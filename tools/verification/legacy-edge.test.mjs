import { test } from 'node:test';
import assert from 'node:assert/strict';
import { legacyRetiredResponse } from '../../supabase/functions/_shared/legacy-retired.mjs';

test('retired payment and content endpoints never simulate success or read the request body', async () => {
  for (const method of ['GET','POST','PUT','PATCH','DELETE']) {
    const response=legacyRetiredResponse({method, get body(){throw new Error('must not read credentials or payment input');}});
    assert.equal(response.status,410);
    assert.equal(response.headers.get('cache-control'),'no-store');
    assert.equal((await response.json()).error,'legacy_endpoint_retired');
  }
});
test('retired endpoint preflight permits clients to read the retirement response', () => {
  const response=legacyRetiredResponse({method:'OPTIONS'});
  assert.equal(response.status,204);
  assert.match(response.headers.get('Access-Control-Allow-Headers'),/authorization/);
});
