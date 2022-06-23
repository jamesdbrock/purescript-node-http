module Test.HTTP2Aff where

import Prelude

import Control.Alternative ((<|>))
import Control.Parallel (parSequence_)
import Data.Either (either)
import Data.Maybe (fromMaybe)
import Data.String as String
import Data.Tuple (Tuple(..), fst)
import Effect.Aff (Aff, attempt, catchError, parallel, sequential, throwError)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Node.HTTP2 (HeadersObject, headerArray, headerKeys, headerString, toHeaders, toOptions)
import Node.HTTP2.Client.Aff as Client.Aff
import Node.HTTP2.Server.Aff as Server.Aff
import Node.Stream.Aff (end, fromStringUTF8, readAll, toStringUTF8, write)
import Node.URL as URL
import Test.MockCert (cert, key)
import Unsafe.Coerce (unsafeCoerce)

push1 :: Aff Unit
push1 = parSequence_
  [ push1_serverSecure
  , push1_client
  ]

push1_serverSecure :: Aff Unit
push1_serverSecure = do

  either (\err -> liftEffect $ Console.error (unsafeCoerce err)) pure =<< attempt do
    -- 1. Start the server, wait for a connection.
    server <- Server.Aff.createSecureServer
      (toOptions { key: key, cert: cert })
    void $ Server.Aff.listenSecure server
      (toOptions { port: 8444 })
      \_headers stream -> do

        -- 2. Wait to receive a request.
        let s = Server.Aff.toDuplex stream
        requestBody <- toStringUTF8 =<< (fst <$> readAll s)
        liftEffect $ Console.log $ "SERVER Request body: " <> requestBody

        -- 3. Send a response stream.
        Server.Aff.respond stream (toOptions {}) (toHeaders {})
        write s =<< fromStringUTF8 "HTTP/2 secure response body Aff"

        -- 4. Push a new stream.
        stream2 <- Server.Aff.pushStream stream (toOptions {}) (toHeaders {})
        Server.Aff.respond stream2 (toOptions {}) (toHeaders {})
        let s2 = Server.Aff.toDuplex stream2
        write s2 =<< fromStringUTF8 "HTTP/2 secure push body Aff"
        end s2

        -- 5. Close the connection.
        end s

        -- 6. After one session, stop the server.
        Server.Aff.closeSecure server

push1_client :: Aff Unit
push1_client = do

  either (\err -> liftEffect $ Console.error (unsafeCoerce err)) pure =<< attempt do
    -- 1. Begin the session, open a connection.
    session <- Client.Aff.connect
      (toOptions { ca: cert })
      (URL.parse "https://localhost:8444")

    -- 2. Send a request.
    stream <- Client.Aff.request session
      (toOptions { endStream: false })
      (toHeaders {})
    let s = Client.Aff.toDuplex stream
    write s =<< fromStringUTF8 "HTTP/2 secure request body Aff"
    end s

    -- 3. Wait for the response.
    _ <- Client.Aff.waitResponse stream

    -- We have to do steps 4 and 5 concurrently because we don't know which of
    -- `readAll` or `waitPush` will complete first.
    Tuple responseBody bodyPushed <- sequential $ Tuple
      <$> do
        parallel do
          -- 4. Wait for the reponse body.
          toStringUTF8 =<< (fst <$> readAll s)
      <*>
        do
          parallel do
            -- 5. Receive a pushed stream.
            { streamPushed } <- Client.Aff.waitPush session
            toStringUTF8 =<< (fst <$> readAll (Client.Aff.toDuplex streamPushed))

    liftEffect $ Console.log $ "CLIENT Response body: " <> responseBody
    liftEffect $ Console.log $ "CLIENT Pushed body: " <> bodyPushed

    -- 6. The stream has ended so close the session.
    Client.Aff.close session

headers_serverSecure :: Aff Unit
headers_serverSecure = do

  -- 1. Start the server, wait for a connection.
  server <- Server.Aff.createSecureServer
    (toOptions { key: key, cert: cert })
  Server.Aff.listenSecure server
    (toOptions { port: 8444 })
    \headers stream -> do
      liftEffect $ Console.log $ "SERVER " <> headersShow headers

      -- 2. Receive a request.
      let s = Server.Aff.toDuplex stream

      -- 3. Send a response.
      Server.Aff.respond stream (toOptions {}) $ toHeaders
        { "normal": "server normal header"
        }
      -- Error [ERR_HTTP2_HEADERS_AFTER_RESPOND]: Cannot specify additional headers after response initiated
      -- Server.Aff.sendHeadersAdditional stream $ toHeaders
      --   { "additional": "server additional header"
      --   }

      -- 4. Push a new stream.
      stream2 <- Server.Aff.pushStream stream (toOptions {}) (toHeaders {})
      Server.Aff.respond stream2 (toOptions {})
        ( toHeaders
            { "pushnormal": "server normal pushed header"
            }
        )
      let s2 = Server.Aff.toDuplex stream2
      end s2

      -- 5. Close the connection.
      end s

      -- 6. After one session, stop the server.
      Server.Aff.closeSecure server

