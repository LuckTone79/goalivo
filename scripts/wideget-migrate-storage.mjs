#!/usr/bin/env node
/**
 * wideget-migrate-storage.mjs
 * ---------------------------------------------------------------------------
 * NON-DESTRUCTIVE Supabase Storage copy: source project -> wideget-core.
 * Downloads every object from a source bucket and re-uploads to the target
 * bucket in wideget-core. Never deletes anything in the source.
 *
 * Reads keys from ENV only (never hardcode service_role keys):
 *   SRC_SUPABASE_URL, SRC_SERVICE_ROLE_KEY         (source project)
 *   DST_SUPABASE_URL, DST_SERVICE_ROLE_KEY         (wideget-core)
 *
 * Usage:
 *   node scripts/wideget-migrate-storage.mjs <srcBucket> <dstBucket> [--public] [--dry-run] [--prefix path/]
 *
 * Examples (per STORAGE_MIGRATION_PLAN.md):
 *   node scripts/wideget-migrate-storage.mjs kadit-images       kadit-images
 *   node scripts/wideget-migrate-storage.mjs payment-proof      castfolio-payment-proof
 *   node scripts/wideget-migrate-storage.mjs scenario-exports   locawing-scenario-exports
 *   node scripts/wideget-migrate-storage.mjs test-reports       locawing-test-reports
 *
 * Requires: @supabase/supabase-js (already a dependency of this repo).
 * Run against wideget-core only after the target bucket policy is decided.
 */
import { createClient } from '@supabase/supabase-js';

const [srcBucket, dstBucket, ...rest] = process.argv.slice(2);
const flags = new Set(rest.filter(a => a.startsWith('--')));
const prefixArg = rest.find(a => a.startsWith('--prefix'));
const prefix = prefixArg ? (prefixArg.split('=')[1] ?? '') : '';
const dryRun = flags.has('--dry-run');
const makePublic = flags.has('--public');

function reqEnv(name) {
  const v = process.env[name];
  if (!v) { console.error(`Missing env: ${name}`); process.exit(1); }
  return v;
}
if (!srcBucket || !dstBucket) {
  console.error('Usage: node scripts/wideget-migrate-storage.mjs <srcBucket> <dstBucket> [--public] [--dry-run] [--prefix=path/]');
  process.exit(1);
}

const src = createClient(reqEnv('SRC_SUPABASE_URL'), reqEnv('SRC_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });
const dst = createClient(reqEnv('DST_SUPABASE_URL'), reqEnv('DST_SERVICE_ROLE_KEY'), { auth: { persistSession: false } });

async function listAll(client, bucket, dir = '') {
  const out = [];
  const stack = [dir];
  while (stack.length) {
    const cur = stack.pop();
    let offset = 0;
    for (;;) {
      const { data, error } = await client.storage.from(bucket).list(cur, { limit: 100, offset });
      if (error) throw new Error(`list ${bucket}/${cur}: ${error.message}`);
      if (!data || data.length === 0) break;
      for (const item of data) {
        const full = cur ? `${cur}/${item.name}` : item.name;
        if (item.id === null || item.metadata === null) stack.push(full); // folder
        else out.push(full);
      }
      if (data.length < 100) break;
      offset += 100;
    }
  }
  return out;
}

async function ensureBucket() {
  const { data } = await dst.storage.getBucket(dstBucket);
  if (data) return;
  if (dryRun) { console.log(`[dry-run] would create bucket ${dstBucket} (public=${makePublic})`); return; }
  const { error } = await dst.storage.createBucket(dstBucket, { public: makePublic });
  if (error && !/already exists/i.test(error.message)) throw new Error(`createBucket: ${error.message}`);
  console.log(`created bucket ${dstBucket} (public=${makePublic})`);
}

async function main() {
  console.log(`Copy storage: ${srcBucket} -> ${dstBucket}  (prefix='${prefix}', dryRun=${dryRun})`);
  await ensureBucket();
  const paths = await listAll(src, srcBucket, prefix);
  console.log(`objects found: ${paths.length}`);
  let ok = 0, fail = 0;
  for (const path of paths) {
    if (dryRun) { console.log(`[dry-run] ${path}`); ok++; continue; }
    const dl = await src.storage.from(srcBucket).download(path);
    if (dl.error) { console.error(`DL fail ${path}: ${dl.error.message}`); fail++; continue; }
    const buf = Buffer.from(await dl.data.arrayBuffer());
    const up = await dst.storage.from(dstBucket).upload(path, buf, {
      contentType: dl.data.type || 'application/octet-stream',
      upsert: true
    });
    if (up.error) { console.error(`UP fail ${path}: ${up.error.message}`); fail++; continue; }
    ok++;
    if (ok % 25 === 0) console.log(`  ...${ok} copied`);
  }
  console.log(`Done. copied=${ok} failed=${fail}. Source left untouched.`);
  if (fail) process.exit(2);
}

main().catch(e => { console.error(e); process.exit(1); });
