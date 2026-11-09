'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function loadDriver(fail = false) {
  const captured = { inputs: [], ended: false };
  const span = {
    spanContext: () => ({ traceId: 'a'.repeat(32), spanId: 'b'.repeat(16), traceFlags: 0 }),
    setStatus: (status) => { captured.status = status; },
    end: () => { captured.ended = true; },
  };
  const request = {
    input: (key, value) => captured.inputs.push([key, value]),
    query: async (sql) => {
      captured.sql = sql;
      if (fail) throw new Error('query rejected');
      return { recordset: [{ book_id: 1 }] };
    },
  };
  class ConnectionPool {
    constructor(config) { captured.config = config; }
    async connect() { return { request: () => request }; }
  }
  const api = {
    SpanKind: { CLIENT: 2 }, SpanStatusCode: { ERROR: 2 },
    trace: { getTracer: () => ({ startActiveSpan: async (name, options, callback) => {
      captured.attributes = options.attributes;
      return callback(span);
    } }) },
  };
  const context = {
    module: { exports: {} }, console, Buffer,
    process: { env: { MSSQL_HOST: 'rds.example', MSSQL_PORT: '1433',
      MSSQL_USER: 'app', MSSQL_PASSWORD: 'test', MSSQL_BOOKSTORE_DB: 'bookstore' } },
    require: (name) => {
      if (name === 'mssql') return { ConnectionPool };
      if (name === 'node:fs') return { readFileSync: () => Buffer.from('test CA') };
      if (name === '@opentelemetry/api') return api;
      throw new Error(`Unexpected dependency: ${name}`);
    },
  };
  const source = path.join(__dirname, '../stacks/nodejs/services/common/sqlserver.js');
  vm.runInNewContext(fs.readFileSync(source, 'utf8'), context);
  return { driver: context.module.exports, captured };
}

test('binds values, verifies TLS, and propagates the actual trace flags', async () => {
  const { driver, captured } = loadDriver();
  const value = "'; DROP TABLE books_inventory;--";
  await driver.query('SELECT * FROM books_inventory WHERE title = @p1', [value]);
  assert.equal(captured.inputs[0][1], value);
  assert.ok(!captured.sql.includes(value));
  assert.ok(captured.sql.includes(`traceparent='00-${'a'.repeat(32)}-${'b'.repeat(16)}-00'`));
  assert.equal(captured.attributes['server.address'], 'rds.example');
  assert.equal(captured.attributes['server.port'], 1433);
  assert.equal(captured.config.options.encrypt, true);
  assert.equal(captured.config.options.trustServerCertificate, false);
  assert.ok(captured.config.options.cryptoCredentialsDetails.ca.length);
  assert.equal(captured.ended, true);
});

test('marks failed queries and ends their spans', async () => {
  const { driver, captured } = loadDriver(true);
  await assert.rejects(driver.query('SELECT @p1', [1]), /query rejected/);
  assert.equal(captured.status.code, 2);
  assert.equal(captured.ended, true);
});
