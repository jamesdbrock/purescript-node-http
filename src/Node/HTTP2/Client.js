import http2 from 'http2';

export const connect = authority => options => listener => errorcallback => () => {
  const clienthttp2session = http2.connect(authority, options, listener);
	clienthttp2session.on('error', error => errorcallback(error)());
	return clienthttp2session;
}

export const request = clienthttp2session => headers => options => () => {
  return clienthttp2session.request(headers, options);
}

// https://nodejs.org/docs/latest/api/http2.html#event-response
export const onceResponse = clienthttp2stream => callback => () => {
  clienthttp2stream.once('response',
    (headers,flags) => callback(headers)(flags)()
  );
}

// https://nodejs.org/docs/latest/api/http2.html#event-push
export const oncePush = clienthttp2stream => callback => () => {
  clienthttp2stream.once('push',
    (headers,flags) => callback(headers)(flags)()
  );
}
