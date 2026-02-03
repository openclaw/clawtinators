'use strict';

const AWS = require('aws-sdk');

const {
  CONTROL_API_TOKEN,
  GITHUB_TOKEN,
  GITHUB_REPO,
  GITHUB_WORKFLOW,
  GITHUB_REF,
} = process.env;

function json(statusCode, payload) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  };
}

function unauthorized() {
  return json(401, { ok: false, error: 'unauthorized' });
}

function badRequest(message) {
  return json(400, { ok: false, error: message });
}

function getAuthToken(headers) {
  const auth = headers.authorization || headers.Authorization;
  if (!auth) return null;
  const match = auth.match(/Bearer\s+(.+)/i);
  return match ? match[1] : null;
}

async function dispatchWorkflow(inputs) {
  const repo = GITHUB_REPO || 'openclaw/clawdinators';
  const workflow = GITHUB_WORKFLOW || 'fleet-deploy.yml';
  const ref = GITHUB_REF || 'main';

  const res = await fetch(`https://api.github.com/repos/${repo}/actions/workflows/${workflow}/dispatches`, {
    method: 'POST',
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      'User-Agent': 'clawdinator-control',
    },
    body: JSON.stringify({ ref, inputs }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`workflow dispatch failed: ${res.status} ${body}`);
  }
}

async function listInstances() {
  const ec2 = new AWS.EC2();
  const resp = await ec2
    .describeInstances({
      Filters: [{ Name: 'tag:app', Values: ['clawdinator'] }],
    })
    .promise();

  const instances = [];
  for (const reservation of resp.Reservations || []) {
    for (const instance of reservation.Instances || []) {
      const tags = instance.Tags || [];
      const nameTag = tags.find((tag) => tag.Key === 'Name');
      instances.push({
        name: nameTag ? nameTag.Value : 'unknown',
        id: instance.InstanceId,
        state: instance.State ? instance.State.Name : 'unknown',
        ami: instance.ImageId,
        ip: instance.PublicIpAddress || 'n/a',
      });
    }
  }

  return instances;
}

exports.handler = async (event) => {
  if (!CONTROL_API_TOKEN) {
    return json(500, { ok: false, error: 'missing CONTROL_API_TOKEN' });
  }

  const headers = event.headers || {};
  const token = getAuthToken(headers);
  if (!token || token !== CONTROL_API_TOKEN) {
    return unauthorized();
  }

  if (!event.body) {
    return badRequest('missing body');
  }

  const body = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64').toString('utf-8')
    : event.body;

  let payload;
  try {
    payload = JSON.parse(body);
  } catch (err) {
    return badRequest('invalid json');
  }

  const action = (payload.action || '').toLowerCase();
  const target = payload.target;
  const caller = payload.caller;
  const amiOverride = payload.ami_override || '';

  if (action === 'status') {
    try {
      const instances = await listInstances();
      return json(200, { ok: true, instances });
    } catch (err) {
      return json(500, { ok: false, error: err.message });
    }
  }

  if (action !== 'deploy') {
    return badRequest('unsupported action');
  }

  if (!target) {
    return badRequest('target required');
  }

  if (caller && target === caller) {
    return badRequest('refusing self-deploy');
  }

  if (!GITHUB_TOKEN) {
    return json(500, { ok: false, error: 'missing GITHUB_TOKEN' });
  }

  try {
    await dispatchWorkflow({
      target,
      ami_override: amiOverride,
    });
    return json(200, { ok: true, message: `deploy queued for ${target}` });
  } catch (err) {
    return json(500, { ok: false, error: err.message });
  }
};
