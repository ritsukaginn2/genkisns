import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import test from 'node:test';

import { loadConfig } from '../src/config.js';
import { createApp } from '../src/http.js';
import { hashPassword } from '../src/auth/passwords.js';
import { assignDeliveryDelays } from '../src/queue.js';
import { buildInteractionRequest } from '../src/request.js';
import { SqliteStore } from '../src/store.js';

async function seedAdmin(app, { username = 'root', password = 'supersecret', role = 'owner' } = {}) {
  await app.store.createAdmin({ username, passwordHash: hashPassword(password), role });
  return { username, password, role };
}

async function adminLogin(baseUrl, username, password) {
  const { json } = await jsonRequest(baseUrl, '/admin/login', {
    method: 'POST',
    body: { username, password },
  });
  return json.token;
}

function authHeaders(token) {
  return { Authorization: `Bearer ${token}` };
}

async function startTestApp(overrides = {}, { provider } = {}) {
  const dir = await mkdtemp(join(tmpdir(), 'genki-llm-proxy-'));
  const config = {
    ...loadConfig({
      DATA_FILE: join(dir, 'store.db'),
      INTERNAL_TOKEN: 'internal-test-token',
      LLM_PROVIDER: 'stub',
      LOG_LEVEL: 'error',
      INSTALLATION_RATE_LIMIT_PER_MINUTE: '20',
      IP_RATE_LIMIT_PER_MINUTE: '20',
      DAILY_JOB_LIMIT: '20',
      DAILY_BUDGET_CENTS: '20',
    }),
    ...overrides,
  };
  const app = await createApp({
    config,
    store: new SqliteStore(config.dataFile),
    provider,
  });
  await new Promise((resolve) => app.server.listen(0, '127.0.0.1', resolve));
  const address = app.server.address();
  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    config,
    store: app.store,
    async close() {
      await new Promise((resolve) => app.server.close(resolve));
      await app.queue.onIdle();
      app.store.close();
      await rm(dir, { recursive: true, force: true });
    },
  };
}

async function jsonRequest(baseUrl, path, { method = 'GET', headers = {}, body } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  return { response, json };
}

function validJobBody(overrides = {}) {
  return {
    post_id: 'post_test_1',
    text: '今天过得还不错。',
    media: {
      image_count: 1,
      has_video: false,
      video_count: 0,
    },
    user: {
      nickname: 'Ritsuka',
      bio: '把开心存在这里。',
    },
    friends: [
      {
        id: 'friend_mika',
        name: '美香',
        relationship: '高中同学',
        personality: '会夸、爱起哄',
        speaking_style: '像很熟的老朋友。',
      },
    ],
    ...overrides,
  };
}

test('registers installation and preserves review status on refresh', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'test_installation_1234';
    const first = await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: {
        installation_id: installationId,
        platform: 'ios',
        app_version: '1.0',
      },
    });
    assert.equal(first.response.status, 200);
    assert.equal(first.json.status, 'allowed');

    const blocked = await jsonRequest(
      app.baseUrl,
      `/internal/installations/${installationId}/status`,
      {
        method: 'POST',
        headers: { 'X-Internal-Token': 'internal-test-token' },
        body: { status: 'blocked', reason: 'manual review' },
      },
    );
    assert.equal(blocked.response.status, 200);
    assert.equal(blocked.json.status, 'blocked');

    const refreshed = await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: {
        installation_id: installationId,
        platform: 'ios',
        app_version: '1.0.1',
      },
    });
    assert.equal(refreshed.response.status, 200);
    assert.equal(refreshed.json.status, 'blocked');
  } finally {
    await app.close();
  }
});

