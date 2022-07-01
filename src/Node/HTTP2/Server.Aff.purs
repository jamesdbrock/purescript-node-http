-- | Bindings to the *Node.js* HTTP/2 Server Core API.
-- |
-- | ## Server-side example
-- |
-- | Equivalent to
-- | https://nodejs.org/docs/latest/api/http2.html#server-side-example
-- |
-- | ```
-- | key <- Node.FS.Sync.readFile "localhost-privkey.pem"
-- | cert <- Node.FS.Sync.readFile "localhost-cert.pem"
-- |
-- | server <- createSecureServer
-- |   (toOptions {key, cert})
-- |   (\err -> Console.log err)
-- |
-- | onceStreamSecure server \stream headers flags -> do
-- |   respond stream
-- |     (toHeaders
-- |       { "content-type": "text/html; charset=utf-8"
-- |       , ":status": 200
-- |       }
-- |     )
-- |     (toOptions {})
-- |   void $ Node.Stream.writeString stream
-- |     Node.Encoding.UTF8
-- |     "<h1>Hello World</h1>"
-- |     (\_ -> pure unit)
-- |   Node.Stream.end (toDuplex stream) (\_ -> pure unit)
-- | ```
module Node.HTTP2.Server.Aff where

import Prelude

import Data.Either (Either(..))
import Effect.Aff (Aff, makeAff, nonCanceler, runAff_)
import Effect.Class (liftEffect)
import Node.HTTP2 (Headers, OptionsObject, toOptions)
import Node.HTTP2.Server (Http2SecureServer, Http2Server, ServerHttp2Stream)
import Node.HTTP2.Server as Server

-- | Create an HTTP/2 server and open one listening socket for unencrypted
-- | connections.
-- |
-- | Waits until the listening socket is open and then returns the `Http2Server`.
-- |
-- | The first `OptionsObject` is the `createServer` options.
-- | See [`http2.createServer([options][, onRequestHandler])`](https://nodejs.org/docs/latest/api/http2.html#http2createserveroptions-onrequesthandler)
-- |
-- | The second `OptionsObject` is the `listen` options.
-- | See [`server.listen(options[, callback])`](https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback)
-- |
-- | For each new connection and request, the handler function will
-- | be invoked with `forkAff` and passed the `Http2Server` and the request.
-- |
-- | Example:
-- | ```
-- | import Node.Stream.Aff (readAll, write, writeableClose)
-- |
-- | void $ listen (toOptions {}) (toOptions {port:8443 })
-- |   \server headers stream -> do
-- |     when (headerString headers ":method" == "GET") do
-- |       request <- toStringUTF8 =<< readAll (toDuplex stream)
-- |       respond stream
-- |         (toHeaders
-- |           { "content-type": "text/html; charset=utf-8"
-- |           , ":status": 200
-- |           }
-- |         )
-- |       write (toDuplex stream) =<< fromStringUTF8 ("Request was: " <> request)
-- |     writeableClose (toDuplex stream)
-- |     closeServer server
-- | ```
listen :: OptionsObject -> OptionsObject -> (Http2Server -> Headers -> ServerHttp2Stream -> Aff Unit) -> Aff Http2Server
listen optionsserver optionslisten handler = makeAff \complete -> do
  -- problem: after listen complete, there is no way to get errors
  server <- Server.createServer optionsserver \err -> complete (Left err)
  Server.onStream server \stream headers _ -> do
    runAff_ (\_ -> pure unit) $ handler server headers stream
  Server.listen server optionslisten $ complete (Right server) -- listen errors raised by createServer callback?
  pure nonCanceler

-- | Create an HTTP/2 server and open one listening socket for encrypted
-- | connections.
-- |
-- | Secure version of `listen`.
listenSecure :: OptionsObject -> OptionsObject -> (Http2SecureServer -> Headers -> ServerHttp2Stream -> Aff Unit) -> Aff Http2SecureServer
listenSecure optionsserver optionslisten handler = makeAff \complete -> do
  -- problem: after listen complete, there is no way to get errors
  server <- Server.createSecureServer optionsserver \err -> complete (Left err)
  Server.onStreamSecure server \stream headers _ -> do
    runAff_ (\_ -> pure unit) $ handler server headers stream
  Server.listenSecure server optionslisten $ complete (Right server) -- listen errors raised by createServer callback?
  pure nonCanceler

-- | Send response headers.
-- |
-- | Follow this with calls to
-- | [`Node.Stream.Aff.write`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:write)
-- | and
-- | [`Node.Stream.Aff.writeableClose`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:writableClose).
respond :: ServerHttp2Stream -> Headers -> Aff Unit
respond stream headers = makeAff \complete -> do
  Server.respond stream headers (toOptions {})
  -- TODO wait for respond send?
  complete (Right unit)
  pure nonCanceler

-- | Close the server listening socket. Completes after socket is closed.
closeServer :: Http2Server -> Aff Unit
closeServer server = makeAff \complete -> do
  Server.closeServer server $ complete (Right unit)
  pure nonCanceler

-- | Close the server listening socket. Completes after socket is closed.
closeServerSecure :: Http2SecureServer -> Aff Unit
closeServerSecure server = makeAff \complete -> do
  Server.closeServerSecure server $ complete (Right unit)
  pure nonCanceler