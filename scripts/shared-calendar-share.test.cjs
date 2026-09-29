'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');

global.window = { addEventListener: function () {} };
global.document = {
  createElement: function () { return { textContent: '', innerHTML: '' }; },
  head: { appendChild: function () {} },
  readyState: 'loading'
};
const { shareEvents } = require('../shared-calendar.js');

const userId = 'owner-1';
const target = { target_type: 'group', target_id: 'group-1' };
const event = {
  source_kind: 'goalivo', source_ref: 'local:block-1', title: 'Updated title',
  start_at: '2026-10-01T10:00:00.000Z', end_at: '2026-10-01T11:00:00.000Z',
  start_date: null, end_date: null, is_all_day: false,
  timezone: 'Asia/Seoul', memo: 'Updated memo'
};

function mockClient(options) {
  options = options || {};
  const calls = { inserts: [], updates: [], shareInserts: [], shareUpdates: [], feedReads: [], returning: [] };
  const client = {
    from: function (table) {
      if (table === 'shared_events') {
        return {
          upsert: function () { assert.fail('shared_events upsert must not be used'); },
          insert: function (payload) {
            calls.inserts.push(payload);
            return {
              select: function (columns) {
                calls.returning.push(columns);
                return {
                  single: async function () {
                    return options.insertResult || { data: { id: 'inserted-event' }, error: null };
                  }
                };
              }
            };
          },
          update: function (payload) {
            const filters = {};
            calls.updates.push({ payload: payload, filters: filters });
            const query = {
              eq: function (key, value) { filters[key] = value; return query; },
              select: function (columns) {
                calls.returning.push(columns);
                return {
                  single: async function () {
                    return options.updateResult || { data: { id: filters.id }, error: null };
                  }
                };
              }
            };
            return query;
          }
        };
      }
      if (table === 'event_shares') {
        return {
          select: function () {
            const filters = {};
            const query = {
              eq: function (key, value) { filters[key] = value; return query; },
              maybeSingle: async function () {
                calls.shareFilters = filters;
                return { data: options.currentShare || null, error: null };
              }
            };
            return query;
          },
          update: function (payload) {
            const filters = {};
            const query = {
              eq: function (key, value) { filters[key] = value; return query; },
              then: function (resolve, reject) {
                calls.shareUpdates.push({ payload: payload, filters: filters });
                return Promise.resolve({ error: null }).then(resolve, reject);
              }
            };
            return query;
          },
          insert: async function (payload) {
            calls.shareInserts.push(payload);
            return { error: null };
          }
        };
      }
      assert.fail('Unexpected table: ' + table);
    },
    rpc: async function (name) {
      calls.feedReads.push(name);
      return options.feedResult || { data: options.feedRows || [], error: null };
    }
  };
  return { client: client, calls: calls };
}

function context(client, sharedEvents) {
  return { local: false, client: client, user: { id: userId }, sharedEvents: sharedEvents || [] };
}

function ownerRow(id) {
  return {
    id: id, owner_user_id: userId, source_kind: event.source_kind,
    source_ref: event.source_ref, title: 'Old title', memo: 'Old memo'
  };
}

test('re-sharing updates the existing owner event and active share without upsert', async function () {
  const row = ownerRow('existing-event');
  const mock = mockClient({ currentShare: { id: 'existing-share' } });

  await shareEvents([event], [target], 'selected_details', context(mock.client, [row]));

  assert.equal(mock.calls.inserts.length, 0);
  assert.equal(mock.calls.updates.length, 1);
  assert.equal(mock.calls.updates[0].filters.id, row.id);
  assert.equal(mock.calls.updates[0].filters.owner_user_id, userId);
  assert.deepEqual(mock.calls.updates[0].payload, {
    title: event.title, start_at: event.start_at, end_at: event.end_at,
    start_date: null, end_date: null, is_all_day: false,
    timezone: event.timezone, memo: event.memo, status: 'active'
  });
  assert.deepEqual(mock.calls.returning, ['id']);
  assert.equal(mock.calls.shareUpdates.length, 1);
  assert.equal(mock.calls.shareUpdates[0].filters.id, 'existing-share');
  assert.equal(mock.calls.shareInserts.length, 0);
  assert.deepEqual(mock.calls.feedReads, []);
});

test('a new shared event inserts and then creates its target share', async function () {
  const mock = mockClient();

  await shareEvents([event], [target], 'title_time', context(mock.client));

  assert.equal(mock.calls.inserts.length, 1);
  assert.deepEqual(mock.calls.inserts[0], {
    owner_user_id: userId, source_kind: event.source_kind, source_ref: event.source_ref,
    title: event.title, start_at: event.start_at, end_at: event.end_at,
    start_date: null, end_date: null, is_all_day: false,
    timezone: event.timezone, memo: event.memo, status: 'active'
  });
  assert.deepEqual(mock.calls.returning, ['id']);
  assert.equal(mock.calls.updates.length, 0);
  assert.equal(mock.calls.shareInserts.length, 1);
  assert.equal(mock.calls.shareInserts[0].event_id, 'inserted-event');
  assert.equal(mock.calls.shareInserts[0].target_group_id, target.target_id);
  assert.deepEqual(mock.calls.feedReads, []);
});

test('a concurrent duplicate insert reloads the feed and updates the owner row', async function () {
  const raced = ownerRow('raced-event');
  const mock = mockClient({
    insertResult: { data: null, error: { code: '23505', message: 'duplicate key' } },
    feedRows: [raced]
  });

  await shareEvents([event], [target], 'time_only', context(mock.client));

  assert.equal(mock.calls.inserts.length, 1);
  assert.deepEqual(mock.calls.feedReads, ['get_shared_event_feed']);
  assert.equal(mock.calls.updates.length, 1);
  assert.equal(mock.calls.updates[0].filters.id, raced.id);
  assert.equal(mock.calls.updates[0].filters.owner_user_id, userId);
  assert.deepEqual(mock.calls.returning, ['id', 'id']);
  assert.equal(mock.calls.shareInserts[0].event_id, raced.id);
});

test('an unresolved concurrent duplicate returns a clear retry error', async function () {
  const mock = mockClient({
    insertResult: { data: null, error: { code: '23505', message: 'duplicate key' } },
    feedRows: []
  });

  await assert.rejects(
    shareEvents([event], [target], 'title_time', context(mock.client)),
    function (error) {
      assert.equal(error.code, 'SHARED_EVENT_CONCURRENT_DUPLICATE');
      assert.match(error.message, /동시에 공유되었습니다/);
      return true;
    }
  );
  assert.equal(mock.calls.updates.length, 0);
  assert.equal(mock.calls.shareInserts.length, 0);
});