test('blocked installation gets fallback-friendly job response', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'blocked_installation_1234';
    await jsonRequest(
      app.baseUrl,
      `/internal/installations/${installationId}/status`,
      {
        method: 'POST',
        headers: { 'X-Internal-Token': 'internal-test-token' },
        body: { status: 'blocked', reason: 'abuse' },
      },
    );

    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.json.status, 'failed');
    assert.equal(result.json.reason, 'installation_blocked');
    assert.equal(result.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('limited installation gets fallback-friendly job response', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'limited_review_installation_1234';
    await jsonRequest(
      app.baseUrl,
      `/internal/installations/${installationId}/status`,
      {
        method: 'POST',
        headers: { 'X-Internal-Token': 'internal-test-token' },
        body: { status: 'limited', reason: 'manual throttle' },
      },
    );

    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.json.status, 'failed');
    assert.equal(result.json.reason, 'installation_limited');
    assert.equal(result.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('content review rejects blocked terms before queueing', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'content_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ text: '这条包含 BLOCK_ME 测试词。' }),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.json.reason, 'content_rejected');
    assert.equal(result.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('queues job and returns validated generated result', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'queued_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(created.response.status, 202);
    assert.match(created.json.job_id, /^job_/);
    assert.equal(created.json.status, 'queued');

    let detail;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      detail = await jsonRequest(app.baseUrl, `/v1/interactions/jobs/${created.json.job_id}`, {
        headers: { 'X-Installation-Id': installationId },
      });
      if (detail.json.status === 'completed') break;
      await delay(25);
    }

    assert.equal(detail.response.status, 200);
    assert.equal(detail.json.status, 'completed');
    assert.equal(detail.json.result.comments[0].actor_id, 'friend_mika');
    assert.equal(typeof detail.json.result.ai_like_count, 'number');
  } finally {
    await app.close();
  }
});

test('invalid LLM result fails the job with fallback signal', async () => {
  const provider = {
    async generate() {
      return {
        ai_like_count: 9,
        comments: [
          {
            actor_id: 'unknown_friend',
            content: '这条应该被校验拦下。',
            like_count: 1,
          },
        ],
      };
    },
  };
  const app = await startTestApp({}, { provider });
  try {
    const installationId = 'invalid_result_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(created.response.status, 202);

    let detail;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      detail = await jsonRequest(app.baseUrl, `/v1/interactions/jobs/${created.json.job_id}`, {
        headers: { 'X-Installation-Id': installationId },
      });
      if (detail.json.status === 'failed') break;
      await delay(25);
    }

    assert.equal(detail.response.status, 200);
    assert.equal(detail.json.status, 'failed');
    assert.equal(detail.json.reason, 'unknown_actor_id:unknown_friend');
    assert.equal(detail.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('rate limits per installation with fallback signal', async () => {
  const app = await startTestApp({ installationRateLimitPerMinute: 1 });
  try {
    const installationId = 'limited_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });
    const first = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ post_id: 'post_first' }),
    });
    assert.equal(first.response.status, 202);

    const second = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ post_id: 'post_second' }),
    });
    assert.equal(second.response.status, 429);
    assert.equal(second.json.fallback_required, true);
    assert.equal(second.json.detail, 'installation_rate_limited');
  } finally {
    await app.close();
  }
});

test('rate limits per IP with fallback signal', async () => {
  const app = await startTestApp({
    installationRateLimitPerMinute: 20,
    ipRateLimitPerMinute: 1,
  });
  try {
    const firstInstallationId = 'ip_limit_installation_1';
    const secondInstallationId = 'ip_limit_installation_2';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: firstInstallationId, platform: 'ios' },
    });
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: secondInstallationId, platform: 'ios' },
    });

    const first = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': firstInstallationId },
      body: validJobBody({ post_id: 'post_ip_first' }),
    });
    assert.equal(first.response.status, 202);

    const second = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': secondInstallationId },
      body: validJobBody({ post_id: 'post_ip_second' }),
    });
    assert.equal(second.response.status, 429);
    assert.equal(second.json.fallback_required, true);
    assert.equal(second.json.detail, 'ip_rate_limited');
  } finally {
    await app.close();
  }
});

