___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "YOM Analytics Server",
  "categories": [
    "ANALYTICS",
    "CONVERSIONS"
  ],
  "brand": {
    "id": "github.com_aapastech",
    "displayName": "YOM (Your Own Metrics)"
  },
  "description": "Sends GA4 ecommerce events (view_item, add_to_cart, begin_checkout, purchase, refund) and generate_lead from your server container to YOM's server ingest, HMAC-signed. Carries Consent Mode, marketing consent and GPC; no personal data is sent. Docs: https://github.com/aapastech/yom-gtm-server-tag",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "secretKey",
    "displayName": "Secret key",
    "simpleValueType": true,
    "help": "A YOM secret key with the <strong>server</strong> scope, for example <strong>yom_sk_live_…</strong>. It signs each request and is never sent. Create it in YOM under Settings → API keys.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^(yom_sk_\\S+|\\{\\{[^}]+\\}\\})$"
        ],
        "errorMessage": "Enter a secret key that starts with yom_sk_."
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "keyId",
    "displayName": "Key id",
    "simpleValueType": true,
    "alwaysInSummary": true,
    "help": "The id of that secret key, for example <strong>key_3f9a…</strong>, shown next to it in YOM.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^(key_\\S+|\\{\\{[^}]+\\}\\})$"
        ],
        "errorMessage": "Enter a key id that starts with key_."
      }
    ]
  },
  {
    "type": "SELECT",
    "name": "consentSource",
    "displayName": "Consent source",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "ga4",
        "displayValue": "Consent Mode in the GA4 hit (gcs / gcd)"
      },
      {
        "value": "fields",
        "displayValue": "Fields below (for example from a variable)"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "ga4",
    "help": "Consent that can't be read is sent as <em>unknown</em>, never as granted. Marketing consent needs both <em>ad_storage</em> and <em>ad_user_data</em> granted."
  },
  {
    "type": "TEXT",
    "name": "analyticsConsent",
    "displayName": "Analytics consent",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "consentSource",
        "paramValue": "fields",
        "type": "EQUALS"
      }
    ],
    "help": "<strong>granted</strong> or <strong>denied</strong> (true / false also work). Anything else is sent as unknown."
  },
  {
    "type": "TEXT",
    "name": "marketingConsent",
    "displayName": "Marketing consent",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "consentSource",
        "paramValue": "fields",
        "type": "EQUALS"
      }
    ],
    "help": "<strong>granted</strong> or <strong>denied</strong>. Leave empty when you don't know; YOM then never forwards the event to ad platforms."
  },
  {
    "type": "TEXT",
    "name": "leadFormId",
    "displayName": "Lead form id",
    "simpleValueType": true,
    "defaultValue": "gtm",
    "help": "Form id sent with <em>generate_lead</em> when the event has no <em>form_id</em>, for example <strong>contact</strong>."
  },
  {
    "type": "GROUP",
    "name": "advanced",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "gpcSignal",
        "displayName": "Global Privacy Control",
        "simpleValueType": true,
        "help": "The tag already reads the browser's <em>Sec-GPC</em> header. Set a variable here if GPC reaches your container another way; <strong>true</strong> or <strong>1</strong> means GPC is on."
      },
      {
        "type": "TEXT",
        "name": "subTenant",
        "displayName": "Sub-tenant",
        "simpleValueType": true,
        "help": "For agencies and platforms that split one YOM project per client site, for example <strong>client-42</strong>."
      },
      {
        "type": "CHECKBOX",
        "name": "debug",
        "checkboxText": "Log requests in preview mode",
        "simpleValueType": true,
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

// YOM Analytics Server — sends GA4 ecommerce and lead events to YOM's server ingest (POST /v2/events),
// HMAC-signed, carrying consent, marketing consent and GPC. Docs: https://github.com/aapastech/yom-gtm-server-tag
const encodeUriComponent = require('encodeUriComponent');
const getAllEventData = require('getAllEventData');
const getRequestHeader = require('getRequestHeader');
const getRequestQueryParameter = require('getRequestQueryParameter');
const getTimestampMillis = require('getTimestampMillis');
const getType = require('getType');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const makeNumber = require('makeNumber');
const makeString = require('makeString');
const Math = require('Math');
const parseUrl = require('parseUrl');
const sendHttpRequest = require('sendHttpRequest');

const INGEST_URL = 'https://ingest.yourownmetrics.aapastech.com/v2/events';
const SDK = 'gtm-server/1.0.0';
const MAPPED_EVENTS = {
  view_item: true,
  add_to_cart: true,
  begin_checkout: true,
  purchase: true,
  refund: true,
  generate_lead: true
};
// Only these fields are sent. user_data, user_id, ip_override, client hints etc. never leave sGTM.
const ORDER_FIELDS = ['transaction_id', 'value', 'currency', 'tax', 'shipping', 'coupon', 'discount',
  'affiliation', 'payment_type', 'shipping_tier', 'lead_source'];
const ITEM_FIELDS = ['item_id', 'item_name', 'item_variant', 'item_brand', 'item_category',
  'item_category2', 'item_category3', 'item_category4', 'item_category5', 'item_list_id',
  'item_list_name', 'coupon', 'discount', 'index', 'price', 'quantity'];
const NUMERIC = { value: true, tax: true, shipping: true, discount: true, price: true, quantity: true, index: true };
const UTM_KEYS = ['source', 'medium', 'campaign', 'term', 'content'];
const CLICK_IDS = ['gclid', 'gbraid', 'wbraid', 'dclid', 'msclkid', 'fbclid', 'ttclid', 'li_fat_id', 'twclid', 'scclid'];
const MAX_ITEMS = 50;

const log = (msg) => {
  if (data.debug) {
    logToConsole('[YOM GTM server] ' + msg);
  }
};

// --- Allow-listed params (no PII) ---

const cleanValue = (field, v) => {
  if (v === undefined || v === null || v === '') {
    return undefined;
  }
  if (NUMERIC[field] === true) {
    const n = makeNumber(v);
    return n === n ? n : undefined;
  }
  const t = getType(v);
  if (t !== 'string' && t !== 'number' && t !== 'boolean') {
    return undefined;
  }
  const s = makeString(v);
  return s.indexOf('@') >= 0 ? undefined : s.substring(0, 200);
};

const pick = (src, fields) => {
  const out = {};
  if (getType(src) !== 'object') {
    return out;
  }
  fields.forEach((f) => {
    const v = cleanValue(f, src[f]);
    if (v !== undefined) {
      out[f] = v;
    }
  });
  return out;
};

const pickItems = (items) => {
  if (getType(items) !== 'array') {
    return undefined;
  }
  return items
    .map((it) => pick(it, ITEM_FIELDS))
    .filter((it) => it.item_id !== undefined)
    .slice(0, MAX_ITEMS);
};

// --- Consent: Google Consent Mode from the GA4 hit, or explicit fields. Unknown stays unknown. ---

// The gcd alphabet as the community decoders use it (Google doesn't publish it). Only bits 0-3 are
// read, and Google emits lowercase letters, which decode the same here and in RFC 4648 base64url
// order (their positions differ by 16).
const GCD_ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

// gcd: one 2-character block per type after the first character (ad_storage at 1, analytics_storage
// at 3, ad_user_data at 5, ad_personalization at 7); the block's second character holds the default
// state in bits 2-3 and the update in bits 0-1 (2 = denied, 3 = granted).
const gcdState = (gcd, offset) => {
  if (getType(gcd) !== 'string' || gcd.length < offset + 2) {
    return undefined;
  }
  const v = GCD_ALPHABET.indexOf(gcd.charAt(offset + 1));
  if (v < 0) {
    return undefined;
  }
  const update = v & 3;
  const state = update > 1 ? update : (v >> 2) & 3;
  return state === 3 ? 'granted' : state === 2 ? 'denied' : undefined;
};

// gcs: "G1" + ad_storage + analytics_storage, each '1' (granted) or '0' (denied).
const gcsState = (gcs, index) => {
  if (getType(gcs) !== 'string' || gcs.length < 4 || gcs.charAt(0) !== 'G') {
    return undefined;
  }
  const c = gcs.charAt(index);
  return c === '1' ? 'granted' : c === '0' ? 'denied' : undefined;
};

const explicitState = (v) => {
  const s = makeString(v).toLowerCase();
  if (v === true || s === 'granted' || s === 'true' || s === '1') {
    return 'granted';
  }
  if (v === false || s === 'denied' || s === 'false' || s === '0') {
    return 'denied';
  }
  return undefined;
};

const resolveConsent = (ev) => {
  if (data.consentSource === 'fields') {
    return {
      analytics: explicitState(data.analyticsConsent) || 'unknown',
      marketing: explicitState(data.marketingConsent)
    };
  }
  const gcs = ev['x-ga-gcs'] || getRequestQueryParameter('gcs');
  const gcd = ev['x-ga-gcd'] || getRequestQueryParameter('gcd');
  const analytics = gcdState(gcd, 3) || gcsState(gcs, 3) || 'unknown';
  const adStorage = gcdState(gcd, 1) || gcsState(gcs, 2);
  const adUserData = gcdState(gcd, 5);
  let marketing;
  if (adStorage === 'denied' || adUserData === 'denied') {
    marketing = 'denied';
  } else if (adStorage === 'granted' && adUserData === 'granted') {
    marketing = 'granted';
  }
  return { analytics: analytics, marketing: marketing };
};

const resolveGpc = () =>
  getRequestHeader('sec-gpc') === '1' || explicitState(data.gpcSignal) === 'granted';

// --- Page context: path-only page, host-only referrer, UTMs and click-id flags ---

const firstValue = (v) => (getType(v) === 'array' ? v[0] : v);

const addPageContext = (env, ev) => {
  const page = getType(ev.page_location) === 'string' ? parseUrl(ev.page_location) : undefined;
  if (page) {
    env.host = page.hostname;
    env.page = page.pathname || '/';
    const q = page.searchParams || {};
    const utm = {};
    let hasUtm = false;
    UTM_KEYS.forEach((k) => {
      const v = firstValue(q['utm_' + k]);
      if (getType(v) === 'string' && v && v.indexOf('@') < 0) {
        utm[k] = v.substring(0, 120);
        hasUtm = true;
      }
    });
    if (hasUtm) {
      env.utm = utm;
    }
    const click = {};
    let hasClick = false;
    CLICK_IDS.forEach((k) => {
      if (q[k] !== undefined && q[k] !== '') {
        click[k] = true;
        hasClick = true;
      }
    });
    if (hasClick) {
      env.click = click;
    }
  }
  const ref = getType(ev.page_referrer) === 'string' ? parseUrl(ev.page_referrer) : undefined;
  if (ref && ref.hostname) {
    env.ref = ref.hostname;
  }
};

// --- HMAC-SHA256 in sandboxed JS (the sandbox has no byte-level string access) ---

const K = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];
const PRINTABLE = ' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
const HEX = '0123456789abcdef';

