// Minimal JSON POST helper over Node's `http` module. Using the core http
// module (rather than global fetch/undici) ensures the request is captured by
// `@opentelemetry/instrumentation-http`, which injects the W3C traceparent
// header so the shipping service joins the same distributed trace.
'use strict';

const http = require('http');
const { URL } = require('url');

function postJson(urlStr, payload) {
  const url = new URL(urlStr);
  const body = JSON.stringify(payload);
  const options = {
    method: 'POST',
    hostname: url.hostname,
    port: url.port,
    path: url.pathname + url.search,
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) },
  };
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 400) return reject(new Error(`shipping ${res.statusCode}: ${data}`));
        resolve(data ? JSON.parse(data) : {});
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

module.exports = { postJson };