headers_client :: Aff Unit
headers_client = do

  -- 1. Begin the session, open a connection.
  session <- Client.Aff.connect
    (toOptions { ca: cert })
    (URL.parse "https://localhost:8444")

  -- 2. Send a request.
  stream <- Client.Aff.request session (toOptions {}) $ toHeaders
    { "normal": "client normal header"
    }
  let s = Client.Aff.toDuplex stream
  end s

  parSequence_
    [ do
        -- 3. Receive a pushed stream.
        { headersRequest, headersResponse } <- Client.Aff.waitPush session
        liftEffect $ Console.log $ "CLIENT Pushed Request " <> headersShow headersRequest
        liftEffect $ Console.log $ "CLIENT Pushed Response " <> headersShow headersResponse
    , do
        -- 4. Wait for the response.
        headers <- Client.Aff.waitResponse stream
        liftEffect $ Console.log $ "CLIENT " <> headersShow headers
    ]

  -- 5. Wait for the stream to end, then close the connection.
  Client.Aff.waitEnd stream
  Client.Aff.close session

trailers_serverSecure :: Aff Unit
trailers_serverSecure = do

  -- 1. Start the server, wait for a connection.
  server <- Server.Aff.createSecureServer
    (toOptions { key: key, cert: cert })
  Server.Aff.listenSecure server
    (toOptions { port: 8444 })
    \_ stream -> do

      -- 2. Receive a request.
      let s = Server.Aff.toDuplex stream

      -- 3. Send a response
      -- This whole Trailers API is so bad, how can we improve this.
      Server.Aff.respond stream
        (toOptions { waitForTrailers: true })
        (toHeaders {})
      end s
      -- 4. Send Trailers.
      Server.Aff.waitWantTrailers stream
      Server.Aff.sendTrailers stream (toHeaders { "trailer1": "trailer one" })

      -- 5. After one session, stop the server.
      Server.Aff.closeSecure server

trailers_client :: Aff Unit
trailers_client = do

  -- 1. Begin the session, open a connection.
  session <- Client.Aff.connect
    (toOptions { ca: cert })
    (URL.parse "https://localhost:8444")

  -- 2. Send a request.
  stream <- Client.Aff.request session (toOptions {}) (toHeaders {})
  let s = Client.Aff.toDuplex stream
  end s

  -- 3. Wait for the response.
  headers <- Client.Aff.waitResponse stream
  liftEffect $ Console.log $ "CLIENT Header " <> headersShow headers
  -- 4. Wait for trailers.
  trailers <- Client.Aff.waitTrailers stream
  liftEffect $ Console.log $ "CLIENT Trailer " <> headersShow trailers

  -- 5. Wait for the stream to end, then close the connection.
  Client.Aff.waitEnd stream
  Client.Aff.close session

headersShow :: HeadersObject -> String
headersShow headers = String.joinWith ", " $ headerKeys headers <#> \key ->
  key <> ": " <>
    ( fromMaybe "" $
        (headerString headers key)
          <|>
            (String.joinWith " " <$> headerArray headers key)
    )

error1_serverSecure :: Aff Unit
error1_serverSecure = catchError
  do
    -- 1. Start the server, wait for a connection.
    _ <- Server.Aff.createSecureServer
      (toOptions { key: "bad key", cert: "bad cert" })
    pure unit
  ( \e -> do
      liftEffect $ Console.error (unsafeCoerce e)
      throwError e
  )

error2_serverSecure :: Aff Unit
error2_serverSecure = catchError
  do
    -- 1. Start the server, wait for a connection.
    server <- Server.Aff.createSecureServer
      (toOptions { key: key, cert: cert })
    void $ Server.Aff.listenSecure server
      (toOptions { port: 1 })
      \_ _ -> pure unit
  ( \e -> do
      liftEffect $ Console.error (unsafeCoerce e)
      throwError e
  )

error1_client :: Aff Unit
error1_client = catchError
  do
    -- 1. Begin the session, open a connection.
    _ <- Client.Aff.connect
      (toOptions { ca: cert })
      (URL.parse "https://localhost:1")
    pure unit
  ( \e -> do
      liftEffect $ Console.error (unsafeCoerce e)
      throwError e
  )

error2_client :: Aff Unit
error2_client = catchError
  do
    -- 1. Begin the session, open a connection.
    session <- Client.Aff.connect
      (toOptions {})
      (URL.parse "https://www.google.com:443")
    stream <- Client.Aff.request session
      (toOptions {})
      (toHeaders { "bad header": "bad header" })
    headers <- Client.Aff.waitResponse stream
    liftEffect $ Console.log (unsafeCoerce headers)
  ( \e -> do
      liftEffect $ Console.error (unsafeCoerce e)
      throwError e
  )