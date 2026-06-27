import http from 'k6/http';
import { check, sleep } from 'k6';

const target = __ENV.TARGET || 'http://127.0.0.1:18080';
const bundlePath = __ENV.BUNDLE_PATH || 'mobile/assets/content/default_bundle.json';
const multiplier = Number.parseInt(__ENV.BUNDLE_MULTIPLIER || '1', 10);
const queryMode = __ENV.QUERY_MODE || 'versioned';
const queries = [
  'main idea reading',
  'CET-6 vocabulary context',
  'api retry idempotency',
  'mysql composite index',
  'unknown zzz concept',
];

function expandedBundle() {
  const bundle = JSON.parse(open(bundlePath));
  const baseMaterials = bundle.materials || [];
  const baseCards = bundle.cards || [];
  const baseDecks = bundle.decks || [];
  if (multiplier <= 1) {
    return bundle;
  }

  const materials = [];
  const cards = [];
  for (let i = 0; i < multiplier; i += 1) {
    for (const material of baseMaterials) {
      materials.push({
        ...material,
        id: `${material.id}_${i}`,
        title: `${material.title} ${i}`,
      });
    }
    for (const card of baseCards) {
      cards.push({
        ...card,
        id: `${card.id}_${i}`,
        sourceMaterialIds: (card.sourceMaterialIds || []).map((id) => `${id}_${i}`),
      });
    }
  }

  const manifest = bundle.manifest || {};
  return {
    ...bundle,
    manifest: {
      ...manifest,
      version: `${manifest.version || 'loadtest'}-${multiplier}`,
    },
    materials,
    decks: baseDecks,
    cards,
  };
}

const bundle = expandedBundle();
const headers = { 'Content-Type': 'application/json' };
const payloads = queries.map((query) => ({
  query,
  legacyBody: JSON.stringify({ query, bundle }),
}));

export const options = {
  scenarios: {
    mixed_api: {
      executor: 'ramping-vus',
      stages: [
        { duration: __ENV.RAMP_UP || '10s', target: Number.parseInt(__ENV.VUS || '25', 10) },
        { duration: __ENV.HOLD || '20s', target: Number.parseInt(__ENV.VUS || '25', 10) },
        { duration: __ENV.RAMP_DOWN || '5s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

export function setup() {
  const syncResponse = http.post(
    `${target}/content/sync`,
    JSON.stringify({ bundle }),
    { headers },
  );

  if (syncResponse.status !== 200) {
    throw new Error(`content sync failed: ${syncResponse.status} ${syncResponse.body}`);
  }

  const contentVersion = syncResponse.json('contentVersion');
  if (!contentVersion) {
    throw new Error('content sync did not return contentVersion');
  }
  return { contentVersion };
}

export default function (data) {
  const selected = payloads[__ITER % payloads.length];
  const routeIndex = __ITER % 10;

  if (routeIndex === 0) {
    const response = http.get(`${target}/health`);
    check(response, {
      'health status is 200': (r) => r.status === 200,
    });
    sleep(0.05);
    return;
  }

  const path = routeIndex < 5 ? '/lookup' : '/rag/answer';
  const body = queryMode === 'legacy'
    ? selected.legacyBody
    : JSON.stringify({ query: selected.query, contentVersion: data.contentVersion });

  const response = http.post(`${target}${path}`, body, { headers });
  check(response, {
    [`${path} status is 200`]: (r) => r.status === 200,
    [`${path} returns json`]: (r) => (r.headers['Content-Type'] || '').includes('application/json'),
  });
  sleep(0.05);
}