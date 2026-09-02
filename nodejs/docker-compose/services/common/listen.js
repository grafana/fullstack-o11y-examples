'use strict';

function listen(app, port, serviceName) {
  app.listen(port, '0.0.0.0', (err) => {
    if (err) throw err;
    console.log(`${serviceName} listening on ${port}`);
  });
}

module.exports = { listen };
