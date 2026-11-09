'use strict';

// Express 5's app.listen() wraps the trailing callback and also registers it
// as a one-time 'error' listener on the underlying server (see
// express/lib/application.js) — that's Express-specific, not a guarantee of
// Node's net.Server.listen(), whose own callback never receives an error.
// So `err` below IS set on an initial bind failure (e.g. EADDRINUSE), and
// `throw err` crashing the process there is intentional, tested behavior.
//
// That wrapped callback only fires once, for whichever of 'listening'/'error'
// happens first. Once the server is up, it's spent — a later server-level
// 'error' (e.g. EMFILE on accept) would otherwise be silently swallowed. The
// separate server.on('error', ...) below exists to catch exactly that case;
// it does not interfere with the initial-bind-failure throw above, since a
// synchronous throw from the first 'error' listener aborts that emit cycle
// before this one runs.
function listen(app, port, serviceName) {
  const server = app.listen(port, '0.0.0.0', (err) => {
    if (err) throw err;
    console.log(`${serviceName} listening on ${port}`);
  });
  server.on('error', (err) => {
    console.error(`${serviceName} server error on port ${port}:`, err);
    process.exit(1);
  });
  return server;
}

module.exports = { listen };