// UTF-8 bytes of a string: encodeUriComponent keeps unreserved ASCII characters as they are and
// percent-encodes every other byte.
const utf8Bytes = (s) => {
  const enc = encodeUriComponent(s);
  const out = [];
  for (let i = 0; i < enc.length; i++) {
    const ch = enc.charAt(i);
    if (ch === '%') {
      out.push(HEX.indexOf(enc.charAt(i + 1).toLowerCase()) * 16 + HEX.indexOf(enc.charAt(i + 2).toLowerCase()));
      i += 2;
    } else {
      out.push(PRINTABLE.indexOf(ch) + 32);
    }
  }
  return out;
};

const rotr = (x, n) => (x >>> n) | (x << (32 - n));

const sha256 = (bytes) => {
  const h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  const m = bytes.slice();
  const bitLength = bytes.length * 8;
  m.push(0x80);
  while (m.length % 64 !== 56) {
    m.push(0);
  }
  const high = Math.floor(bitLength / 4294967296);
  const low = bitLength >>> 0;
  m.push((high >>> 24) & 255, (high >>> 16) & 255, (high >>> 8) & 255, high & 255);
  m.push((low >>> 24) & 255, (low >>> 16) & 255, (low >>> 8) & 255, low & 255);
  for (let i = 0; i < m.length; i += 64) {
    const w = [];
    for (let t = 0; t < 64; t++) {
      if (t < 16) {
        const j = i + t * 4;
        w.push((m[j] << 24) | (m[j + 1] << 16) | (m[j + 2] << 8) | m[j + 3]);
      } else {
        const s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
        const s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
        w.push((w[t - 16] + s0 + w[t - 7] + s1) | 0);
      }
    }
    let a = h[0];
    let b = h[1];
    let c = h[2];
    let d = h[3];
    let e = h[4];
    let f = h[5];
    let g = h[6];
    let hh = h[7];
    for (let t = 0; t < 64; t++) {
      const S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      const ch = (e & f) ^ ((e ^ 0xffffffff) & g);
      const t1 = (hh + S1 + ch + K[t] + w[t]) | 0;
      const S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const t2 = (S0 + maj) | 0;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) | 0;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) | 0;
    }
    h[0] = (h[0] + a) | 0;
    h[1] = (h[1] + b) | 0;
    h[2] = (h[2] + c) | 0;
    h[3] = (h[3] + d) | 0;
    h[4] = (h[4] + e) | 0;
    h[5] = (h[5] + f) | 0;
    h[6] = (h[6] + g) | 0;
    h[7] = (h[7] + hh) | 0;
  }
  const out = [];
  h.forEach((x) => {
    out.push((x >>> 24) & 255, (x >>> 16) & 255, (x >>> 8) & 255, x & 255);
  });
  return out;
};

