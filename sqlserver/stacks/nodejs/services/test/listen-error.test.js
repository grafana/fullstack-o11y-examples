'use strict';

const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const test = require('node:test');

const servicesDir = path.resolve(__dirname, '..');
const services = ['products', 'checkout', 'shipping'];

function occupyPort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '0.0.0.0', () => {
      resolve({ server, port: server.address().port });
    });
  });
}

function closeServer(server) {
  return new Promise((resolve, reject) => {
    server.close((err) => (err ? reject(err) : resolve()));
  });
}

function runService(service, port) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [`${service}/index.js`], {
      cwd: servicesDir,
      env: { ...process.env, SERVICE_PORT: String(port) },
    });
    let stdout = '';
    let stderr = '';
    let timeout;
    let settled = false;
    const finish = (err, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      err ? reject(err) : resolve(result);
    };

    timeout = setTimeout(() => {
      child.kill('SIGKILL');
      finish(new Error(`${service} did not exit after listen failed`));
    }, 3000);
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.once('error', finish);
    child.once('exit', (code, signal) => {
      finish(null, { code, signal, stdout, stderr });
    });
  });
}

for (const service of services) {
  test(`${service} exits nonzero when its port is already in use`, async () => {
    const { server, port } = await occupyPort();
    try {
      const result = await runService(service, port);
      assert.notEqual(result.code, 0);
      assert.equal(result.signal, null);
      assert.match(result.stderr, /EADDRINUSE/);
      assert.doesNotMatch(result.stdout, new RegExp(`${service} listening`));
    } finally {
      await closeServer(server);
    }
  });
}
