import http2 from 'http2';

export const createServer = options => errorcallback => () => {
  const server = http2.createServer(options);
  // TODO instead of an error callback
  // TODO the completion callback should be Maybe Error -> Effect Unit
  server.on('error', error => errorcallback(error)());
  server.on('sessionError', (error,session) => errorcallback(error)());
  return server;
}

export const createSecureServer = options => errorcallback => () => {
  const server = http2.createSecureServer(options);
  server.on('error', error => errorcallback(error)());
  server.on('sessionError', (error,session) => errorcallback(error)());
  return server;
}

// https://nodejs.org/docs/latest/api/net.html#serverlistenoptions-callback
export const listen = server => options => callback => () => {
  // TODO the completion callback should be Maybe Error -> Effect Unit
  server.listen(options, () => callback());
}

export const onceSession = http2server => callback => () => {
  http2server.once('session', (session) => callback(session)());
}
