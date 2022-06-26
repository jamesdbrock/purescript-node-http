-- | Low-level bindings to the *Node.js* HTTP/2 Server Core API.
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
module Node.HTTP2.Server
  ( Http2Server
  , createServer
  , listen
  , onceSession
  , onceStream
  , closeServer
  , Http2SecureServer
  , createSecureServer
  , listenSecure
  , onceSessionSecure
  , onceStreamSecure
  , closeServerSecure
  , ServerHttp2Session
  , respond
  , closeSession
  , ServerHttp2Stream
  , pushStream
  , toDuplex
  )
  where

import Prelude

import Effect (Effect)
import Effect.Exception (Error)
import Node.HTTP2 (Flags, Headers, OptionsObject)
import Node.HTTP2.Internal as Internal
import Node.Stream (Duplex)
import Unsafe.Coerce (unsafeCoerce)

-- | https://nodejs.org/docs/latest/api/http2.html#class-http2server
foreign import data Http2Server :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#http2createserveroptions-onrequesthandler
-- |
-- | The `Error` callback will be called for errors in the server and
-- | errors in the server’s associated `ServerHttp2Session`.
foreign import createServer :: OptionsObject -> (Error -> Effect Unit) -> Effect Http2Server

-- | https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback
foreign import listen :: Http2Server -> OptionsObject -> Effect Unit -> Effect Unit

-- | https://nodejs.org/docs/latest/api/http2.html#serverclosecallback
closeServer :: Http2Server -> Effect Unit -> Effect Unit
closeServer = unsafeCoerce Internal.close


-- | https://nodejs.org/docs/latest/api/http2.html#class-http2secureserver
foreign import data Http2SecureServer :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#http2createsecureserveroptions-onrequesthandler
-- |
-- | Required options: `key :: String`, `cert :: String`.
-- |
-- | The `Error` callback will be called for errors in the server and
-- | errors in the server’s associated `ServerHttp2Session`.
foreign import createSecureServer :: OptionsObject -> (Error -> Effect Unit) -> Effect Http2SecureServer

-- | https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback
listenSecure :: Http2SecureServer -> OptionsObject -> Effect Unit -> Effect Unit
listenSecure = unsafeCoerce listen

-- | https://nodejs.org/docs/latest/api/http2.html#serverclosecallback
closeServerSecure :: Http2SecureServer -> Effect Unit -> Effect Unit
closeServerSecure = unsafeCoerce Internal.close

-- | https://nodejs.org/docs/latest/api/http2.html#class-serverhttp2session
-- |
-- | > Every `Http2Session` instance is associated with exactly one
-- | > `net.Socket` or `tls.TLSSocket` when it is created. When either
-- | > the `Socket` or the `Http2Session` are destroyed, both will be destroyed.
-- |
-- | > On the server side, user code should rarely have occasion to work
-- | > with the `Http2Session` object directly, with most actions typically
-- | > taken through interactions with either the `Http2Server` or `Http2Stream` objects.
foreign import data ServerHttp2Session :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#event-session
foreign import onceSession :: Http2Server -> (ServerHttp2Session -> Effect Unit) -> Effect Unit

-- | https://nodejs.org/docs/latest/api/http2.html#http2sessionclosecallback
closeSession :: ServerHttp2Session -> Effect Unit -> Effect Unit
closeSession = unsafeCoerce Internal.close

-- | Listen for one event, call the callback, then remove
-- | the event listener.
-- | Returns an effect for removing the event listener before the event
-- | is raised.
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#event-stream
onceStream :: Http2Server -> (ServerHttp2Stream -> Headers -> Flags -> Effect Unit) -> Effect (Effect Unit)
onceStream = unsafeCoerce Internal.onceStream

-- | Listen for one event, call the callback, then remove
-- | the event listener.
-- | Returns an effect for removing the event listener before the event
-- | is raised.
-- |
-- | https://nodejs.org/docs/latest/api/http2.html#event-stream
onceStreamSecure :: Http2SecureServer -> (ServerHttp2Stream -> Headers -> Flags -> Effect Unit) -> Effect (Effect Unit)
onceStreamSecure = unsafeCoerce Internal.onceStream

-- | https://nodejs.org/docs/latest/api/http2.html#http2streamrespondheaders-options
respond :: ServerHttp2Stream -> Headers -> OptionsObject -> Effect Unit
respond = unsafeCoerce Internal.respond

-- | https://nodejs.org/docs/latest/api/http2.html#event-session_1
onceSessionSecure :: Http2SecureServer -> (ServerHttp2Session -> Effect Unit) -> Effect Unit
onceSessionSecure = unsafeCoerce onceSession

-- | https://nodejs.org/docs/latest/api/http2.html#class-serverhttp2stream
foreign import data ServerHttp2Stream :: Type

-- | https://nodejs.org/docs/latest/api/http2.html#http2streampushstreamheaders-options-callback
-- |
-- | > Calling `http2stream.pushStream()` from within a pushed stream is not permitted and will throw an error.
pushStream :: ServerHttp2Stream -> Headers -> OptionsObject -> (Error -> ServerHttp2Stream -> Headers -> Effect Unit) -> Effect Unit
pushStream = unsafeCoerce Internal.pushStream

-- | Coerce to a duplex stream.
toDuplex :: ServerHttp2Stream -> Duplex
toDuplex = unsafeCoerce
