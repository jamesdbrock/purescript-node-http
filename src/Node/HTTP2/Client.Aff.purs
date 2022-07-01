-- | Bindings to the *Node.js* HTTP/2 Client Core API.
-- |
-- | ## Client-side example
-- |
-- | Equivalent to
-- | https://nodejs.org/docs/latest/api/http2.html#client-side-example
-- |
-- | ```
-- | ca <- liftEffect $ Node.FS.Sync.readFile "localhost-cert.pem"
-- |
-- | clientsession <- connect
-- |   (toOptions {ca})
-- |   (URL.parse "https://localhost:8443")
-- |
-- | Tuple headers clientstream <- request clientsession
-- |   (toOptions {})
-- |   (toHeaders {":path": "/"})
-- |
-- | liftEffect $ for_ (headerKeys headers) \name ->
-- |   Effect.Console.log $
-- |     name <> ": " <> fromMaybe "" (headerValueString headers name)
-- |
-- | dataString <- toStringUTF8 =<< (fst <$> Node.Stream.Aff.readAll (toDuplex clientstream))
-- | liftEffect $ Effect.Console.log $ "\n" <> dataString
-- |
-- | close clientsession
-- | ```
module Node.HTTP2.Client.Aff where

import Prelude

import Data.Either (Either(..))
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff, effectCanceler, makeAff, nonCanceler)
import Node.HTTP2 (Headers, OptionsObject)
import Node.HTTP2.Client (ClientHttp2Session, ClientHttp2Stream)
import Node.HTTP2.Client as Client
import Node.URL (URL)

-- | Connect a client `Http2Session`.
-- |
-- | See [`http2.connect(authority[, options][, listener])`](https://nodejs.org/docs/latest/api/http2.html#http2connectauthority-options-listener)
connect :: OptionsObject -> URL -> Aff ClientHttp2Session
connect optionsobject url = makeAff \complete -> do
  void $ Client.connect url optionsobject
    (\session _ -> complete (Right session))
  pure nonCanceler

-- | Gracefully closes the `Http2Session`, allowing any existing streams
-- | to complete on their own and preventing new `Http2Stream` instances
-- | from being created.
-- |
-- | See [`http2session.close([callback])`](https://nodejs.org/docs/latest/api/http2.html#http2sessionclosecallback)
close :: ClientHttp2Session -> Aff Unit
close session = makeAff \complete -> do
  Client.close session (complete (Right unit))
  pure nonCanceler

-- | Send an HTTP/2 request to the connected server and wait for the response.
-- |
-- | See [`clienthttp2session.request(headers[, options])`](https://nodejs.org/docs/latest/api/http2.html#clienthttp2sessionrequestheaders-options)
-- |
-- | Follow this with a call to
-- | [`Node.Stream.Aff.readAll`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/2.0.0/docs/Node.Stream.Aff#v:readAll).
request :: ClientHttp2Session -> OptionsObject -> Headers -> Aff (Tuple Headers ClientHttp2Stream)
request session optionsobject headers = makeAff \complete -> do
  stream <- Client.request session headers optionsobject -- TODO errors?
  -- assume the request cannot complete before we attach reponse handler
  Client.onceResponse stream \headers' _ ->
    complete (Right (Tuple headers' stream))
  pure $ effectCanceler do
    -- onceStreamCancel Don't need to cancel
    Client.destroy stream

-- | Wait to receive a pushed stream from the server.
-- |
-- | See [Push streams on the client](https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client)
-- |
-- | Follow this with a call to `respond`.
receivePush :: ClientHttp2Session -> Aff (Tuple Headers ClientHttp2Stream)
receivePush session = makeAff \complete -> do
  onceStreamCancel <- Client.onceStream session \stream headers _ ->
    complete (Right (Tuple headers stream))
  pure $ effectCanceler do
    onceStreamCancel

-- | Respond to a pushed stream from the server.
-- |
-- | See [`http2stream.respond([headers[, options]])`](https://nodejs.org/docs/latest/api/http2.html#http2streamrespondheaders-options)
-- |
-- | Follow this with calls to
-- | [`Node.Stream.Aff.write`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:write)
-- | and
-- | [`Node.Stream.Aff.writeableClose`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:writableClose).
respond :: ClientHttp2Stream -> OptionsObject -> Headers -> Aff Unit
respond stream optionsobject headers = makeAff \complete -> do
  Client.respond stream headers optionsobject
  complete (Right unit) -- TODO we can't wait? What about errors?
  pure nonCanceler