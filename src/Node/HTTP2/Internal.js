import http2 from 'http2';

// https://nodejs.org/docs/latest/api/http2.html#http2streampushstreamheaders-options-callback
export const pushStream = http2stream => headers => options => callback => () => {
  http2stream.pushStream(headers, options,
    (err,pushStream2,headers2) => callback(err)(pushStream2)(headers2)()
  );
}

// https://nodejs.org/docs/latest/api/http2.html#http2streamrespondheaders-options
export const respond = http2stream => headers => options => () => {
  http2stream.respond(headers,options);
}

export const close = foreign => callback => () => {
  foreign.close(() => callback());
}

// https://nodejs.org/docs/latest/api/http2.html#event-close_1
export const onceClose = http2stream => callback => () => {
  const cb = () => callback(http2stream.rstCode)();
  http2stream.once('close', cb);
  return () => {http2stream.removeEventListener('close', cb)};
}

// https://nodejs.org/docs/latest/api/http2.html#event-stream
export const onceStream = foreign => callback => () => {
  const cb = (stream, headers, flags) => callback(stream)(headers)(flags)();
  foreign.once('stream', cb);
  return () => {foreign.removeEventListener('stream', cb)};
}

// https://nodejs.org/docs/latest/api/http2.html#event-stream
export const onStream = foreign => callback => () => {
  const cb = (stream, headers, flags) => callback(stream)(headers)(flags)();
  foreign.on('stream', cb);
}

export const onceError = object => callback => () => {
  const cb = error => callback(error)();
  object.once('error', cb);
  return () => {object.removeEventListener('error', cb)};
}

export const throwAllErrors = eventtarget => () => {
  eventtarget.addEventListener('error', error => {throw error});
}