test('daily job limit guard is enforced when jobs are submitted concurrently', async () => {
  const app = await startTestApp({
    dailyJobLimit: 1,
    dailyBudgetCents: 100,
    installationRateLimitPerMinute: 20,
    ipRateLimitPerMinute: 20,
  });
  try {
    const installationId = 'budget_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const results = await Promise.all([
      jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
        method: 'POST',
        headers: { 'X-Installation-Id': installationId },
        body: validJobBody({ post_id: 'post_budget_first' }),
      }),
      jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
        method: 'POST',
        headers: { 'X-Installation-Id': installationId },
        body: validJobBody({ post_id: 'post_budget_second' }),
      }),
    ]);

    const statuses = results.map((result) => result.response.status).sort();
    assert.deepEqual(statuses, [200, 202]);
    const fallback = results.find((result) => result.response.status === 200);
    assert.equal(fallback.json.reason, 'daily_job_limit');
    assert.equal(fallback.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('daily budget limit is enforced independently of the job limit', async () => {
  const app = await startTestApp({
    dailyJobLimit: 10,
    dailyBudgetCents: 3,
    estimatedJobCostCents: 2,
    installationRateLimitPerMinute: 20,
    ipRateLimitPerMinute: 20,
  });
  try {
    const installationId = 'budget_only_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    // First job costs 2 of 3 cents -> allowed.
    const first = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ post_id: 'post_budget_a' }),
    });
    assert.equal(first.response.status, 202);

    // Second job would bring spend to 4 > 3 cents while still under the job
    // limit (2 of 10) -> rejected specifically by the budget guard.
    const second = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ post_id: 'post_budget_b' }),
    });
    assert.equal(second.response.status, 200);
    assert.equal(second.json.reason, 'daily_budget_limit');
    assert.equal(second.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('content review rejects text longer than maxTextLength', async () => {
  const app = await startTestApp({ maxTextLength: 50 });
  try {
    const installationId = 'too_long_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ text: 'a'.repeat(51) }),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.json.reason, 'content_too_long');
    assert.equal(result.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('invalid LLM result with an over-long comment fails with fallback signal', async () => {
  const provider = {
    async generate() {
      return {
        ai_like_count: 5,
        comments: [
          { actor_id: 'friend_mika', content: 'x'.repeat(161), like_count: 1 },
        ],
      };
    },
  };
  const app = await startTestApp({}, { provider });
  try {
    const installationId = 'too_long_comment_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(created.response.status, 202);

    let detail;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      detail = await jsonRequest(app.baseUrl, `/v1/interactions/jobs/${created.json.job_id}`, {
        headers: { 'X-Installation-Id': installationId },
      });
      if (detail.json.status === 'failed') break;
      await delay(25);
    }

    assert.equal(detail.json.status, 'failed');
    assert.equal(detail.json.reason, 'comment_too_long:0');
    assert.equal(detail.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('invalid LLM result with empty comments fails with fallback signal', async () => {
  const provider = {
    async generate() {
      return { ai_like_count: 5, comments: [] };
    },
  };
  const app = await startTestApp({}, { provider });
  try {
    const installationId = 'empty_comments_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(created.response.status, 202);

    let detail;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      detail = await jsonRequest(app.baseUrl, `/v1/interactions/jobs/${created.json.job_id}`, {
        headers: { 'X-Installation-Id': installationId },
      });
      if (detail.json.status === 'failed') break;
      await delay(25);
    }

    assert.equal(detail.json.status, 'failed');
    assert.equal(detail.json.reason, 'comments_empty');
    assert.equal(detail.json.fallback_required, true);
  } finally {
    await app.close();
  }
});

test('job creation requires the X-Installation-Id header', async () => {
  const app = await startTestApp();
  try {
    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      body: validJobBody(),
    });
    assert.equal(result.response.status, 401);
    assert.equal(result.json.error, 'unauthorized');
  } finally {
    await app.close();
  }
});

test('internal status endpoint rejects a missing internal token', async () => {
  const app = await startTestApp();
  try {
    const result = await jsonRequest(
      app.baseUrl,
      '/internal/installations/some_installation_1234/status',
      { method: 'POST', body: { status: 'blocked' } },
    );
    assert.equal(result.response.status, 401);
    assert.equal(result.json.error, 'unauthorized');
  } finally {
    await app.close();
  }
});

test('internal status endpoint rejects a wrong internal token', async () => {
  const app = await startTestApp();
  try {
    const result = await jsonRequest(
      app.baseUrl,
      '/internal/installations/some_installation_1234/status',
      {
        method: 'POST',
        headers: { 'X-Internal-Token': 'wrong-token' },
        body: { status: 'blocked' },
      },
    );
    assert.equal(result.response.status, 401);
    assert.equal(result.json.error, 'unauthorized');
  } finally {
    await app.close();
  }
});

test('per-IP rate limit ignores spoofed X-Forwarded-For by default', async () => {
  const app = await startTestApp({
    installationRateLimitPerMinute: 20,
    ipRateLimitPerMinute: 1,
  });
  try {
    const firstInstallationId = 'xff_installation_1';
    const secondInstallationId = 'xff_installation_2';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: firstInstallationId, platform: 'ios' },
    });
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: secondInstallationId, platform: 'ios' },
    });

    const first = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: {
        'X-Installation-Id': firstInstallationId,
        'X-Forwarded-For': '10.0.0.1',
      },
      body: validJobBody({ post_id: 'post_xff_first' }),
    });
    assert.equal(first.response.status, 202);

    // A different spoofed XFF must NOT grant a fresh per-IP budget: both share
    // the same real socket address, so the second request is still limited.
    const second = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: {
        'X-Installation-Id': secondInstallationId,
        'X-Forwarded-For': '10.0.0.2',
      },
      body: validJobBody({ post_id: 'post_xff_second' }),
    });
    assert.equal(second.response.status, 429);
    assert.equal(second.json.detail, 'ip_rate_limited');
  } finally {
    await app.close();
  }
});

