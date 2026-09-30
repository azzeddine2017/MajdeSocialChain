<script>
  import { onMount } from 'svelte'
  import { currentLang, t } from './i18n.js'

  export let open = false
  export let onClose = () => {}
  export let unreadCount = 0

  let notifications = []
  let loading = false

  $: lang = $currentLang
  $: dir = lang === 'ar' ? 'rtl' : 'ltr'

  $: if (open) loadNotifications()

  async function loadNotifications() {
    loading = true
    try {
      const res = await window.getNotifications()
      notifications = Array.isArray(res) ? res : []
    } catch (e) {
      console.error('getNotifications failed:', e)
      notifications = []
    }
    loading = false
  }

  async function markAllRead() {
    try {
      await window.markNotificationsRead()
      notifications = notifications.map(n => ({ ...n, is_read: 1 }))
      unreadCount = 0
    } catch (e) {
      console.error('markNotificationsRead failed:', e)
    }
  }

  function getNotifIcon(type) {
    const icons = {
      rating: '⭐',
      comment: '💬',
      follow: '👥',
      tip: '💰',
      message: '📩',
      reward: '🖥️'
    }
    return icons[type] || '🔔'
  }

  function getNotifAccent(type) {
    const colors = {
      rating: '#fbbf24',
      comment: '#818cf8',
      follow: '#34d399',
      tip: '#f59e0b',
      message: '#c084fc',
      reward: '#60a5fa'
    }
    return colors[type] || '#94a3b8'
  }

  function formatTime(ts) {
    if (!ts) return ''
    try {
      const d = new Date(ts)
      const now = new Date()
      const diff = Math.floor((now - d) / 1000)
      if (diff < 60) return lang === 'ar' ? 'الآن' : 'Just now'
      if (diff < 3600) return `${Math.floor(diff/60)}${lang === 'ar' ? ' د' : 'm'}`
      if (diff < 86400) return `${Math.floor(diff/3600)}${lang === 'ar' ? ' س' : 'h'}`
      return `${Math.floor(diff/86400)}${lang === 'ar' ? ' ي' : 'd'}`
    } catch { return ts }
  }

  function getAvatar(notif) {
    if (notif?.actor_avatar && (notif.actor_avatar.startsWith('data:') || notif.actor_avatar.startsWith('http://') || notif.actor_avatar.startsWith('https://'))) {
      return notif.actor_avatar
    }
    const seed = notif?.actor_name || notif?.actor_id || '?'
    return `https://api.dicebear.com/7.x/identicon/svg?seed=${encodeURIComponent(seed)}`
  }
</script>

