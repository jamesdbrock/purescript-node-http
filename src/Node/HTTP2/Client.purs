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
-- | client <- connect
-- |   (URL.parse "https://localhost:8443")
-- |   (toOptions {ca})
-- |   (\_ _ -> pure unit)
-- | _ <- onceErrorSession client Console.errorShow
-- |
-- | req <- request client
-- |   (toHeaders {":path": "/"})
-- |   (toOptions {})
-- |
-- | _ <- onceResponse req
-- |   \headers flags ->
-- |     for_ (headerKeys headers) \name ->
-- |       Console.log $
-- |         name <> ": " <> fromMaybe "" (headerValueString headers name)
-- |
-- | dataRef <- liftST $ Control.Monad.ST.Ref.new ""
-- | Node.Stream.onDataString (toDuplex req) Node.Encoding.UTF8
-- |   \chunk -> void $ liftST $
-- |     Control.Monad.ST.Ref.modify (_ <> chunk) dataRef
-- | Node.Stream.onEnd (toDuplex req) do
-- |   dataString <- liftST $ Control.Monad.ST.Ref.read dataRef
-- |   Console.log $ "\n" <> dataString
-- |   close client
-- | ```
module Node.HTTP2.Client
  ( ClientHttp2Session
  , connect
  , connectWithError
  , onceReady
  , request
  , onceErrorSession
  , onceResponse
  , onStream
  , onceStream
  , onceHeaders
  , close
  , ClientHttp2Stream
  , oncePush
  , onceErrorStream
  , toDuplex
  , onceTrailers
  , onData
  , onceEnd
  , destroy
  ) where

import Prelude

import Effect (Effect)
import Effect.Exception (Error)
import Node.Buffer (Buffer)
import Node.HTTP2 (Flags, HeadersObject, OptionsObject)
import Node.HTTP2.Internal as Internal
import Node.Net.Socket (Socket)
import Node.Stream (Duplex)
import Node.URL (URL)
import Unsafe.Coerce (unsafeCoerce)

-- | > Every `Http2Session` instance is associated with exactly one `net.Socket` or `tls.TLSSocket` when it is created. When either the `Socket` or the `Http2Session` are destroyed, both will be destroyed.
-- |
-- | See [__Class: ClientHttp2Session__](https://nodejs.org/docs/latest/api/http2.html#class-clienthttp2session)
foreign import data ClientHttp2Session :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#http2connectauthority-options-listener
foreign import connect :: URL -> OptionsObject -> (ClientHttp2Session -> Socket -> Effect Unit) -> Effect ClientHttp2Session

-- | https://stackoverflow.com/questions/67790720/node-js-net-connect-error-in-spite-of-try-catch
foreign import connectWithError :: URL -> OptionsObject -> (ClientHttp2Session -> Socket -> Effect Unit) -> (Error -> Effect Unit) -> Effect ClientHttp2Session

-- | https://nodejs.org/api/net.html#event-ready
foreign import onceReady :: Socket -> (Effect Unit) -> Effect (Effect Unit)

-- | A client-side `Http2Stream`.
-- |
-- | See [__Class: ClientHttp2Stream__](https://nodejs.org/docs/latest/api/http2.html#class-clienthttp2stream)
foreign import data ClientHttp2Stream :: Type

-- |https://nodejs.org/docs/latest/api/http2.html#clienthttp2sessionrequestheaders-options
foreign import request :: ClientHttp2Session -> HeadersObject -> OptionsObject -> Effect ClientHttp2Stream

-- | https://nodejs.org/docs/latest/api/http2.html#destruction
foreign import destroy :: ClientHttp2Stream -> Effect Unit

-- | https://nodejs.org/docs/latest/api/http2.html#http2sessionclosecallback
close :: ClientHttp2Session -> Effect Unit -> Effect Unit
close = unsafeCoerce Internal.closeServer

-- | https://nodejs.org/docs/latest/api/http2.html#event-response
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
foreign import onceResponse :: ClientHttp2Stream -> (HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)

-- | https://nodejs.org/docs/latest/api/http2.html#event-headers
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
foreign import onceHeaders :: ClientHttp2Stream -> (HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)

-- | https://nodejs.org/docs/latest/api/http2.html#event-stream
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
onceStream :: ClientHttp2Session -> (ClientHttp2Stream -> HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)
onceStream = unsafeCoerce Internal.onceStream

-- | https://nodejs.org/docs/latest/api/http2.html#event-stream
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client
-- |
-- | Returns an effect for removing the event listener.
onStream :: ClientHttp2Session -> (ClientHttp2Stream -> HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)
onStream = unsafeCoerce Internal.onStream

-- | https://nodejs.org/docs/latest/api/http2.html#event-error
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
onceErrorSession :: ClientHttp2Session -> (Error -> Effect Unit) -> Effect (Effect Unit)
onceErrorSession = unsafeCoerce Internal.onceEmitterError

-- | https://nodejs.org/docs/latest/api/http2.html#event-error_1
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
onceErrorStream :: ClientHttp2Stream -> (Error -> Effect Unit) -> Effect (Effect Unit)
onceErrorStream = unsafeCoerce Internal.onceEmitterError

-- | https://nodejs.org/docs/latest/api/http2.html#event-push
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#push-streams-on-the-client
foreign import oncePush :: ClientHttp2Stream -> (HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)

-- | https://nodejs.org/docs/latest/api/http2.html#event-trailers
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
onceTrailers :: ClientHttp2Stream -> (HeadersObject -> Flags -> Effect Unit) -> Effect (Effect Unit)
onceTrailers = unsafeCoerce Internal.onceTrailers

-- | https://nodejs.org/docs/latest/api/stream.html#event-data
-- |
-- | Returns an effect for removing the event listener.
onData :: ClientHttp2Stream -> (Buffer -> Effect Unit) -> Effect (Effect Unit)
onData = unsafeCoerce Internal.onData

-- | https://nodejs.org/docs/latest/api/net.html#event-end
-- |
-- | Listen for one event, then remove the event listener.
-- |
-- | Returns an effect for removing the event listener before the event
-- | is raised.
onceEnd :: ClientHttp2Stream -> Effect Unit -> Effect (Effect Unit)
onceEnd = unsafeCoerce Internal.onceEnd

-- | Coerce to a duplex stream.
toDuplex :: ClientHttp2Stream -> Duplex
toDuplex = unsafeCoerce