test('stale queued/processing jobs are failed on restart', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'genki-llm-proxy-stale-'));
  try {
    const config = loadConfig({
      DATA_FILE: join(dir, 'store.db'),
      INTERNAL_TOKEN: 'internal-test-token',
      LLM_PROVIDER: 'stub',
    });

    // Seed a job stuck in "processing" as if the server crashed mid-run.
    const seedStore = new SqliteStore(config.dataFile);
    await seedStore.load();
    await seedStore.createJob({
      job_id: 'job_stale_1',
      installation_id: 'stale_installation_1234',
      status: 'processing',
      request: {},
      fallback_required: false,
      created_at: '2026-06-14T00:00:00.000Z',
      updated_at: '2026-06-14T00:00:00.000Z',
    });
    seedStore.close();

    // Restart: a fresh app on the same data file runs markStaleJobsFailed.
    const app = await createApp({
      config,
      store: new SqliteStore(config.dataFile),
    });
    const job = await app.store.getJob('job_stale_1');
    assert.equal(job.status, 'failed');
    assert.equal(job.reason, 'server_restarted');
    assert.equal(job.fallback_required, true);
    await app.queue.onIdle();
    app.store.close();
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('assignDeliveryDelays staggers comments and caps the max', () => {
  const config = loadConfig({
    COMMENT_FIRST_DELAY_SECONDS: '4',
    COMMENT_DELAY_GAP_SECONDS: '18',
    COMMENT_MAX_DELAY_SECONDS: '30',
  });
  const comments = [{}, {}, {}];
  assignDeliveryDelays(comments, config);
  assert.deepEqual(
    comments.map((c) => c.delay_seconds),
    [4, 22, 30], // 4, 4+18=22, 4+36=40 -> capped at 30
  );
});

test('completed job comments carry staggered delay_seconds', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'delay_installation_1234';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({
        friends: [
          { id: 'friend_mika', name: '美香' },
          { id: 'friend_sen', name: '森' },
          { id: 'friend_aki', name: 'Aki' },
        ],
      }),
    });
    assert.equal(created.response.status, 202);

    let detail;
    for (let attempt = 0; attempt < 10; attempt += 1) {
      detail = await jsonRequest(app.baseUrl, `/v1/interactions/jobs/${created.json.job_id}`, {
        headers: { 'X-Installation-Id': installationId },
      });
      if (detail.json.status === 'completed') break;
      await delay(25);
    }
    assert.equal(detail.json.status, 'completed');
    const delays = detail.json.result.comments.map((c) => c.delay_seconds);
    assert.equal(delays[0], 4);
    for (let i = 1; i < delays.length; i += 1) {
      assert.ok(delays[i] > delays[i - 1], 'delays must increase');
    }
  } finally {
    await app.close();
  }
});

test('buildInteractionRequest caps the friend count to maxFriends', () => {
  const config = loadConfig({ MAX_FRIENDS: '3' });
  const friends = Array.from({ length: 20 }, (_, index) => ({
    id: `friend_${index}`,
    name: `Friend ${index}`,
  }));
  const request = buildInteractionRequest(
    { post_id: 'post_cap', text: 'hello', friends },
    { maxFriends: config.maxFriends },
  );
  assert.equal(request.friends.length, 3);
  assert.equal(request.friend_ids.length, 3);
});

