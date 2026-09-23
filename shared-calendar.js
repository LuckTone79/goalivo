(function () {
  'use strict';
  var KEY = 'goalivo_shared_calendar_v1';
  var SC = {
    client: null, user: null, profile: null, local: true, groups: [], friends: [],
    requests: [], invitations: [], sharedEvents: [], memberships: [], tab: 'groups',
    selectedGroupId: null, initialized: false, busy: false
  };

  function esc(value) {
    var node = document.createElement('div');
    node.textContent = value == null ? '' : String(value);
    return node.innerHTML;
  }
  function uid() {
    return window.crypto && crypto.randomUUID ? crypto.randomUUID() : 'local-' + Date.now() + '-' + Math.random().toString(36).slice(2, 9);
  }
  function readLocal() {
    var data = {};
    try { data = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (_) {}
    return {
      profile: data.profile || null, friends: Array.isArray(data.friends) ? data.friends : [],
      requests: Array.isArray(data.requests) ? data.requests : [], groups: Array.isArray(data.groups) ? data.groups : [],
      invitations: Array.isArray(data.invitations) ? data.invitations : [], sharedEvents: Array.isArray(data.sharedEvents) ? data.sharedEvents : []
    };
  }
  function saveLocal(data) {
    var current = readLocal();
    localStorage.setItem(KEY, JSON.stringify(Object.assign({}, current, data)));
  }
  function toast(message, kind) {
    if (window.Goalivo && Goalivo.toast) Goalivo.toast(message, kind || 'info');
    else window.alert(message);
  }
  function makeCode() {
    var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', result = '';
    for (var i = 0; i < 8; i++) result += chars[Math.floor(Math.random() * chars.length)];
    return result;
  }
  async function client() {
    if (SC.client) return SC.client;
    try {
      var response = await fetch('/api/config');
      if (!response.ok) return null;
      var config = await response.json();
      if (!config.supabaseUrl || !config.supabaseAnonKey || !window.supabase) return null;
      SC.client = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, { db: { schema: 'goalivo' } });
      var session = await SC.client.auth.getSession();
      SC.user = session.data && session.data.session ? session.data.session.user : null;
      return SC.client;
    } catch (error) {
      console.warn('[Goalivo shared calendar] Supabase unavailable', error);
      return null;
    }
  }
  function localProfile() {
    var data = readLocal(), profile = data.profile;
    if (profile) return profile;
    var email = (SC.user && SC.user.email) || '';
    profile = { user_id: SC.user ? SC.user.id : 'local-user', nickname: (email.split('@')[0] || 'Goalivo 사용자').slice(0, 20), friend_code: makeCode(), timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Seoul' };
    if (profile.nickname.length < 2) profile.nickname = 'Goalivo 사용자';
    saveLocal({ profile: profile });
    return profile;
  }
  async function ensureProfile() {
    var db = await client();
    if (db && !SC.user) {
      var session = await db.auth.getSession();
      SC.user = session.data && session.data.session ? session.data.session.user : null;
    }
    if (!db || !SC.user) {
      SC.local = true; SC.profile = localProfile(); return SC.profile;
    }
    SC.local = false;
    var found = await db.from('profiles').select('*').eq('user_id', SC.user.id).maybeSingle();
    if (found.error) throw found.error;
    if (found.data) { SC.profile = found.data; return found.data; }
    var name = ((SC.user.email || '').split('@')[0] || 'Goalivo 사용자').slice(0, 20);
    if (name.length < 2) name = 'Goalivo 사용자';
    var created = await db.from('profiles').insert({ user_id: SC.user.id, nickname: name, friend_code: makeCode(), timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Seoul' }).select().single();
    if (created.error) throw created.error;
    SC.profile = created.data;
    return created.data;
  }
  function sourceEvents() {
    var state = window.Goalivo && Goalivo.state ? Goalivo.state : {}, blocks = Array.isArray(state.timeBlocks) ? state.timeBlocks : [], external = Array.isArray(state.externalEvents) ? state.externalEvents : [], result = [];
    blocks.forEach(function (block) {
      if (!block || !block.title || !block.date || block.isTodo) return;
      var start = block.isAllDay ? null : new Date(block.date + 'T' + (block.startTime || '00:00') + ':00').toISOString();
      var end = block.isAllDay ? null : new Date(block.date + 'T' + (block.endTime || '23:59') + ':00').toISOString();
      result.push({ source_kind: 'goalivo', source_ref: 'local:' + block.id, title: block.title, start_at: start, end_at: end, start_date: block.isAllDay ? block.date : null, end_date: block.isAllDay ? block.date : null, is_all_day: !!block.isAllDay, timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Seoul', memo: block.memo || '', source_label: '직접 작성' });
    });
    external.forEach(function (event) {
      if (!event || !event.eventId || !event.summary) return;
      var allDay = !!event.isAllDay, startDate = event.start ? new Date(event.start) : null, endDate = event.end ? new Date(event.end) : null;
      result.push({ source_kind: 'google', source_ref: 'google:' + (event.calendarId || 'primary') + ':' + event.eventId + ':' + (event.start || ''), title: event.summary, start_at: !allDay && startDate && !isNaN(startDate.getTime()) ? startDate.toISOString() : null, end_at: !allDay && endDate && !isNaN(endDate.getTime()) ? endDate.toISOString() : null, start_date: allDay ? String(event.start || '').slice(0, 10) : null, end_date: allDay ? String(event.end || event.start || '').slice(0, 10) : null, is_all_day: allDay, timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Seoul', memo: event.description || '', source_label: 'Google Calendar' });
    });
    return result;
  }
  function eventDate(event) {
    if (event.is_all_day || event.start_date) return (event.start_date || '') + ' · 종일';
    if (!event.start_at) return '시간 미정';
    var start = new Date(event.start_at), end = event.end_at ? new Date(event.end_at) : null;
    var date = start.toLocaleDateString('ko-KR', { month: 'short', day: 'numeric', weekday: 'short' });
    var time = start.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
    return date + ' ' + time + (end && !isNaN(end.getTime()) ? '–' + end.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' }) : '');
  }
  async function load() {
    await ensureProfile();
    if (SC.local) {
      var local = readLocal();
      SC.groups = local.groups; SC.friends = local.friends; SC.requests = local.requests; SC.invitations = local.invitations; SC.sharedEvents = local.sharedEvents;
      SC.memberships = SC.groups.flatMap(function (group) { return (group.members || []).filter(function (m) { return m.user_id === SC.profile.user_id; }).map(function (m) { return Object.assign({}, m, { group: group }); }); });
      return;
    }
    var db = SC.client, id = SC.user.id;
    var results = await Promise.all([
      db.from('groups').select('*').order('created_at', { ascending: false }),
      db.from('group_members').select('*, groups(*)').eq('user_id', id).eq('status', 'active'),
      db.from('friendships').select('user_b').eq('user_a', id),
      db.from('friendships').select('user_a').eq('user_b', id),
      db.from('friend_requests').select('*').or('sender_id.eq.' + id + ',receiver_id.eq.' + id).order('created_at', { ascending: false }),
      db.from('group_invitations').select('*, groups(*)').eq('invitee_id', id).eq('status', 'pending').order('created_at', { ascending: false }),
      db.rpc('get_shared_event_feed')
    ]);
    var failure = results.find(function (item) { return item.error; });
    if (failure) throw failure.error;
    SC.groups = results[0].data || [];
    var groupIds = SC.groups.map(function (group) { return group.id; });
    var allMemberships = groupIds.length ? await db.from('group_members').select('*').in('group_id', groupIds).eq('status', 'active') : { data: [], error: null };
    if (allMemberships.error) throw allMemberships.error;
    var memberIds = Array.from(new Set((allMemberships.data || []).map(function (member) { return member.user_id; })));
    var memberProfiles = memberIds.length ? await db.from('profiles').select('user_id,nickname,friend_code').in('user_id', memberIds) : { data: [], error: null };
    if (memberProfiles.error) throw memberProfiles.error;
    var profileById = (memberProfiles.data || []).reduce(function (map, profile) { map[profile.user_id] = profile; return map; }, {});
    SC.memberships = (allMemberships.data || []).map(function (member) { return Object.assign({}, member, profileById[member.user_id] || {}); });
    var friendIds = (results[2].data || []).map(function (r) { return r.user_b; }).concat((results[3].data || []).map(function (r) { return r.user_a; }));
    var friendProfiles = friendIds.length ? await db.from('profiles').select('user_id,nickname,friend_code').in('user_id', friendIds) : { data: [], error: null };
    if (friendProfiles.error) throw friendProfiles.error;
    SC.friends = friendProfiles.data || [];
    SC.requests = results[4].data || []; SC.invitations = results[5].data || [];
    SC.sharedEvents = (results[6].data || []).sort(function (a, b) {
      return String(a.start_at || a.start_date || '').localeCompare(String(b.start_at || b.start_date || ''));
    });
  }
  async function task(action, message) {
    SC.busy = true;
    try { await action(); await load(); render(); if (message) toast(message, 'success'); }
    catch (error) { console.error('[Goalivo shared calendar]', error); toast(error.message || '공유 캘린더 작업에 실패했습니다', 'error'); }
    finally { SC.busy = false; }
  }
  async function saveProfile() {
    var input = document.getElementById('sharedNicknameInput'), nickname = String(input && input.value || '').trim();
    if (nickname.length < 2 || nickname.length > 20) return toast('닉네임은 2~20자로 입력하세요', 'error');
    if (SC.local) { SC.profile.nickname = nickname; saveLocal({ profile: SC.profile }); toast('닉네임이 저장되었습니다', 'success'); render(); return; }
    await task(async function () { var result = await SC.client.from('profiles').update({ nickname: nickname }).eq('user_id', SC.user.id); if (result.error) throw result.error; }, '닉네임이 저장되었습니다');
  }
  async function sendFriendRequest() {
    var input = document.getElementById('sharedFriendCodeInput'), code = String(input && input.value || '').trim().toUpperCase();
    if (!/^[A-Z0-9]{8}$/.test(code)) return toast('8자리 친구 코드를 입력하세요', 'error');
    if (SC.local) { var local = readLocal(); local.requests.unshift({ id: uid(), status: 'pending', direction: 'outgoing', friend_code: code }); saveLocal({ requests: local.requests }); toast('요청 초안을 저장했습니다. 로그인하면 실제 사용자에게 전송됩니다.', 'info'); await load(); render(); return; }
    await task(async function () {
      var found = await SC.client.rpc('find_profile_by_friend_code', { p_friend_code: code });
      if (found.error) throw found.error;
      var profile = found.data && found.data[0];
      if (!profile) throw new Error('해당 친구 코드를 찾지 못했습니다');
      var result = await SC.client.from('friend_requests').insert({ sender_id: SC.user.id, receiver_id: profile.user_id });
      if (result.error) throw result.error;
    }, '친구 요청을 보냈습니다');
  }
  async function respondFriendRequest(requestId, status) {
    if (SC.local) { var local = readLocal(); local.requests = local.requests.map(function (r) { return r.id === requestId ? Object.assign({}, r, { status: status }) : r; }); saveLocal({ requests: local.requests }); await load(); render(); return; }
    await task(async function () {
      var request = SC.requests.find(function (r) { return r.id === requestId; });
      var changed = await SC.client.from('friend_requests').update({ status: status }).eq('id', requestId);
      if (changed.error) throw changed.error;
      if (status === 'accepted' && request) {
        var pair = [request.sender_id, request.receiver_id].sort(), inserted = await SC.client.from('friendships').insert({ user_a: pair[0], user_b: pair[1] });
        if (inserted.error && inserted.error.code !== '23505') throw inserted.error;
      }
    }, status === 'accepted' ? '친구가 연결되었습니다' : '요청을 거절했습니다');
  }
  async function createGroup() {
    var nameInput = document.getElementById('sharedGroupNameInput'), name = String(nameInput && nameInput.value || '').trim(), description = String(document.getElementById('sharedGroupDescriptionInput') && document.getElementById('sharedGroupDescriptionInput').value || '').trim();
    if (!name || name.length > 60) return toast('그룹 이름을 1~60자로 입력하세요', 'error');
    if (SC.local) {
      var local = readLocal(), group = { id: uid(), owner_user_id: SC.profile.user_id, name: name, description: description, color: '#6c8cff', members: [{ user_id: SC.profile.user_id, role: 'owner', status: 'active' }] };
      local.groups.unshift(group); saveLocal({ groups: local.groups }); SC.selectedGroupId = group.id; await load(); render(); toast('그룹을 만들었습니다', 'success'); return;
    }
    await task(async function () {
      var inserted = await SC.client.from('groups').insert({ owner_user_id: SC.user.id, name: name, description: description }).select().single();
      if (inserted.error) throw inserted.error;
      var member = await SC.client.from('group_members').insert({ group_id: inserted.data.id, user_id: SC.user.id, role: 'owner', status: 'active', joined_at: new Date().toISOString() });
      if (member.error) throw member.error;
      SC.selectedGroupId = inserted.data.id;
    }, '그룹을 만들었습니다');
  }
  async function inviteToGroup(groupId) {
    var input = document.getElementById('sharedInviteCode-' + groupId), code = String(input && input.value || '').trim().toUpperCase();
    if (!code) return toast('친구 코드를 입력하세요', 'error');
    if (SC.local) { toast('로그인하면 친구 코드로 실제 초대를 보낼 수 있습니다.', 'info'); return; }
    await task(async function () {
      var found = await SC.client.rpc('find_profile_by_friend_code', { p_friend_code: code });
      if (found.error) throw found.error;
      var profile = found.data && found.data[0];
      if (!profile) throw new Error('친구 코드를 찾지 못했습니다');
      var result = await SC.client.from('group_invitations').insert({ group_id: groupId, inviter_id: SC.user.id, invitee_id: profile.user_id });
      if (result.error) throw result.error;
    }, '그룹 초대를 보냈습니다');
  }
  async function updateMemberRole(groupId, userId, role) {
    if (['admin', 'member'].indexOf(role) < 0) return toast('지원하지 않는 역할입니다', 'error');
    if (SC.local) {
      var local = readLocal();
      local.groups = local.groups.map(function (group) {
        if (group.id !== groupId) return group;
        group.members = (group.members || []).map(function (member) { return member.user_id === userId ? Object.assign({}, member, { role: role }) : member; });
        return group;
      });
      saveLocal({ groups: local.groups }); await load(); render(); return;
    }
    await task(async function () {
      var changed = await SC.client.from('group_members').update({ role: role }).eq('group_id', groupId).eq('user_id', userId);
      if (changed.error) throw changed.error;
    }, role === 'admin' ? '관리자로 지정했습니다' : '멤버 권한으로 변경했습니다');
  }
  async function removeMember(groupId, userId) {
    if (SC.local) {
      var local = readLocal();
      local.groups = local.groups.map(function (group) { if (group.id === groupId) group.members = (group.members || []).filter(function (member) { return member.user_id !== userId; }); return group; });
      saveLocal({ groups: local.groups }); await load(); render(); return;
    }
    await task(async function () {
      var removed = await SC.client.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
      if (removed.error) throw removed.error;
    }, '그룹에서 멤버를 제거했습니다');
  }
  async function respondGroupInvite(invitationId, status) {
    if (SC.local) { var local = readLocal(); local.invitations = local.invitations.filter(function (i) { return i.id !== invitationId; }); saveLocal({ invitations: local.invitations }); await load(); render(); return; }
    await task(async function () {
      var invitation = SC.invitations.find(function (i) { return i.id === invitationId; });
      var changed = await SC.client.from('group_invitations').update({ status: status }).eq('id', invitationId);
      if (changed.error) throw changed.error;
      if (status === 'accepted' && invitation) {
        var member = await SC.client.from('group_members').insert({ group_id: invitation.group_id, user_id: SC.user.id, role: 'member', status: 'active', joined_at: new Date().toISOString() });
        if (member.error) throw member.error;
      }
    }, status === 'accepted' ? '그룹에 가입했습니다' : '초대를 거절했습니다');
  }
  function targetList() {
    return SC.groups.map(function (g) { return { type: 'group', id: g.id, label: '그룹 · ' + g.name }; }).concat(SC.friends.map(function (f) { return { type: 'user', id: f.user_id, label: '사람 · ' + f.nickname }; }));
  }
  function findEvent(id) {
    if (!id) return null;
    if (id.indexOf('local:') === 0 || id.indexOf('google:') === 0) return sourceEvents().find(function (e) { return e.source_ref === id; }) || null;
    return SC.sharedEvents.find(function (e) { return e.id === id; }) || null;
  }
  function shareFor(event, targetType, targetId) {
    return (event.event_shares || []).find(function (share) {
      return share.status === 'active' && share.target_type === targetType && (targetType === 'group' ? share.target_group_id === targetId : share.target_user_id === targetId);
    }) || null;
  }
  function sharedTitle(event, share) {
    return share && share.access_level === 'time_only' ? '공유된 일정' : event.title;
  }
  function sharedMemo(event, share) {
    return share && share.access_level === 'selected_details' ? (event.memo || '') : '';
  }
  function eventRow(event, selected) {
    return '<label class="shared-event-row ' + (selected ? 'selected' : '') + '"><input type="checkbox" data-event-ref="' + esc(event.source_ref) + '"' + (selected ? ' checked' : '') + '><span class="shared-event-dot"></span><span class="shared-event-main"><strong>' + esc(event.title) + '</strong><small>' + esc(eventDate(event)) + ' · ' + esc(event.source_label || '') + '</small></span></label>';
  }
  function modalHtml(event, presetGroup) {
    var events = event ? [event] : sourceEvents().slice(0, 100), targets = targetList(), html = '<div class="shared-modal-overlay" id="sharedShareModal"><div class="shared-modal"><div class="shared-card-heading"><div><h2>' + (event ? '이 일정을 공유' : '그룹에 일정 추가') + '</h2><p>' + (event ? esc(event.title + ' · ' + eventDate(event)) : '일정을 탭해서 한 번에 공유하세요') + '</p></div><button class="shared-icon-btn" onclick="SharedCalendar.closeModal()">×</button></div>';
    if (!targets.length) html += '<div class="shared-empty">먼저 친구를 연결하거나 그룹을 만들어 주세요.</div>';
    else html += '<div class="shared-share-targets">' + targets.map(function (target) { return '<label class="shared-target-row"><input type="checkbox" data-target-type="' + target.type + '" data-target-id="' + esc(target.id) + '"' + (presetGroup === target.id ? ' checked' : '') + '><span>' + esc(target.label) + '</span></label>'; }).join('') + '</div>';
    if (!event) html += '<div class="shared-selection-tip">탭한 일정만 선택됩니다. 이미 공유한 원본은 공유 관리에서 수정하세요.</div><div class="shared-event-picker">' + events.map(function (item) { return eventRow(item, false); }).join('') + '</div>';
    html += '<div class="shared-access-box"><label>공개 수준</label><select id="sharedAccessSelect" class="shared-input"><option value="title_time">제목·시간 공개</option><option value="time_only">시간만 공개</option><option value="selected_details">선택한 상세정보</option></select><small>장소·메모·링크는 자동 공개하지 않습니다.</small></div><div class="shared-modal-actions"><button class="shared-secondary" onclick="SharedCalendar.closeModal()">취소</button><button class="shared-primary" onclick="SharedCalendar.confirmShare(' + (event ? "'" + esc(event.source_ref || event.id) + "'" : "''") + ')">공유하기</button></div></div></div>';
    return html;
  }
  function openShareComposer(eventId, groupId) {
    var event = eventId ? findEvent(eventId) : null;
    document.body.insertAdjacentHTML('beforeend', modalHtml(event, groupId));
  }
  function closeModal() { var modal = document.getElementById('sharedShareModal'); if (modal) modal.remove(); }
  async function confirmShare(ref) {
    var modal = document.getElementById('sharedShareModal'), checkedTargets = modal ? Array.from(modal.querySelectorAll('input[data-target-type]:checked')) : [];
    if (!checkedTargets.length) return toast('공유할 사람이나 그룹을 선택하세요', 'error');
    var targets = checkedTargets.map(function (input) { return { target_type: input.dataset.targetType, target_id: input.dataset.targetId }; }), access = document.getElementById('sharedAccessSelect').value, events = [];
    if (ref) events = [findEvent(ref)].filter(Boolean);
    else events = Array.from(modal.querySelectorAll('input[data-event-ref]:checked')).map(function (input) { return findEvent(input.dataset.eventRef); }).filter(Boolean);
    if (!events.length) return toast('공유할 일정을 선택하세요', 'error');
    closeModal();
    await task(function () { return shareEvents(events, targets, access); }, events.length + '개 일정의 공유를 저장했습니다');
  }
  async function shareEvents(events, targets, access) {
    if (SC.local) {
      var local = readLocal();
      events.forEach(function (event) {
        var saved = local.sharedEvents.find(function (item) { return item.source_kind === event.source_kind && item.source_ref === event.source_ref; });
        if (!saved) { saved = Object.assign({ id: uid(), owner_user_id: SC.profile.user_id, event_shares: [] }, event); local.sharedEvents.push(saved); }
        targets.forEach(function (target) {
          var exists = (saved.event_shares || []).some(function (s) { return s.target_type === target.target_type && s.target_id === target.target_id; });
          if (!exists) (saved.event_shares || (saved.event_shares = [])).push({ target_type: target.target_type, target_id: target.target_id, access_level: access, status: 'active' });
        });
      });
      saveLocal({ sharedEvents: local.sharedEvents }); return;
    }
    for (var i = 0; i < events.length; i++) {
      var event = events[i], upsert = await SC.client.from('shared_events').upsert({ owner_user_id: SC.user.id, source_kind: event.source_kind, source_ref: event.source_ref, title: event.title, start_at: event.start_at, end_at: event.end_at, start_date: event.start_date, end_date: event.end_date, is_all_day: event.is_all_day, timezone: event.timezone, memo: event.memo || '', status: 'active' }, { onConflict: 'owner_user_id,source_kind,source_ref' }).select('id,owner_user_id,source_kind,source_ref,start_at,end_at,start_date,end_date,is_all_day,timezone,status,version,created_at,updated_at').single();
      if (upsert.error) throw upsert.error;
      for (var j = 0; j < targets.length; j++) {
        var target = targets[j], query = SC.client.from('event_shares').select('id').eq('event_id', upsert.data.id).eq('status', 'active');
        query = target.target_type === 'group' ? query.eq('target_group_id', target.target_id) : query.eq('target_user_id', target.target_id);
        var current = await query.maybeSingle();
        if (current.error) throw current.error;
        if (current.data) {
          var updated = await SC.client.from('event_shares').update({ access_level: access, status: 'active', suspended_reason: null, revoked_at: null }).eq('id', current.data.id);
          if (updated.error) throw updated.error;
        } else {
          var inserted = await SC.client.from('event_shares').insert({ event_id: upsert.data.id, target_type: target.target_type, target_user_id: target.target_type === 'user' ? target.target_id : null, target_group_id: target.target_type === 'group' ? target.target_id : null, access_level: access, created_by: SC.user.id });
          if (inserted.error) throw inserted.error;
        }
      }
    }
  }
  function groupDetail(group) {
    var members = group.members || SC.memberships.filter(function (m) { return m.group_id === group.id; }), shared = SC.sharedEvents.filter(function (event) { return (event.event_shares || []).some(function (share) { return share.target_group_id === group.id && share.status === 'active'; }); });
    var canManage = SC.local ? group.owner_user_id === SC.profile.user_id : SC.memberships.some(function (m) { return m.group_id === group.id && ['owner', 'admin'].indexOf(m.role) >= 0; });
    var memberRows = members.length ? members.map(function (member) {
      var controls = canManage && member.user_id !== group.owner_user_id ? '<button class="shared-secondary" onclick="SharedCalendar.updateMemberRole(\'' + esc(group.id) + '\',\'' + esc(member.user_id) + '\',\'' + (member.role === 'admin' ? 'member' : 'admin') + '\')">' + (member.role === 'admin' ? '관리자 해제' : '관리자 지정') + '</button><button class="shared-danger" onclick="SharedCalendar.removeMember(\'' + esc(group.id) + '\',\'' + esc(member.user_id) + '\')">제거</button>' : '';
      return '<div class="shared-list-row"><span class="shared-avatar">🙂</span><span><strong>' + esc(member.nickname || member.user_id || '멤버') + '</strong><small>' + esc(member.role || 'member') + '</small></span>' + controls + '</div>';
    }).join('') : '<div class="shared-empty">로그인 후 멤버 정보를 표시합니다.</div>';
    return '<section class="shared-card"><div class="shared-card-heading"><div><button class="shared-link" onclick="SharedCalendar.showGroups()">← 그룹 목록</button><h2>' + esc(group.name) + '</h2><p>' + esc(group.description || '구성원과 필요한 일정만 공유하세요.') + '</p></div><span class="shared-role">' + (canManage ? '관리 권한' : '멤버') + '</span></div><div class="shared-action-grid"><button class="shared-primary" onclick="SharedCalendar.openBulkShare(' + "'" + esc(group.id) + "'" + ')">이 그룹에 일정 추가</button><button class="shared-secondary" onclick="SharedCalendar.openShareComposer(null,' + "'" + esc(group.id) + "'" + ')">내 일정 추가</button></div><div class="shared-subsection"><h3>그룹에 공유된 일정 <span>' + shared.length + '</span></h3>' + (shared.length ? shared.slice(0, 20).map(function (event) { var share = shareFor(event, 'group', group.id); return '<div class="shared-list-row"><span>📅</span><span><strong>' + esc(sharedTitle(event, share)) + '</strong><small>' + esc(eventDate(event)) + (sharedMemo(event, share) ? ' · ' + esc(sharedMemo(event, share)) : '') + '</small></span></div>'; }).join('') : '<div class="shared-empty">아직 공유된 일정이 없습니다.</div>') + '</div><div class="shared-subsection"><h3>친구 초대</h3><div class="shared-inline-form"><input class="shared-input" id="sharedInviteCode-' + esc(group.id) + '" maxlength="8" placeholder="친구 코드 8자리"><button class="shared-secondary" onclick="SharedCalendar.inviteToGroup(' + "'" + esc(group.id) + "'" + ')">초대</button></div><small class="shared-help">지정한 친구에게만 초대가 전달됩니다.</small></div><div class="shared-subsection"><h3>멤버</h3><div class="shared-member-list">' + memberRows + '</div></div></section>';
  }
  function renderGroups() {
    var selected = SC.groups.find(function (group) { return group.id === SC.selectedGroupId; });
    if (selected) return groupDetail(selected);
    return '<section class="shared-card"><div class="shared-card-heading"><div><h2>그룹 캘린더</h2><p>가족·친구·모임별로 필요한 일정만 공유하세요.</p></div><span class="shared-count">' + SC.groups.length + '개</span></div><div class="shared-create-box"><h3>새 그룹 만들기</h3><div class="shared-inline-form"><input class="shared-input" id="sharedGroupNameInput" maxlength="60" placeholder="예: 우리 가족"><button class="shared-primary" onclick="SharedCalendar.createGroup()">그룹 만들기</button></div><input class="shared-input" id="sharedGroupDescriptionInput" maxlength="500" placeholder="그룹 설명 (선택)"></div><div class="shared-group-grid">' + (SC.groups.length ? SC.groups.map(function (group) { return '<button class="shared-group-card" onclick="SharedCalendar.selectGroup(' + "'" + esc(group.id) + "'" + ')"><span class="shared-group-icon" style="background:' + esc(group.color || '#6c8cff') + '">👥</span><span><strong>' + esc(group.name) + '</strong><small>' + esc(group.description || '공유 일정 공간') + '</small></span><span class="shared-group-arrow">›</span></button>'; }).join('') : '<div class="shared-empty">첫 그룹을 만들어 일정을 공유해 보세요.</div>') + '</div></section>';
  }
  function renderPeople() {
    var me = SC.profile && SC.profile.user_id;
    var incoming = SC.requests.filter(function (r) { return r.receiver_id === me && r.status === 'pending'; });
    var outgoing = SC.requests.filter(function (r) { return r.sender_id === me && r.status === 'pending'; });
    var friendRows = SC.friends.length ? SC.friends.map(function (f) {
      return '<div class="shared-list-row"><span class="shared-avatar">🙂</span><span><strong>' + esc(f.nickname) + '</strong><small>' + esc(f.friend_code || '') + '</small></span></div>';
    }).join('') : '<div class="shared-empty">아직 친구가 없습니다.</div>';
    var requestRows = incoming.length ? incoming.map(function (r) {
      var id = esc(r.id);
      return '<div class="shared-list-row"><span>✉️</span><span><small>친구 요청</small></span><button class="shared-secondary" onclick="SharedCalendar.respondFriendRequest(\'' + id + '\',\'accepted\')">수락</button><button class="shared-danger" onclick="SharedCalendar.respondFriendRequest(\'' + id + '\',\'declined\')">거절</button></div>';
    }).join('') : '<div class="shared-empty">새로운 요청이 없습니다.</div>';
    var inviteRows = SC.invitations.length ? SC.invitations.map(function (i) {
      var id = esc(i.id);
      return '<div class="shared-list-row"><span>👥</span><span><strong>' + esc(i.groups && i.groups.name || '그룹') + '</strong><small>초대를 받았습니다</small></span><button class="shared-secondary" onclick="SharedCalendar.respondGroupInvite(\'' + id + '\',\'accepted\')">가입</button><button class="shared-danger" onclick="SharedCalendar.respondGroupInvite(\'' + id + '\',\'declined\')">거절</button></div>';
    }).join('') : '<div class="shared-empty">새로운 그룹 초대가 없습니다.</div>';
    return '<section class="shared-card"><div class="shared-card-heading"><div><h2>사람</h2><p>친구 연결만으로 일정이 공개되지는 않습니다.</p></div><span class="shared-code">' + esc(SC.profile && SC.profile.friend_code) + '</span></div><div class="shared-profile-box"><label>내 닉네임</label><div class="shared-inline-form"><input class="shared-input" id="sharedNicknameInput" maxlength="20" value="' + esc(SC.profile && SC.profile.nickname) + '"><button class="shared-secondary" onclick="SharedCalendar.saveProfile()">저장</button></div><small class="shared-help">친구 코드를 공유해 초대할 수 있습니다.</small></div><div class="shared-profile-box"><h3>친구 추가</h3><div class="shared-inline-form"><input class="shared-input" id="sharedFriendCodeInput" maxlength="8" placeholder="친구 코드 8자리"><button class="shared-primary" onclick="SharedCalendar.sendFriendRequest()">요청 보내기</button></div></div><div class="shared-subsection"><h3>친구 <span>' + SC.friends.length + '</span></h3>' + friendRows + '</div><div class="shared-subsection"><h3>받은 친구 요청</h3>' + requestRows + '</div><div class="shared-subsection"><h3>그룹 초대</h3>' + inviteRows + '</div><div class="shared-subsection"><h3>보낸 요청</h3><div class="shared-empty">' + (outgoing.length ? '상대방의 수락을 기다리는 중입니다.' : '보낸 요청이 없습니다.') + '</div></div></section>';
  }
  function renderEvents() {
    var me = SC.profile && SC.profile.user_id;
    var received = SC.sharedEvents.filter(function (event) { return event.owner_user_id !== me && (event.event_shares || []).some(function (share) { return share.target_user_id === me && share.status === 'active'; }); });
    var receivedHtml = received.length ? received.slice(0, 50).map(function (event) { var share = shareFor(event, 'user', me); return '<div class="shared-list-row"><span>📥</span><span><strong>' + esc(sharedTitle(event, share)) + '</strong><small>' + esc(eventDate(event)) + (sharedMemo(event, share) ? ' · ' + esc(sharedMemo(event, share)) : '') + '</small></span></div>'; }).join('') : '<div class="shared-empty">사람에게 직접 받은 일정이 없습니다.</div>';
    var owned = SC.sharedEvents.filter(function (event) { return event.owner_user_id === me; });
    var ownedHtml = owned.length ? owned.slice(0, 50).map(function (event) { return '<div class="shared-list-row"><span>📅</span><span><strong>' + esc(event.title) + '</strong><small>' + esc(eventDate(event)) + '</small></span><button class="shared-secondary" onclick="SharedCalendar.openShareComposer(' + "'" + esc(event.source_ref || event.id) + "'" + ')">공유 관리</button></div>'; }).join('') : '<div class="shared-empty">공유한 일정이 여기에 표시됩니다.</div>';
    return '<section class="shared-card"><div class="shared-card-heading"><div><h2>공유 관리</h2><p>원본 일정은 내 캘린더에 남고 공유 연결만 관리합니다.</p></div><span class="shared-count">' + owned.length + '개</span></div><div class="shared-subsection"><h3>나에게 공유된 일정</h3>' + receivedHtml + '</div><div class="shared-subsection"><h3>내가 공유한 일정</h3>' + ownedHtml + '</div></section>';
  }
  function render() {
    var center = document.getElementById('centerContent');
    if (!center || !window.Goalivo || Goalivo.state.currentPage !== 'shared') return;
    var localLabel = SC.local ? '로컬 미리보기' : (SC.profile && SC.profile.nickname || '사용자') + ' · 동기화됨';
    center.innerHTML = '<div class="shared-calendar-page"><div class="shared-page-head"><div><span class="shared-eyebrow">SHARED CALENDAR</span><h1>사람과 그룹으로 공유</h1><p>' + esc(localLabel) + ' · 명시적으로 공유한 일정만 보입니다.</p></div><div class="shared-page-actions"><button class="shared-secondary" onclick="SharedCalendar.refresh()">새로고침</button>' + (SC.local ? '<button class="shared-primary" onclick="Goalivo.openModal(\'authModal\')">로그인하고 실제 초대 연결</button>' : '') + '</div></div><div class="shared-tabs"><button class="' + (SC.tab === 'groups' ? 'active' : '') + '" onclick="SharedCalendar.setTab(\'groups\')">그룹</button><button class="' + (SC.tab === 'people' ? 'active' : '') + '" onclick="SharedCalendar.setTab(\'people\')">사람</button><button class="' + (SC.tab === 'events' ? 'active' : '') + '" onclick="SharedCalendar.setTab(\'events\')">공유 관리</button></div>' + (SC.tab === 'groups' ? renderGroups() : SC.tab === 'people' ? renderPeople() : renderEvents()) + '</div>';
  }
  function selectGroup(id) { SC.selectedGroupId = id; SC.tab = 'groups'; render(); }
  function showGroups() { SC.selectedGroupId = null; SC.tab = 'groups'; render(); }
  function setTab(tab) { SC.selectedGroupId = null; SC.tab = tab; render(); }
  async function refresh() { try { await load(); render(); } catch (error) { console.error(error); toast(error.message || '공유 캘린더를 불러오지 못했습니다', 'error'); } }
  function ensureNav() {
    var header = document.getElementById('headerNav');
    if (header && !header.querySelector('[data-page="shared"]')) {
      var button = document.createElement('button'); button.className = 'header-nav-btn shared-nav-btn'; button.dataset.page = 'shared'; button.textContent = 'Shared'; button.onclick = function () { openPage('groups'); }; header.appendChild(button);
    }
    var bottom = document.querySelector('.bottom-tabs-inner');
    if (bottom && !bottom.querySelector('[data-page="shared"]')) {
      var tab = document.createElement('button'); tab.className = 'bottom-tab shared-nav-btn'; tab.dataset.page = 'shared'; tab.innerHTML = '<span class="bottom-tab-icon">👥</span>공유'; tab.onclick = function () { openPage('groups'); }; bottom.appendChild(tab);
    }
  }
  async function openPage(tab) {
    SC.tab = tab || 'groups'; SC.selectedGroupId = null; Goalivo.navigate('shared'); render(); await refresh();
  }
  async function openBulkShare(groupId) { openShareComposer('', groupId); }
  function closeShare() { var modal = document.getElementById('sharedShareModal'); if (modal) modal.remove(); }
  async function openSharedEventDetail(id) {
    var event = findEvent(id);
    if (event) toast(event.title + ' · ' + eventDate(event), 'info');
  }
  function injectShareButton() {
    var right = document.getElementById('rightPanelContent'), actions = right && right.querySelector('.detail-actions');
    if (!right || right.dataset.sharedButton === '1') return;
    var button = document.createElement('button'); button.className = 'btn btn-primary shared-detail-share-button'; button.textContent = '이 일정 공유하기';
    button.onclick = function () { var state = Goalivo.state, block = state.selectedBlockId && state.timeBlocks.find(function (item) { return item.id === state.selectedBlockId; }); if (block) openShareComposer('local:' + block.id); else if (state._sharedExternalEventContext) openShareComposer(state._sharedExternalEventContext); };
    var firstCard = right.querySelector('.detail-card');
    if (firstCard) {
      var shareAction = document.createElement('div'); shareAction.className = 'shared-detail-share-action'; shareAction.appendChild(button);
      firstCard.insertAdjacentElement('afterend', shareAction);
      right.dataset.sharedButton = '1';
    } else if (actions) {
      actions.appendChild(button);
      right.dataset.sharedButton = '1';
    }
  }
  async function init() {
    if (SC.initialized || !window.Goalivo) return;
    SC.initialized = true; ensureNav();
    var originalNavigate = Goalivo.navigate;
    Goalivo.navigate = function (page) {
      if (page !== 'shared') { document.body.classList.remove('shared-page-active'); document.getElementById('leftPanel')?.classList.remove('shared-hidden-panel'); document.getElementById('rightPanel')?.classList.remove('shared-hidden-panel'); }
      var result = originalNavigate.call(Goalivo, page);
      if (page === 'shared') { document.body.classList.add('shared-page-active'); document.getElementById('leftPanel')?.classList.add('shared-hidden-panel'); document.getElementById('rightPanel')?.classList.add('shared-hidden-panel'); render(); }
      return result;
    };
    var originalBlock = Goalivo.openBlockDetail;
    Goalivo.openBlockDetail = function () { var panel = document.getElementById('rightPanelContent'); if (panel) panel.dataset.sharedButton = '0'; var result = originalBlock.apply(Goalivo, arguments); setTimeout(injectShareButton, 0); return result; };
    var originalExternal = Goalivo.openExternalEventDetail;
    Goalivo.openExternalEventDetail = function (eventId, start) { var panel = document.getElementById('rightPanelContent'); if (panel) panel.dataset.sharedButton = '0'; var event = (Goalivo.state.externalEvents || []).find(function (item) { return item.eventId === eventId && (!start || item.start === start); }) || (Goalivo.state.externalEvents || []).find(function (item) { return item.eventId === eventId; }); if (event) Goalivo.state._sharedExternalEventContext = 'google:' + (event.calendarId || 'primary') + ':' + event.eventId + ':' + (event.start || ''); var result = originalExternal.call(Goalivo, eventId, start); setTimeout(injectShareButton, 0); return result; };
    await refresh();
  }
  window.SharedCalendar = { init: init, render: render, refresh: refresh, setTab: setTab, selectGroup: selectGroup, showGroups: showGroups, saveProfile: saveProfile, sendFriendRequest: sendFriendRequest, respondFriendRequest: respondFriendRequest, createGroup: createGroup, inviteToGroup: inviteToGroup, respondGroupInvite: respondGroupInvite, updateMemberRole: updateMemberRole, removeMember: removeMember, openBulkShare: openBulkShare, openShareComposer: openShareComposer, confirmShare: confirmShare, closeModal: closeShare, openSharedEventDetail: openSharedEventDetail };
  var style = document.createElement('style');
  style.textContent = '.shared-hidden-panel{display:none!important}body.shared-page-active .center-panel{grid-column:1/-1}#rightPanelContent .shared-detail-share-action{margin:0 0 12px}#rightPanelContent .shared-detail-share-button{width:100%;min-height:44px;font-weight:700}.shared-calendar-page{max-width:1100px;margin:0 auto;padding:26px}.shared-page-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-start;margin-bottom:18px}.shared-eyebrow{color:var(--c-accent);font-size:11px;letter-spacing:.14em;font-weight:800}.shared-page-head h1{margin:5px 0 4px;font-size:clamp(24px,4vw,36px)}.shared-page-head p,.shared-card p{color:var(--c-text-muted);margin:0;font-size:13px}.shared-page-actions,.shared-action-grid,.shared-inline-form,.shared-modal-actions{display:flex;gap:8px;flex-wrap:wrap;align-items:center}.shared-primary,.shared-secondary,.shared-danger,.shared-icon-btn{border:0;border-radius:10px;padding:10px 14px;cursor:pointer;font:inherit}.shared-primary{background:var(--c-accent);color:#fff}.shared-secondary{background:var(--c-surface-alt);color:var(--c-text);border:1px solid var(--c-border)}.shared-danger{background:rgba(220,38,38,.1);color:#dc2626}.shared-tabs{display:flex;gap:4px;border-bottom:1px solid var(--c-border);margin-bottom:16px}.shared-tabs button{background:none;border:0;padding:11px 16px;cursor:pointer;color:var(--c-text-muted);border-bottom:2px solid transparent}.shared-tabs button.active{color:var(--c-accent);border-color:var(--c-accent);font-weight:700}.shared-card{background:var(--c-surface);border:1px solid var(--c-border);border-radius:18px;padding:20px}.shared-card-heading{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:18px}.shared-card h2{margin:0 0 5px;font-size:21px}.shared-card h3{margin:0 0 10px;font-size:14px}.shared-count,.shared-code,.shared-role{background:var(--c-accent-bg);color:var(--c-accent);border-radius:999px;padding:5px 9px;font-size:12px;font-weight:700;white-space:nowrap}.shared-code{letter-spacing:.12em}.shared-create-box,.shared-profile-box,.shared-access-box{background:var(--c-surface-alt);border-radius:14px;padding:14px;margin-bottom:18px}.shared-create-box h3{margin-bottom:10px}.shared-input{min-height:38px;min-width:0;flex:1;border:1px solid var(--c-border);border-radius:9px;padding:8px 10px;background:var(--c-surface);color:var(--c-text)}.shared-create-box>.shared-input{width:100%;margin-top:8px}.shared-group-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:10px}.shared-group-card{display:grid;grid-template-columns:auto 1fr auto;gap:11px;align-items:center;text-align:left;border:1px solid var(--c-border);border-radius:14px;padding:13px;background:var(--c-surface);color:var(--c-text);cursor:pointer}.shared-group-icon{width:36px;height:36px;border-radius:12px;display:grid;place-items:center;color:#fff}.shared-group-card strong,.shared-list-row strong{display:block}.shared-group-card small,.shared-list-row small{color:var(--c-text-muted);display:block;margin-top:3px;font-size:11px}.shared-group-arrow{color:var(--c-text-muted);font-size:22px}.shared-subsection{border-top:1px solid var(--c-border);padding-top:16px;margin-top:17px}.shared-subsection h3 span{color:var(--c-accent);margin-left:3px}.shared-list-row{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid color-mix(in srgb,var(--c-border) 55%,transparent)}.shared-list-row>span:nth-child(2){flex:1;min-width:0}.shared-avatar{width:30px;height:30px;display:grid;place-items:center;border-radius:50%;background:var(--c-accent-bg)}.shared-member-list{display:flex;gap:6px;flex-wrap:wrap}.shared-member-chip{background:var(--c-surface-alt);border-radius:999px;padding:7px 10px;font-size:12px}.shared-help,.shared-access-box small{display:block;color:var(--c-text-muted);font-size:11px;margin-top:7px;line-height:1.45}.shared-empty{padding:22px 8px;text-align:center;color:var(--c-text-muted);font-size:13px}.shared-selection-tip{background:var(--c-accent-bg);color:var(--c-accent);padding:10px;border-radius:10px;font-size:12px;margin:10px 0}.shared-event-picker,.shared-share-targets{max-height:330px;overflow:auto;border:1px solid var(--c-border);border-radius:12px}.shared-event-row,.shared-target-row{display:flex;gap:9px;align-items:center;padding:10px 12px;border-bottom:1px solid var(--c-border);cursor:pointer}.shared-event-row:last-child,.shared-target-row:last-child{border-bottom:0}.shared-event-row.selected{background:var(--c-accent-bg)}.shared-event-dot{width:8px;height:8px;border-radius:50%;background:var(--c-accent);flex:0 0 auto}.shared-event-main{flex:1;min-width:0}.shared-event-main small{display:block;color:var(--c-text-muted);margin-top:3px;font-size:11px}.shared-access-box{margin-top:12px}.shared-access-box label{display:block;font-weight:700;font-size:12px;margin-bottom:6px}.shared-modal-overlay{position:fixed;inset:0;background:rgba(15,23,42,.48);z-index:9999;display:grid;place-items:center;padding:16px}.shared-modal{width:min(720px,100%);max-height:min(88vh,760px);overflow:auto;background:var(--c-surface);color:var(--c-text);border-radius:18px;padding:20px;box-shadow:0 18px 60px rgba(15,23,42,.25)}.shared-icon-btn{background:transparent;color:var(--c-text-muted);font-size:24px;padding:2px 8px}.shared-link{border:0;background:none;color:var(--c-accent);cursor:pointer;padding:0 0 10px}@media(max-width:700px){.shared-calendar-page{padding:16px 12px}.shared-page-head{display:block}.shared-page-actions{margin-top:12px}.shared-page-actions button{flex:1}.shared-group-grid{grid-template-columns:1fr}.shared-card{padding:15px}.shared-modal{padding:15px}}';
  document.head.appendChild(style);
  window.addEventListener('goalivo:ready', function () { if (window.SharedCalendar) init().catch(console.error); });
  if (typeof Goalivo !== 'undefined' && document.readyState !== 'loading') setTimeout(function () { init().catch(console.error); }, 0);
})();