const hmacSha256Hex = (key, message) => {
  let k = utf8Bytes(key);
  if (k.length > 64) {
    k = sha256(k);
  }
  while (k.length < 64) {
    k.push(0);
  }
  const inner = k.map((x) => x ^ 0x36);
  const outer = k.map((x) => x ^ 0x5c);
  const digest = sha256(outer.concat(sha256(inner.concat(utf8Bytes(message)))));
  return digest.map((x) => HEX.charAt(x >> 4) + HEX.charAt(x & 15)).join('');
};

// --- Build and send ---

const buildEnvelope = (ev, name) => {
  const params = pick(ev, ORDER_FIELDS);
  const items = pickItems(ev.items);
  if (items) {
    params.items = items;
  }
  const wire = { e: name, t: getTimestampMillis(), p: params };
  if (name === 'purchase' || name === 'refund') {
    if (!params.transaction_id) {
      return undefined;
    }
    if (name === 'purchase') {
      // Same id as the browser purchase for this order, so YOM counts it once.
      wire.id = params.transaction_id;
    } else {
      const refundId = cleanValue('refund_id', ev.refund_id);
      if (refundId) {
        wire.id = params.transaction_id + ':refund:' + refundId;
      }
    }
  }
  if (name === 'generate_lead') {
    params.form_id = cleanValue('form_id', ev.form_id) || data.leadFormId || 'gtm';
  }

  const consent = resolveConsent(ev);
  const env = { v: 2, sdk: SDK, consent: consent.analytics, events: [wire] };
  if (consent.marketing) {
    env.marketing = consent.marketing;
  }
  if (resolveGpc()) {
    env.gpc = true;
  }
  if (data.subTenant) {
    env.st = makeString(data.subTenant);
  }
  addPageContext(env, ev);
  if (ev.ga_session_id !== undefined && ev.ga_session_id !== null) {
    env.session = makeString(ev.ga_session_id).substring(0, 64);
  }
  // A persistent visitor id only with explicit analytics consent.
  if (consent.analytics === 'granted' && getType(ev.client_id) === 'string') {
    env.visitor = ev.client_id.substring(0, 64);
  }
  if (getType(ev.user_agent) === 'string') {
    env.forwarded = { user_agent: ev.user_agent.substring(0, 400) };
  }
  return env;
};