test('readyz reports ready with the stub provider', async () => {
  const app = await startTestApp();
  try {
    const result = await jsonRequest(app.baseUrl, '/readyz');
    assert.equal(result.response.status, 200);
    assert.equal(result.json.ok, true);
    assert.equal(result.json.db, true);
  } finally {
    await app.close();
  }
});

test('admin can log in, read /me, and log out', async () => {
  const app = await startTestApp();
  try {
    await seedAdmin(app, { username: 'root', password: 'supersecret', role: 'owner' });

    const bad = await jsonRequest(app.baseUrl, '/admin/login', {
      method: 'POST',
      body: { username: 'root', password: 'wrong' },
    });
    assert.equal(bad.response.status, 401);
    assert.equal(bad.json.error, 'invalid_credentials');

    const login = await jsonRequest(app.baseUrl, '/admin/login', {
      method: 'POST',
      body: { username: 'root', password: 'supersecret' },
    });
    assert.equal(login.response.status, 200);
    assert.equal(login.json.role, 'owner');
    const token = login.json.token;
    assert.ok(token && token.length > 20);

    const me = await jsonRequest(app.baseUrl, '/admin/me', { headers: authHeaders(token) });
    assert.equal(me.response.status, 200);
    assert.equal(me.json.username, 'root');

    const logout = await jsonRequest(app.baseUrl, '/admin/logout', {
      method: 'POST',
      headers: authHeaders(token),
    });
    assert.equal(logout.response.status, 204);

    const afterLogout = await jsonRequest(app.baseUrl, '/admin/me', { headers: authHeaders(token) });
    assert.equal(afterLogout.response.status, 401);
  } finally {
    await app.close();
  }
});

test('admin endpoints reject missing or invalid tokens', async () => {
  const app = await startTestApp();
  try {
    const noToken = await jsonRequest(app.baseUrl, '/admin/stats');
    assert.equal(noToken.response.status, 401);
    const badToken = await jsonRequest(app.baseUrl, '/admin/stats', {
      headers: authHeaders('not-a-real-token'),
    });
    assert.equal(badToken.response.status, 401);
  } finally {
    await app.close();
  }
});

test('role enforcement: viewer cannot moderate, admin can', async () => {
  const app = await startTestApp();
  try {
    await seedAdmin(app, { username: 'viewer1', password: 'viewerpass', role: 'viewer' });
    await seedAdmin(app, { username: 'admin1', password: 'adminpass1', role: 'admin' });
    const installationId = 'role_target_installation_1';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });

    const viewerToken = await adminLogin(app.baseUrl, 'viewer1', 'viewerpass');
    const viewerAttempt = await jsonRequest(
      app.baseUrl,
      `/admin/installations/${installationId}/status`,
      { method: 'POST', headers: authHeaders(viewerToken), body: { status: 'blocked' } },
    );
    assert.equal(viewerAttempt.response.status, 403);

    const adminToken = await adminLogin(app.baseUrl, 'admin1', 'adminpass1');
    const adminAttempt = await jsonRequest(
      app.baseUrl,
      `/admin/installations/${installationId}/status`,
      {
        method: 'POST',
        headers: authHeaders(adminToken),
        body: { status: 'blocked', reason: 'abuse' },
      },
    );
    assert.equal(adminAttempt.response.status, 200);
    assert.equal(adminAttempt.json.status, 'blocked');

    const detail = await jsonRequest(app.baseUrl, `/admin/installations/${installationId}`, {
      headers: authHeaders(adminToken),
    });
    assert.equal(detail.json.installation.status, 'blocked');
    assert.ok(detail.json.audit.some((entry) => entry.source === 'admin:admin1'));
  } finally {
    await app.close();
  }
});

