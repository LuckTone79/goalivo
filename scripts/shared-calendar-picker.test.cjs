'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function loadHelpers(state) {
  const source = fs.readFileSync(path.join(__dirname, '..', 'shared-calendar.js'), 'utf8');
  const document = {
    createElement() {
      let value = '';
      return {
        set textContent(input) { value = String(input).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); },
        get innerHTML() { return value; }
      };
    },
    head: { appendChild() {} },
    readyState: 'loading'
  };
  const goalivo = { state: state || {} };
  const window = { Goalivo: goalivo, addEventListener() {}, alert() {} };
  const context = { window, document, Goalivo: goalivo, module: { exports: {} }, Intl, Date, Math, Array, Object, String, Number, JSON, console, setTimeout() {}, clearTimeout() {} };
  vm.runInNewContext(source, context, { filename: 'shared-calendar.js' });
  return context.module.exports;
}

test('includes scheduled tasks and linked todos once while retaining linked block time', () => {
  const helpers = loadHelpers({
    timeBlocks: [
      { id: 'block-1', title: '준비 일정', date: '2026-10-01', startTime: '09:30', endTime: '10:15' },
      { id: 'todo-block', title: '독립 할 일', date: '2026-10-02', startTime: '13:00', isTodo: true }
    ],
    taskInstances: [
      { id: 'linked-task', title: '준비 일정 할 일', date: '2026-10-01', linkedBlockId: 'block-1' },
      { id: 'dated-task', title: '별도 할 일', date: '2026-10-03' }
    ],
    externalEvents: [
      { eventId: 'google-1', calendarId: 'primary', summary: 'Google 일정', start: '2026-10-04T09:00:00+09:00', end: '2026-10-04T10:00:00+09:00' },
      { eventId: 'google-all-day', calendarId: 'primary', summary: 'Google 종일 일정', start: '2026-10-05', end: '2026-10-06', isAllDay: true }
    ]
  });
  const events = helpers.sourceEvents();
  assert.equal(events.length, 5);
  assert.equal(events.filter((event) => event.source_ref === 'local:block-1').length, 1);
  const linked = events.find((event) => event.source_ref === 'local:block-1');
  assert.equal(new Date(linked.start_at).getHours(), 9);
  assert.equal(new Date(linked.start_at).getMinutes(), 30);
  assert.ok(events.some((event) => event.source_ref === 'local:todo-block'));
  const datedTask = events.find((event) => event.source_ref === 'task:dated-task');
  assert.ok(datedTask);
  assert.equal(datedTask.is_all_day, true);
  assert.ok(events.some((event) => event.source_ref.indexOf('google:primary:google-1:') === 0));
  assert.ok(events.some((event) => event.source_ref.indexOf('google:primary:google-all-day:') === 0));
});

test('does not expose malformed entries that cannot be saved as shared events', () => {
  const helpers = loadHelpers({
    timeBlocks: [
      { id: 'bad-day', title: '잘못된 날짜', date: '2026-02-30' },
      { id: 'bad-time', title: '잘못된 시간', date: '2026-10-01', startTime: '12:00', endTime: '11:00' }
    ],
    taskInstances: [
      { id: 'bad-task', title: '잘못된 할 일', date: '2026-02-30' },
      { id: 'timed-task-without-end', title: '종료 없는 일정', date: '2026-10-01', startTime: '12:00' }
    ]
  });
  assert.equal(helpers.sourceEvents().length, 0);
});

test('picker renders more than one hundred entries', () => {
  const timeBlocks = Array.from({ length: 125 }, (_, index) => ({
    id: 'block-' + index,
    title: '일정 ' + index,
    date: '2026-10-' + String((index % 28) + 1).padStart(2, '0'),
    startTime: '09:00'
  }));
  const helpers = loadHelpers({ timeBlocks });
  const html = helpers.modalHtml(null, null);
  assert.equal((html.match(/data-event-ref=/g) || []).length, 125);
});

test('sorts events by local calendar date and time', () => {
  const helpers = loadHelpers({});
  const events = [
    { source_ref: 'later', start_at: new Date(2026, 9, 2, 10, 0).toISOString() },
    { source_ref: 'earlier-time', start_at: new Date(2026, 9, 1, 11, 0).toISOString() },
    { source_ref: 'earlier-day', start_date: '2026-10-01', is_all_day: true }
  ];
  assert.deepEqual(helpers.sortEvents(events).map((event) => event.source_ref), ['earlier-day', 'earlier-time', 'later']);
});

test('chooses the nearest future event, or the most recent past event when none remain', () => {
  const helpers = loadHelpers({});
  const now = new Date(2026, 8, 29, 12, 0);
  const events = [
    { source_ref: 'past', start_at: new Date(2026, 8, 29, 10, 0).toISOString() },
    { source_ref: 'near-future', start_at: new Date(2026, 8, 29, 13, 0).toISOString() },
    { source_ref: 'far-future', start_at: new Date(2026, 8, 30, 9, 0).toISOString() }
  ];
  assert.equal(helpers.chooseAnchor(events, now).source_ref, 'near-future');
  assert.equal(helpers.chooseAnchor([events[0]], now).source_ref, 'past');
});
