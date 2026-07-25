// Continuous profiling (Pyroscope) bootstrap for the bookstore services.
//
// Started from common/otel.js after the OTel SDK. The @pyroscope/nodejs SDK
// samples wall/CPU time (collectCpuTime) and heap allocations and pushes the
// profiles to Alloy at PYROSCOPE_SERVER_ADDRESS (http://alloy:9999, set in
// docker-compose.yml). Profiling is strictly opt-in: when the address is unset
// (e.g. ../k8s reuses these images without configuring it), this logs one line
// and does nothing, so other consumers of the images are unaffected.
'use strict';

// PYROSCOPE_LABELS uses the Pyroscope Java agent's "k=v,k2=v2" format so every
// stack shares one compose-level convention instead of hardcoding tags here.
function parseLabels() {
  const tags = {};
  for (const pair of (process.env.PYROSCOPE_LABELS || '').split(',')) {
    const [key, ...rest] = pair.trim().split('=');
    if (key && rest.length) tags[key] = rest.join('=');
  }
  return tags;
}

function startProfiling(serviceName) {
  const serverAddress = process.env.PYROSCOPE_SERVER_ADDRESS;
  if (!serverAddress) {
    console.log('pyroscope profiling disabled (PYROSCOPE_SERVER_ADDRESS not set)');
    return;
  }

  // Required lazily so disabled runs never load the SDK (native pprof addon).
  const Pyroscope = require('@pyroscope/nodejs');
  Pyroscope.init({
    serverAddress,
    appName: process.env.PYROSCOPE_APPLICATION_NAME || serviceName,
    tags: parseLabels(),
    // Record CPU time alongside wall time so both profile types are available.
    wall: { collectCpuTime: true },
  });
  Pyroscope.start(); // wall/CPU + heap profilers
}

module.exports = { startProfiling };