const secretKey = makeString(data.secretKey);
const keyId = makeString(data.keyId);
if (secretKey.indexOf('yom_sk_') !== 0 || keyId.indexOf('key_') !== 0) {
  log('a secret key (yom_sk_...) and its key id (key_...) are required');
  data.gtmOnFailure();
  return;
}

const eventData = getAllEventData();
const eventName = makeString(eventData.event_name);
if (MAPPED_EVENTS[eventName] !== true) {
  log('skipped ' + eventName);
  data.gtmOnSuccess();
  return;
}

const envelope = buildEnvelope(eventData, eventName);
if (!envelope) {
  log(eventName + ' without transaction_id was not sent');
  data.gtmOnFailure();
  return;
}

const body = JSON.stringify(envelope);
const timestamp = makeString(Math.floor(getTimestampMillis() / 1000));
const headers = {
  'Content-Type': 'application/json',
  'YOM-Key-Id': keyId,
  'YOM-Signature': 't=' + timestamp + ',v1=' + hmacSha256Hex(secretKey, timestamp + '.' + body)
};

sendHttpRequest(INGEST_URL, { method: 'POST', headers: headers, timeout: 5000 }, body)
  .then((res) => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      log(eventName + ' accepted');
      data.gtmOnSuccess();
    } else {
      log(eventName + ' rejected: HTTP ' + res.statusCode);
      data.gtmOnFailure();
    }
  })
  .catch(() => {
    log(eventName + ' failed: network error or timeout');
    data.gtmOnFailure();
  });


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "headerWhitelist",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "sec-gpc"
                  }
                ]
              }
            ]
          }
        },
        {
          "key": "headersAllowed",
          "value": {
            "type": 8,
            "boolean": true
          }
        },
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://ingest.yourownmetrics.aapastech.com/"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Signs and posts a purchase to YOM ingest
  code: |-
    runCode(mockData);
    assertThat(request.url).isEqualTo('https://ingest.yourownmetrics.aapastech.com/v2/events');
    assertThat(request.options.method).isEqualTo('POST');
    assertThat(request.options.headers['YOM-Key-Id']).isEqualTo('key_test');
    assertThat(request.options.headers['YOM-Signature']).isEqualTo('t=1700000000,v1=41bea350ac23f85ed8ce5317f550694f670cf3394d01b3f46887af14ce416563');
    const body = JSON.parse(request.body);
    assertThat(body.v).isEqualTo(2);
    assertThat(body.events[0].e).isEqualTo('purchase');
    assertThat(body.events[0].id).isEqualTo('9007199254740993001');
    assertThat(body.events[0].p.transaction_id).isEqualTo('9007199254740993001');
    assertThat(body.events[0].p.items).isEqualTo([{ item_id: 'SKU-1', price: 40, quantity: 2 }]);
    assertApi('gtmOnSuccess').wasCalled();
