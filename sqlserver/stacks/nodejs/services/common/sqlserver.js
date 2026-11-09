'use strict';

const sql = require('mssql');
const { SpanKind, SpanStatusCode, trace } = require('@opentelemetry/api');

const database = process.env.MSSQL_DATABASE ||
  (process.env.SERVICE_PORT === '8003' ? process.env.MSSQL_SHIPPING_DB : process.env.MSSQL_BOOKSTORE_DB) ||
  'bookstore';
const poolPromise = new sql.ConnectionPool({
  server: process.env.MSSQL_HOST,
  port: parseInt(process.env.MSSQL_PORT || '1433', 10),
  user: process.env.MSSQL_USER,
  password: process.env.MSSQL_PASSWORD,
  database,
  options: {
    encrypt: true,
    cryptoCredentialsDetails: { ca: require('node:fs').readFileSync('/etc/ssl/certs/rds-ca-bundle.pem') },
    trustServerCertificate: process.env.MSSQL_TRUST_SERVER_CERTIFICATE === 'true',
  },
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
}).connect();

poolPromise.catch((error) => {
  console.error('SQL Server connection failed:', error.message);
});

const tracer = trace.getTracer('bookstore-mssql');

async function query(statement, values = [], executor = null) {
  return tracer.startActiveSpan('mssql.query', {
    kind: SpanKind.CLIENT,
    attributes: {
      'db.system': 'mssql', 'db.name': database, 'db.statement': statement,
      'server.address': process.env.MSSQL_HOST,
      'server.port': Number(process.env.MSSQL_PORT || '1433'),
      'net.peer.name': process.env.MSSQL_HOST,
      'net.peer.port': Number(process.env.MSSQL_PORT || '1433'),
    },
  }, async (span) => {
    try {
      const target = executor || await poolPromise;
      const request = target.request();
      values.forEach((value, index) => request.input('p' + (index + 1), value));
      const spanContext = span.spanContext();
      const flags = spanContext.traceFlags.toString(16).padStart(2, '0');
      const queryText = statement + " /*traceparent='00-" + spanContext.traceId + "-" +
        spanContext.spanId + "-" + flags + "',db_driver='tedious'*/";
      return await request.query(queryText);
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
      throw error;
    } finally {
      span.end();
    }
  });
}

async function beginTransaction() {
  const transaction = new sql.Transaction(await poolPromise);
  await transaction.begin();
  return transaction;
}

module.exports = { beginTransaction, query };
