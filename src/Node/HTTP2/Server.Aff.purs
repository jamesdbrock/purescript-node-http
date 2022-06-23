-- | Bindings to the *Node.js* HTTP/2 Server Core API.
-- |
-- | ## Server-side example
-- |
-- | Equivalent to
-- | [*Node.js* HTTP/2 Core API __Server-side example__](https://nodejs.org/docs/latest/api/http2.html#server-side-example)
-- |
-- | ```
-- | import Node.Stream.Aff (write, end)
-- |
-- | key <- Node.FS.Sync.readFile "localhost-privkey.pem"
-- | cert <- Node.FS.Sync.readFile "localhost-cert.pem"
-- |
-- | either (liftEffect <<< Console.errorShow) pure =<< attempt do
-- |   server <- createSecureServer (toOptions {key, cert})
-- |   listenSecure server (toOptions {port:8443})
-- |     \headers stream -> do
-- |       respond stream
-- |         (toOptions {})
-- |         (toHeaders
-- |           { "content-type": "text/html; charset=utf-8"
-- |           , ":status": 200
-- |           }
-- |         )
-- |       write (toDuplex stream) =<< fromStringUTF8 ("<h1>Hello World<hl>")
-- |       end (toDuplex stream)
-- | ```
module Node.HTTP2.Server.Aff
  ( createServer
  , listen
  , createSecureServer
  , listenSecure
  , respond
  , pushStream
  , sendHeadersAdditional
  , waitEnd
  , waitWantTrailers
  , sendTrailers
  , close
  , closeSecure
  , module ReServer
  ) where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Nullable (toMaybe)
import Effect.Aff (Aff, effectCanceler, launchAff_, makeAff, nonCanceler)
import Effect.Class (liftEffect)
import Effect.Exception (catchException)
import Node.HTTP2 (HeadersObject, OptionsObject, toOptions)
import Node.HTTP2.Server (Http2SecureServer, Http2Server, ServerHttp2Stream, toDuplex)
import Node.HTTP2.Server (Http2Server, Http2SecureServer, ServerHttp2Stream, toDuplex) as ReServer
import Node.HTTP2.Server as Server
import Node.Stream.Aff.Internal as Node.Stream.Aff.Internal
import Web.Fetch.AbortController as Web.Fetch.AbortController

-- | Create an insecure (HTTP) HTTP/2 server.
-- |
-- | The argument is the `createServer` options.
-- | See [`http2.createServer([options][, onRequestHandler])`](https://nodejs.org/docs/latest/api/http2.html#http2createserveroptions-onrequesthandler)
createServer
  :: OptionsObject
  -> Aff Http2Server
createServer options = makeAff \complete -> do
  catchException (complete <<< Left) do
    server <- Server.createServer options
    complete (Right server)
  pure nonCanceler

-- | Open one listening socket for unencrypted connections.
-- |
-- | For each new client connection and request, the handler function will
-- | be invoked by `launchAff` and passed the request.
-- | This unfortunately makes the handler function uncancellable.
-- |
-- | Will complete after the socket has stopped listening and closed.
-- |
-- | Errors will be thrown through the `Aff` `MonadThrow` instance.
-- |
-- | Listening may be stopped explicity by calling `close` on the
-- | server, or implicitly by `killFiber`.
-- |
-- | For the `listen` options,
-- | see [`server.listen(options[, callback])`](https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback)
listen
  :: Http2Server
  -> OptionsObject
  -> (HeadersObject -> ServerHttp2Stream -> Aff Unit)
  -> Aff Unit
listen server options handler = makeAff \complete -> do
  -- The Http2Server is a tls.Server
  -- https://nodejs.org/docs/latest/api/tls.html#event-tlsclienterror
  -- The Http2Server is a net.Server
  -- https://nodejs.org/docs/latest/api/net.html#event-error
  -- The Http2Server is an EventEmitter.
  abortcontroller <- Web.Fetch.AbortController.new
  let abortsignal = Web.Fetch.AbortController.signal abortcontroller

  onStreamCancel <- Server.onStream server \stream headers _ -> do
    launchAff_ $ handler headers stream

  -- https://nodejs.org/docs/latest/api/net.html#event-error
  -- “the 'close' event will not be emitted directly following this event unless server.close() is manually called.”
  onErrorCancel <- Server.onErrorServer server \err -> do
    onStreamCancel
    -- TODO Is it a good idea to closeServer here?
    Server.closeServer server $ pure unit
    complete (Left err)

  _ <- Server.onceCloseServer server do
    onStreamCancel
    onErrorCancel
    complete (Right unit)

  -- TODO there is also an on 'session' event raised by the server, do we
  -- want to do anything about that?
  -- https://nodejs.org/docs/latest/api/http2.html#class-serverhttp2session

  Server.listen server (toOptions { "signal": abortsignal } <> options) do
    -- We don't want to complete here.
    pure unit

  pure $ effectCanceler do
    -- “signal <AbortSignal> An AbortSignal that may be used to close a listening server.”
    -- Or we could just call close() here?
    Web.Fetch.AbortController.abort abortcontroller

-- | Create a secure (HTTPS) HTTP/2 server.
-- |
-- | The argument is the `createServer` options.
-- | See [`http2.createServer([options][, onRequestHandler])`](https://nodejs.org/docs/latest/api/http2.html#http2createserveroptions-onrequesthandler)
-- |
-- | Required options: `key :: String`, `cert :: String`.
createSecureServer
  :: OptionsObject
  -> Aff Http2SecureServer
createSecureServer options = makeAff \complete -> do
  catchException (complete <<< Left) do
    server <- Server.createSecureServer options
    complete (Right server)
  pure nonCanceler

-- | Secure version of `listen`. Open one listening socket
-- | for encrypted connections.
-- |
-- | For each new client connection and request, the handler function will
-- | be invoked by `launchAff` and passed the request.
-- | This unfortunately makes the handler function uncancellable.
-- |
-- | Will complete after the socket has stopped listening and closed.
-- |
-- | Errors will be thrown through the `Aff` `MonadThrow` instance.
-- |
-- | Listening may be stopped explicity by calling `closeSecure` on the
-- | server, or implicitly by `killFiber`.
-- |
-- | For the `listen` options,
-- | see [`server.listen(options[, callback])`](https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback)
listenSecure
  :: Http2SecureServer
  -> OptionsObject
  -> (HeadersObject -> ServerHttp2Stream -> Aff Unit)
  -> Aff Unit
listenSecure server options handler = makeAff \complete -> do
  -- The Http2Server is a tls.Server
  -- https://nodejs.org/docs/latest/api/tls.html#event-tlsclienterror
  -- The Http2Server is a net.Server
  -- https://nodejs.org/docs/latest/api/net.html#event-error
  -- The Http2Server is an EventEmitter.
  abortcontroller <- Web.Fetch.AbortController.new
  let abortsignal = Web.Fetch.AbortController.signal abortcontroller

  onStreamCancel <- Server.onStreamSecure server \stream headers _ -> do
    launchAff_ $ handler headers stream

  -- https://nodejs.org/docs/latest/api/net.html#event-error
  -- “the 'close' event will not be emitted directly following this event unless server.close() is manually called.”
  onErrorCancel <- Server.onErrorServerSecure server \err -> do
    onStreamCancel
    -- TODO Is it a good idea to closeServer here?
    Server.closeServerSecure server $ pure unit
    complete (Left err)

  _ <- Server.onceCloseServerSecure server do
    onStreamCancel
    onErrorCancel
    complete (Right unit)

  -- TODO there is also an on 'session' event raised by the server, do we
  -- want to do anything about that?
  -- https://nodejs.org/docs/latest/api/http2.html#class-serverhttp2session

  Server.listenSecure server (toOptions { "signal": abortsignal } <> options) do
    -- We don't want to complete here.
    pure unit

  pure $ effectCanceler do
    -- “signal <AbortSignal> An AbortSignal that may be used to close a listening server.”
    -- Or we could just call close() here?
    Web.Fetch.AbortController.abort abortcontroller

-- | Send response headers.
-- |
-- | Follow this with calls to
-- | [`Node.Stream.Aff.write`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:write)
-- | and
-- | [`Node.Stream.Aff.end`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:end).
-- |
-- | See
-- | [`http2stream.respond([headers[, options]])`](https://nodejs.org/docs/latest/api/http2.html#http2streamrespondheaders-options)
respond :: ServerHttp2Stream -> OptionsObject -> HeadersObject -> Aff Unit
respond stream options headers = makeAff \complete -> do
  catchException (complete <<< Left) do
    Server.respond stream headers options
    -- TODO wait for respond send?
    complete (Right unit)
  pure nonCanceler

-- | Close the server listening socket. Will complete after socket is closed.
close :: Http2Server -> Aff Unit
close server = makeAff \complete -> do
  catchException (complete <<< Left) do
    Server.closeServer server $ complete (Right unit)
  pure nonCanceler

-- | Close the server listening socket. Will complete after socket is closed.
closeSecure :: Http2SecureServer -> Aff Unit
closeSecure server = makeAff \complete -> do
  catchException (complete <<< Left) do
    Server.closeServerSecure server $ complete (Right unit)
  pure nonCanceler

-- | Push a stream to the client, with the client request headers for a
-- | request which the client did not send but to which the server will respond.
-- |
-- | On the new pushed stream, it is mandatory to first call `respond`.
-- |
-- | Then call
-- | [`Node.Stream.Aff.write`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:write)
-- | and
-- | [`Node.Stream.Aff.end`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:end).
-- |
-- | See [`http2stream.pushStream(headers[, options], callback)`](https://nodejs.org/docs/latest/api/http2.html#http2streampushstreamheaders-options-callback)
-- |
-- | > Calling `http2stream.pushStream()` from within a pushed stream is not permitted and will throw an error.
pushStream :: ServerHttp2Stream -> OptionsObject -> HeadersObject -> Aff ServerHttp2Stream
pushStream stream options headersRequest = makeAff \complete -> do
  Server.pushStream stream headersRequest options \nerr pushedstream _ -> do
    case toMaybe nerr of
      Just err -> complete (Left err)
      Nothing -> complete (Right pushedstream)
  pure nonCanceler

-- | Send an additional informational `HEADERS` frame to the connected HTTP/2 peer.
sendHeadersAdditional :: ServerHttp2Stream -> HeadersObject -> Aff Unit
sendHeadersAdditional stream headers = do
  liftEffect $ Server.additionalHeaders stream headers

-- | Wait for the end of the `Readable` stream from the client.
waitEnd :: ServerHttp2Stream -> Aff Unit
waitEnd stream = makeAff \complete -> do
  readable <- Node.Stream.Aff.Internal.readable (toDuplex stream)
  if readable then do
    onceEndCancel <- Server.onceEnd stream $ complete (Right unit)
    pure $ effectCanceler do
      onceEndCancel
  else do
    complete (Right unit)
    pure nonCanceler

-- | Wait for the
-- | [`wantTrailers`](https://nodejs.org/docs/latest/api/http2.html#event-wanttrailers)
-- | event.
-- |
-- | > When initiating a `request` or `response`, the `waitForTrailers` option must
-- | > be set for this event to be emitted.
-- |
-- | Follow this with a call to `sendTrailers`.
waitWantTrailers :: ServerHttp2Stream -> Aff Unit
waitWantTrailers stream = makeAff \complete -> do
  onceWantTrailersCancel <- Server.onceWantTrailers stream $ complete (Right unit)
  pure $ effectCanceler do
    onceWantTrailersCancel

-- | Send a trailing `HEADERS` frame to the connected HTTP/2 peer.
-- | This will cause the `Http2Stream` to immediately close and must
-- | only be called after the final `DATA` frame is signalled with
-- | [`Node.Stream.Aff.end`](https://pursuit.purescript.org/packages/purescript-node-streams-aff/docs/Node.Stream.Aff#v:end).
-- |
-- | See [`http2stream.sendTrailers(headers)`](https://nodejs.org/docs/latest/api/http2.html#http2streamsendtrailersheaders)
-- |
-- | > When sending a request or sending a response, the
-- | > `options.waitForTrailers` option must be set in order to keep
-- | > the `Http2Stream` open after the final `DATA` frame so that
-- | > trailers can be sent.
sendTrailers :: ServerHttp2Stream -> HeadersObject -> Aff Unit
sendTrailers stream headers = makeAff \complete -> do
  catchException (complete <<< Left) do
    Server.sendTrailers stream headers
    complete (Right unit)
  pure nonCanceler
