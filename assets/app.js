// Shared by index.html (client) and admin.html (agency).
//
// Each page sets window.IS_ADMIN_APP before loading this, and defines its own
// onSignedIn(profile, userId) for whatever it needs to load.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

window.SUPABASE_URL      = 'https://wjshwwivzpazczayuexc.supabase.co';
// Publishable key. Safe in the browser by design: it grants nothing on its own,
// and RLS is what protects the data. Never put an sb_secret_ key in here.
window.SUPABASE_ANON_KEY = 'sb_publishable_IiAkCfE_bNoYNqz6aVZcbA_qOnZoPVn';

window.sb = createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY);

// Customer names are user input rendered into HTML, so escape them.
function esc(str) {
  return String(str).replace(/[&<>"']/g, ch =>
    ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[ch]));
}

// ============================================================
// TAB SWITCHING
// ============================================================
function switchTab(id, btn) {
  document.querySelectorAll('.tab-pane').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(el => {
    el.classList.remove('active');
    el.setAttribute('aria-selected', 'false');
  });
  document.getElementById('tab-' + id).classList.add('active');
  btn.classList.add('active');
  btn.setAttribute('aria-selected', 'true');
}

async function signIn() {
  const btn = document.getElementById('login-btn');
  const err = document.getElementById('login-error');
  err.textContent = '';
  btn.disabled = true; btn.textContent = 'Signing in...';
  const { error } = await sb.auth.signInWithPassword({
    email:    document.getElementById('login-email').value.trim(),
    password: document.getElementById('login-password').value,
  });
  if (error) {
    err.textContent = 'That email and password did not match. Try again.';
    btn.disabled = false; btn.textContent = 'Sign In';
    return;
  }
  await showApp();
}

async function signOut() {
  await sb.auth.signOut();
  location.reload();
}

async function showApp() {
  // Which business this user belongs to, and whether they are agency side.
  // Every read and write is scoped to it, and RLS enforces that server-side
  // regardless of what the app sends.
  const { data: profile } = await sb
    .from('profiles').select('business_id, full_name, is_admin').single();

  if (!profile) {
    document.getElementById('login-error').textContent =
      'That login is not linked to a business yet. Run the add-a-client script.';
    await sb.auth.signOut();
    return;
  }

  // One login, two destinations. Admins belong on the agency dashboard; this
  // is a convenience, not a lock. RLS is what actually keeps the data apart,
  // so a client who guesses the URL sees empty lists rather than someone
  // else's data.
  if (profile.is_admin && !window.IS_ADMIN_APP) {
    window.location.replace('/admin.html');
    return;
  }
  if (!profile.is_admin && window.IS_ADMIN_APP) {
    window.location.replace('/');
    return;
  }

  window.currentProfile  = profile;
  window.currentBusinessId = profile.business_id;
  document.getElementById('login-screen').hidden = true;
  document.getElementById('app').hidden = false;

  const { data: { session } } = await sb.auth.getSession();
  if (typeof onSignedIn === 'function') await onSignedIn(profile, session.user.id);
}

async function initChat(profile, userId) {
  chatState.userId     = userId;
  chatState.isAdmin    = !!profile.is_admin;
  chatState.businessId = profile.business_id;

  if (chatState.isAdmin) {
    const { data: businesses } = await sb.from('businesses').select('id, name').order('name');
    const picker = document.getElementById('chat-business');
    picker.innerHTML = (businesses || [])
      .map(b => `<option value="${esc(b.id)}">${esc(b.name)}</option>`).join('');
    document.getElementById('chat-picker-wrap').hidden = false;
    document.getElementById('chat-sub').textContent =
      'Every client conversation. Pick one to read and reply.';
    if (businesses && businesses.length) chatState.businessId = businesses[0].id;
  }
  await openThread(chatState.businessId);
}

async function openThread(businessId) {
  if (!businessId) return;
  chatState.businessId = businessId;
  const thread = document.getElementById('chat-thread');
  thread.innerHTML = '<p class="cust-empty">Loading...</p>';

  const { data, error } = await sb
    .from('messages')
    .select('id, body, sender_id, created_at')
    .eq('business_id', businessId)
    .order('created_at');

  if (error) { thread.innerHTML = '<p class="cust-empty">Could not load messages.</p>'; return; }
  thread.innerHTML = '';
  if (!data.length) {
    thread.innerHTML = '<p class="cust-empty">No messages yet. Say hello.</p>';
  } else {
    data.forEach(appendMessage);
  }
  subscribeToThread(businessId);
}

function appendMessage(m) {
  const thread = document.getElementById('chat-thread');
  const empty = thread.querySelector('.cust-empty');
  if (empty) empty.remove();
  if (thread.querySelector(`[data-msg="${m.id}"]`)) return;  // realtime echoes our own insert

  const mine = m.sender_id === chatState.userId;
  const el = document.createElement('div');
  el.className = 'msg ' + (mine ? 'msg-me' : 'msg-them');
  el.setAttribute('data-msg', m.id);
  const when = new Date(m.created_at).toLocaleString([], {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  });
  el.innerHTML = `${esc(m.body)}<span class="msg-meta">${esc(when)}</span>`;
  thread.appendChild(el);
  thread.scrollTop = thread.scrollHeight;
}

function subscribeToThread(businessId) {
  if (chatState.channel) sb.removeChannel(chatState.channel);
  chatState.channel = sb
    .channel('messages-' + businessId)
    .on('postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'messages',
          filter: 'business_id=eq.' + businessId },
        payload => appendMessage(payload.new))
    .subscribe();
}

async function sendMessage(e) {
  e.preventDefault();
  const input = document.getElementById('chat-input');
  const btn   = document.getElementById('chat-send');
  const body  = input.value.trim();
  if (!body || !chatState.businessId) return;

  input.value = '';
  btn.disabled = true;
  const { data, error } = await sb.from('messages').insert({
    business_id: chatState.businessId,
    sender_id:   chatState.userId,
    body,
  }).select().single();
  btn.disabled = false;

  if (error) { input.value = body; alert('Message could not be sent. Try again.'); return; }
  appendMessage(data);   // show it now rather than waiting on the realtime round trip
  input.focus();
}

// Expose for the inline onclick handlers in the markup.
Object.assign(window, {
  esc, switchTab, signIn, signOut, showApp,
  initChat, openThread, appendMessage, subscribeToThread, sendMessage,
});

sb.auth.getSession().then(({ data }) => { if (data.session) showApp(); });