- name: No PII leaves the container
  code: |-
    runCode(mockData);
    const raw = request.body;
    assertThat(raw.indexOf('jane.doe@example.com')).isEqualTo(-1);
    assertThat(raw.indexOf('+1 650 555 0100')).isEqualTo(-1);
    assertThat(raw.indexOf('203.0.113.7')).isEqualTo(-1);
    assertThat(raw.indexOf('crm-42')).isEqualTo(-1);
    assertThat(raw.indexOf('token=abc')).isEqualTo(-1);
- name: Page is path-only, referrer host-only, UTMs and click ids extracted
  code: |-
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.host).isEqualTo('shop.example.com');
    assertThat(body.page).isEqualTo('/checkout/thanks');
    assertThat(body.ref).isEqualTo('www.google.com');
    assertThat(body.utm).isEqualTo({ source: 'newsletter', medium: 'email' });
    assertThat(body.click).isEqualTo({ gclid: true });
- name: Unknown consent stays unknown, no marketing, no visitor id
  code: |-
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.consent).isEqualTo('unknown');
    assertThat(body.marketing).isUndefined();
    assertThat(body.visitor).isUndefined();
    assertThat(body.gpc).isUndefined();
- name: Consent Mode from the GA4 hit and GPC are carried
  code: |-
    eventData['x-ga-gcs'] = 'G111';
    eventData['x-ga-gcd'] = '13r3r3r3r5';
    headers['sec-gpc'] = '1';
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.consent).isEqualTo('granted');
    assertThat(body.marketing).isEqualTo('granted');
    assertThat(body.gpc).isTrue();
    assertThat(body.visitor).isEqualTo('123.456');
