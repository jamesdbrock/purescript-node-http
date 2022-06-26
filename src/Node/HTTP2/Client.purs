-- | Low-level bindings to the *Node.js* HTTP/2 Client Core API.
-- |
-- | ## Client-side example
-- |
-- | Equivalent to
-- | https://nodejs.org/docs/latest/api/http2.html#client-side-example
-- |
-- | ```
-- | ca <- Node.FS.Sync.readFile "localhost-cert.pem"
-- |
-- | clientsession <- connect
-- |   (URL.parse "https://localhost:8443")
-- |   (toOptions {ca})
-- |   (\socket -> pure unit)
-- |   (\err -> Effect.Console.error err)
-- |
-- | clientstream <- request clientsession
-- |   (toHeaders {":path": "/"})
-- |   (toOptions {})
-- |
-- | onceResponse clientstream
-- |   \headers flags ->
-- |     for_ (headerKeys headers) \name ->
-- |       Effect.Console.log $
-- |         name <> ": " <> fromMaybe "" (headerValueString headers name)
-- |
-- | let req = toDuplex clientstream
-- |
-- | dataRef <- liftST $ Control.Monad.ST.Ref.new ""
-- | Node.Stream.onDataString req Node.Encoding.UTF8
-- |   \chunk -> void $ liftST $ Control.Monad.ST.Ref.modify (_ <> chunk) dataRef
-- | Node.Stream.onEnd req do
-- |   dataString <- liftST $ Control.Monad.ST.Ref.read dataRef
-- |   Effect.Console.log $ "\n" <> dataString
-- |   close clientsession
-- | ```
module Node.HTTP2.Client
  ( ClientHttp2Session
  , connect
  , request
  , onceError
  , onceResponse
  , onceStream
  , close
  , ClientHttp2Stream
  , respond
  , oncePush
  , toDuplex
  )
  where

import Prelude

import Effect (Effect)
import Effect.Exception (Error)
import Node.HTTP2 (Flags, Headers, OptionsObject)
import Node.HTTP2.Internal as Internal
import Node.Net.Socket (Socket)
import Node.Stream (Duplex)
import Node.URL (URL)
import Unsafe.Coerce (unsafeCoerce)


-- | > Every `Http2Session` instance is associated with exactly one `net.Socket` or `tls.TLSSocket` when it is created. When either the `Socket` or the `Http2Session` are destroyed, both will be destroyed.
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#class-clienthttp2session
foreign import data ClientHttp2Session :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#http2connectauthority-options-listener
foreign import connect :: URL -> OptionsObject -> (Socket -> Effect Unit) -> (Error -> Effect Unit) -> Effect ClientHttp2Session

-- | https://nodejs.org/docs/latest/api/http2.html#class-clienthttp2stream
foreign import data ClientHttp2Stream :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#clienthttp2sessionrequestheaders-options
foreign import request :: ClientHttp2Session -> Headers -> OptionsObject -> Effect ClientHttp2Stream

-- | https://nodejs.org/docs/latest/api/http2.html#http2sessionclosecallback
close :: ClientHttp2Session -> Effect Unit -> Effect Unit
close = unsafeCoerce Internal.close

-- | https://nodejs.org/docs/latest/api/http2.html#event-response
foreign import onceResponse :: ClientHttp2Stream -> (Headers -> Flags -> Effect Unit) -> Effect Unit

-- | https://nodejs.org/docs/latest/api/http2.html#event-stream
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client
onceStream :: ClientHttp2Session -> (ClientHttp2Stream -> Headers -> Flags -> Effect Unit) -> Effect (Effect Unit)
onceStream = unsafeCoerce Internal.onceStream

-- | https://nodejs.org/docs/latest/api/http2.html#event-error
onceError :: ClientHttp2Session -> (Error -> Effect Unit) -> Effect (Effect Unit)
onceError = unsafeCoerce Internal.onceError

-- | https://nodejs.org/docs/latest/api/http2.html#event-push
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client
foreign import oncePush :: ClientHttp2Stream -> (Headers -> Flags -> Effect Unit) -> Effect Unit

-- | https://nodejs.org/docs/latest/api/http2.html#http2streamrespondheaders-options
respond :: ClientHttp2Stream -> Headers -> OptionsObject -> Effect Unit
respond = unsafeCoerce Internal.respond

-- | Coerce to a duplex stream.
toDuplex :: ClientHttp2Stream -> Duplex
toDuplex = unsafeCoerce