{#if open}
  <!-- Backdrop -->
  <div class="drawer-backdrop" on:click={onClose} role="presentation"></div>

  <!-- Drawer panel -->
  <div class="notif-drawer" {dir}>
    <div class="drawer-header">
      <div class="header-left">
        <h2>{t('notifications', lang)}</h2>
        {#if unreadCount > 0}
          <span class="unread-pill">{unreadCount}</span>
        {/if}
      </div>
      <div class="header-actions">
        {#if notifications.some(n => !n.is_read)}
          <button class="btn-mark-read" on:click={markAllRead}>{t('markAllRead', lang)}</button>
        {/if}
        <button class="btn-close" on:click={onClose} aria-label="Close">✕</button>
      </div>
    </div>

    <div class="drawer-body">
      {#if loading}
        <div class="notif-loading">
          <div class="spinner"></div>
        </div>
      {:else if notifications.length === 0}
        <div class="notif-empty">
          <span>🔔</span>
          <p>{t('noNotifications', lang)}</p>
        </div>
      {:else}
        <ul class="notif-list">
          {#each notifications as notif}
            <li class="notif-item {notif.is_read ? 'read' : 'unread'}">
              <!-- Actor avatar -->
              <div class="notif-avatar-wrap">
                <img src={getAvatar(notif)} alt={notif.actor_name} class="notif-avatar" />
                <span class="notif-type-icon" style="background:{getNotifAccent(notif.type)}22;color:{getNotifAccent(notif.type)}">
                  {getNotifIcon(notif.type)}
                </span>
              </div>
              <!-- Content -->
              <div class="notif-content">
                <p class="notif-message">{notif.message}</p>
                <span class="notif-time">{formatTime(notif.created_at)}</span>
              </div>
              <!-- Unread indicator -->
              {#if !notif.is_read}
                <span class="unread-dot"></span>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </div>
{/if}

<style>
  .drawer-backdrop {
    position: fixed; inset: 0; z-index: 300;
    background: rgba(0,0,0,0.5);
    backdrop-filter: blur(4px);
    animation: fadeIn 0.2s ease;
  }
  @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

  .notif-drawer {
    position: fixed; top: 0; right: 0; bottom: 0;
    width: min(380px, 100vw);
    z-index: 301;
    display: flex; flex-direction: column;
    background: var(--bg-base, #070709);
    border-left: 1px solid rgba(255,255,255,0.08);
    box-shadow: -20px 0 60px rgba(0,0,0,0.5);
    animation: slideIn 0.25s cubic-bezier(0.4,0,0.2,1);
  }
  :global([dir="rtl"]) .notif-drawer {
    right: auto; left: 0;
    border-left: none; border-right: 1px solid rgba(255,255,255,0.08);
    box-shadow: 20px 0 60px rgba(0,0,0,0.5);
    animation: slideInRtl 0.25s cubic-bezier(0.4,0,0.2,1);
  }
  @keyframes slideIn { from { transform: translateX(100%); } to { transform: none; } }
  @keyframes slideInRtl { from { transform: translateX(-100%); } to { transform: none; } }

  .drawer-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 20px 20px 16px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }
  .header-left { display: flex; align-items: center; gap: 10px; }
  .drawer-header h2 {
    margin: 0; font-size: 1.1rem; font-weight: 700;
    background: linear-gradient(135deg, #818cf8, #c084fc);
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  }
  .unread-pill {
    background: linear-gradient(135deg, #818cf8, #c084fc);
    color: white; font-size: 0.72rem; font-weight: 700;
    padding: 2px 8px; border-radius: 20px; min-width: 20px;
    text-align: center; display: inline-block;
  }
  .header-actions { display: flex; align-items: center; gap: 8px; }
  .btn-mark-read {
    background: rgba(129,140,248,0.12);
    border: 1px solid rgba(129,140,248,0.25);
    border-radius: 8px; color: #818cf8;
    font-size: 0.78rem; padding: 5px 10px;
    cursor: pointer; transition: background 0.2s;
  }
  .btn-mark-read:hover { background: rgba(129,140,248,0.22); }
  .btn-close {
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 8px; color: #94a3b8;
    width: 32px; height: 32px; cursor: pointer;
    display: flex; align-items: center; justify-content: center;
    transition: background 0.2s; font-size: 0.9rem;
  }
  .btn-close:hover { background: rgba(255,255,255,0.12); color: #e2e8f0; }

  .drawer-body { flex: 1; overflow-y: auto; }

  .notif-loading {
    display: flex; align-items: center; justify-content: center; padding: 60px;
  }
  .spinner {
    width: 32px; height: 32px;
    border: 3px solid rgba(129,140,248,0.2);
    border-top-color: #818cf8;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .notif-empty {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 10px;
    padding: 60px 20px; color: rgba(148,163,184,0.4); text-align: center;
  }
  .notif-empty span { font-size: 2.5rem; }
  .notif-empty p { margin: 0; font-size: 0.9rem; }

  .notif-list { list-style: none; margin: 0; padding: 8px 0; }

  .notif-item {
    display: flex; align-items: flex-start; gap: 12px;
    padding: 14px 18px;
    border-bottom: 1px solid rgba(255,255,255,0.04);
    transition: background 0.18s; position: relative;
    cursor: default;
  }
  .notif-item:hover { background: rgba(255,255,255,0.04); }
  .notif-item.unread { background: rgba(129,140,248,0.05); }

  .notif-avatar-wrap { position: relative; flex-shrink: 0; }
  .notif-avatar { width: 44px; height: 44px; border-radius: 50%; object-fit: cover; }
  .notif-type-icon {
    position: absolute; bottom: -2px; right: -4px;
    width: 20px; height: 20px; border-radius: 50%;
    display: flex; align-items: center; justify-content: center;
    font-size: 0.7rem; font-weight: 700;
    border: 2px solid var(--bg-base, #070709);
  }
  :global([dir="rtl"]) .notif-type-icon { right: auto; left: -4px; }

  .notif-content { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
  .notif-message { margin: 0; font-size: 0.88rem; line-height: 1.45; color: #cbd5e1; }
  .notif-time { font-size: 0.75rem; color: rgba(148,163,184,0.5); }

  .unread-dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: linear-gradient(135deg, #818cf8, #c084fc);
    flex-shrink: 0; align-self: center; margin-top: 2px;
  }
</style>