- name: ad_user_data denied means marketing denied
  code: |-
    eventData['x-ga-gcd'] = '13r3r3p3r5';
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.consent).isEqualTo('granted');
    assertThat(body.marketing).isEqualTo('denied');
- name: Explicit consent fields are used when selected
  code: |-
    mockData.consentSource = 'fields';
    mockData.analyticsConsent = 'denied';
    mockData.marketingConsent = 'maybe';
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.consent).isEqualTo('denied');
    assertThat(body.marketing).isUndefined();
- name: Refund id is keyed to the order
  code: |-
    eventData.event_name = 'refund';
    eventData.refund_id = 'R-7';
    eventData.value = 20;
    runCode(mockData);
    const body = JSON.parse(request.body);
    assertThat(body.events[0].id).isEqualTo('9007199254740993001:refund:R-7');
- name: Events YOM does not map are skipped
  code: |-
    eventData.event_name = 'page_view';
    runCode(mockData);
    assertThat(request).isUndefined();
    assertApi('gtmOnSuccess').wasCalled();
- name: A rejected request fails the tag
  code: |-
    status = 401;
    runCode(mockData);
    assertApi('gtmOnFailure').wasCalled();
    assertApi('gtmOnSuccess').wasNotCalled();
- name: Missing keys fail without sending
  code: |-
    mockData.secretKey = '';
    runCode(mockData);
    assertThat(request).isUndefined();
    assertApi('gtmOnFailure').wasCalled();
setup: |-
  const JSON = require('JSON');
  const mockData = {
    secretKey: 'yom_sk_test_secret',
    keyId: 'key_test',
    consentSource: 'ga4',
    debug: false
  };
  const eventData = {
    event_name: 'purchase',
    transaction_id: '9007199254740993001',
    value: 85,
    currency: 'USD',
    tax: 5,
    shipping: 0,
    items: [{ item_id: 'SKU-1', item_name: 'jane.doe@example.com', price: 40, quantity: 2 }],
    page_location: 'https://shop.example.com/checkout/thanks?token=abc&utm_source=newsletter&utm_medium=email&gclid=xyz#done',
    page_referrer: 'https://www.google.com/search?q=chairs',
    client_id: '123.456',
    ga_session_id: '1700000000',
    user_id: 'crm-42',
    ip_override: '203.0.113.7',
    user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Safari/605.1.15',
    user_data: {
      email_address: 'jane.doe@example.com',
      phone_number: '+1 650 555 0100',
      address: { first_name: 'Jane', last_name: 'Doe', street: '1 Main St', postal_code: '94000' }
    }
  };
  const headers = {};
  let request;
  let status = 202;
  mock('getAllEventData', () => eventData);
  mock('getRequestHeader', (name) => headers[name]);
  mock('getRequestQueryParameter', () => undefined);
  mock('getTimestampMillis', () => 1700000000000);
  mock('sendHttpRequest', (url, options, body) => {
    request = { url: url, options: options, body: body };
    return {
      then: (onResponse) => {
        onResponse({ statusCode: status, headers: {}, body: '' });
        return { catch: () => {} };
      }
    };
  });


___NOTES___

YOM Analytics Server tag template, version 1.0.0.
Source of truth: integrations/gtm in the YOM repository; published copies are synced from there.