test('only owners can manage admin accounts', async () => {
  const app = await startTestApp();
  try {
    await seedAdmin(app, { username: 'owner1', password: 'ownerpass1', role: 'owner' });
    const ownerToken = await adminLogin(app.baseUrl, 'owner1', 'ownerpass1');

    const created = await jsonRequest(app.baseUrl, '/admin/admins', {
      method: 'POST',
      headers: authHeaders(ownerToken),
      body: { username: 'mod1', password: 'modpass12', role: 'admin' },
    });
    assert.equal(created.response.status, 201);
    assert.equal(created.json.role, 'admin');

    const dup = await jsonRequest(app.baseUrl, '/admin/admins', {
      method: 'POST',
      headers: authHeaders(ownerToken),
      body: { username: 'mod1', password: 'modpass12', role: 'admin' },
    });
    assert.equal(dup.response.status, 409);

    const weak = await jsonRequest(app.baseUrl, '/admin/admins', {
      method: 'POST',
      headers: authHeaders(ownerToken),
      body: { username: 'mod2', password: 'short', role: 'admin' },
    });
    assert.equal(weak.response.status, 400);

    const modToken = await adminLogin(app.baseUrl, 'mod1', 'modpass12');
    const forbidden = await jsonRequest(app.baseUrl, '/admin/admins', {
      headers: authHeaders(modToken),
    });
    assert.equal(forbidden.response.status, 403);
  } finally {
    await app.close();
  }
});

test('admin can list and inspect installations and jobs', async () => {
  const app = await startTestApp();
  try {
    await seedAdmin(app, { username: 'root', password: 'supersecret', role: 'owner' });
    const token = await adminLogin(app.baseUrl, 'root', 'supersecret');
    const installationId = 'inspect_installation_1';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });
    const created = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody(),
    });
    assert.equal(created.response.status, 202);

    const list = await jsonRequest(app.baseUrl, '/admin/installations?status=allowed', {
      headers: authHeaders(token),
    });
    assert.equal(list.response.status, 200);
    assert.ok(list.json.total >= 1);
    assert.ok(list.json.items.some((i) => i.installation_id === installationId));

    const jobs = await jsonRequest(
      app.baseUrl,
      `/admin/jobs?installation_id=${installationId}`,
      { headers: authHeaders(token) },
    );
    assert.equal(jobs.response.status, 200);
    assert.ok(jobs.json.items.length >= 1);

    const stats = await jsonRequest(app.baseUrl, '/admin/stats', { headers: authHeaders(token) });
    assert.equal(stats.response.status, 200);
    assert.ok(stats.json.installations >= 1);
  } finally {
    await app.close();
  }
});

test('device token is issued on registration and enforced when required', async () => {
  const app = await startTestApp({ requireDeviceToken: true });
  try {
    const installationId = 'device_token_installation_1';
    const register = await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });
    assert.equal(register.response.status, 200);
    const deviceToken = register.json.device_token;
    assert.ok(deviceToken && deviceToken.length > 20);

    const noToken = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ post_id: 'p_notoken' }),
    });
    assert.equal(noToken.response.status, 401);

    const wrongToken = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId, 'X-Device-Token': 'wrong' },
      body: validJobBody({ post_id: 'p_wrong' }),
    });
    assert.equal(wrongToken.response.status, 401);

    const ok = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId, 'X-Device-Token': deviceToken },
      body: validJobBody({ post_id: 'p_ok' }),
    });
    assert.equal(ok.response.status, 202);
  } finally {
    await app.close();
  }
});

test('job creation rejects an unregistered installation (no auto-provision)', async () => {
  const app = await startTestApp();
  try {
    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': 'never_registered_install_1' },
      body: validJobBody(),
    });
    assert.equal(result.response.status, 401);
    assert.equal(result.json.error, 'unauthorized');
  } finally {
    await app.close();
  }
});

test('content review screens friend.id (a field that reaches the LLM)', async () => {
  const app = await startTestApp();
  try {
    const installationId = 'friend_id_review_installation';
    await jsonRequest(app.baseUrl, '/v1/installations', {
      method: 'POST',
      body: { installation_id: installationId, platform: 'ios' },
    });
    const result = await jsonRequest(app.baseUrl, '/v1/interactions/jobs', {
      method: 'POST',
      headers: { 'X-Installation-Id': installationId },
      body: validJobBody({ friends: [{ id: 'BLOCK_ME', name: '美香' }] }),
    });
    assert.equal(result.response.status, 200);
    assert.equal(result.json.reason, 'content_rejected');
    assert.equal(result.json.fallback_required, true);
  } finally {
    await app.close();
  }
});
