import http2 from 'http2';

// https://nodejs.org/docs/latest/api/http2.html#http2connectauthority-options-listener
// https://nodejs.org/docs/latest/api/http2.html#event-connect
export const connect = authority => options => listener => () => {
  return http2.connect(authority, options,
    (session,socket) => listener(session)(socket)()
  );
}

// https://nodejs.org/docs/latest/api/http2.html#clienthttp2sessionrequestheaders-options
export const request = clienthttp2session => headers => options => () => {
  return clienthttp2session.request(headers, options);
}

export const destroy = clienthttp2stream => () => {
  clienthttp2stream.destroy();
}

// https://nodejs.org/docs/latest/api/http2.html#event-response
export const onceResponse = clienthttp2stream => callback => () => {
  clienthttp2stream.once('response',
    (headers,flags) => callback(headers)(flags)()
  );
}

// https://nodejs.org/docs/latest/api/http2.html#event-headers
export const onceHeaders = clienthttp2stream => callback => () => {
  const cb = (headers,flags) => callback(headers)(flags)();
  clienthttp2stream.once('headers', cb);
  return () => clienthttp2stream.removeEventListener('headers', cb);
}

// https://nodejs.org/docs/latest/api/http2.html#event-push
export const oncePush = clienthttp2stream => callback => () => {
  const cb = (headers,flags) => callback(headers)(flags)();
  clienthttp2stream.once('push', cb);
  return () => clienthttp2stream.removeEventListener('push', cb);
}
