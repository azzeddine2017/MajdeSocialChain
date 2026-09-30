<script>
  import { onMount } from 'svelte'
  import Feed from './lib/Feed.svelte'
  import Stories from './lib/Stories.svelte'
  import CreatePost from './lib/CreatePost.svelte'
  import WalletOnboarding from './lib/WalletOnboarding.svelte'
  import WalletView from './lib/WalletView.svelte'
  import ProfileView from './lib/ProfileView.svelte'
  import MessagesView from './lib/MessagesView.svelte'
  import NotificationsDrawer from './lib/NotificationsDrawer.svelte'
  import NodePanel from './lib/NodePanel.svelte'
  import { currentLang, currentTheme, t, setLanguage, setTheme } from './lib/i18n.js'
  import { BRAND_LOGO } from './lib/brandLogo.js'

  let unlocked = false
  let posts = []
  let balance = 0
  let activeTab = 'feed' // 'feed' | 'wallet' | 'profile' | 'messages' | 'node'
  let activeFilter = 'latest'
  let isRefreshing = false
  let currentUserId = ''
  let notifDrawerOpen = false
  let unreadCount = 0
  let unreadPollInterval = null

  onMount(async () => {
    // Initialize language & theme on start
    setLanguage($currentLang)
    setTheme($currentTheme)

    // Check if there is an existing authenticated session in companion DB
    try {
      if (window.checkSession) {
        const session = await window.checkSession()
        if (session && session.authenticated && session.user_id) {
          currentUserId = session.user_id
          unlocked = true
          loadFeed()
          loadBalance()
          startUnreadPolling()
          startAutoSync()
          return
        }
      }
    } catch (e) {
      console.error('Session check failed:', e)
    }
  })

  async function handleLogout() {
    try {
      if (window.logout) {
        await window.logout()
      }
    } catch (_) {}
    if (unreadPollInterval) {
      clearInterval(unreadPollInterval)
      unreadPollInterval = null
    }
    if (autoSyncInterval) {
      clearInterval(autoSyncInterval)
      autoSyncInterval = null
    }
    unlocked = false
    currentUserId = ''
    posts = []
    balance = 0
    unreadCount = 0
    activeTab = 'feed'
  }

  async function loadFeed(filter = activeFilter) {
    activeFilter = filter
    isRefreshing = true
    try {
      if (window.getFeed) {
        let res = await window.getFeed('me', filter)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (Array.isArray(res)) {
          posts = res.map(item => {
            if (Array.isArray(item) && item.length > 0 && Array.isArray(item[0])) {
              const obj = {}
              item.forEach(pair => {
                if (Array.isArray(pair) && pair.length >= 2) {
                  obj[pair[0]] = pair[1]
                }
              })
              return obj
            }
            return item
          })
        }
      }
    } catch (err) {
      console.error('Error loading feed:', err)
    } finally {
      setTimeout(() => isRefreshing = false, 400)
    }
  }

  async function loadBalance() {
    try {
      if (window.getBalance) {
        balance = await window.getBalance('me')
      }
    } catch (err) {
      console.error('Error loading balance:', err)
    }
  }

  async function handleUnlocked(e) {
    unlocked = true
    // Try to get the user id from the event detail first
    if (e?.detail?.user_id) {
      currentUserId = e.detail.user_id
    } else {
      // Fall back to getProfile to resolve active user ID
      try {
        if (window.getProfile) {
          const p = await window.getProfile('me')
          if (p && p.id) currentUserId = p.id
        }
      } catch (_) {}
    }
    loadFeed()
    loadBalance()
    startUnreadPolling()
    startAutoSync()
  }

  let autoSyncInterval = null
  let isAutoSyncing = false

  function startAutoSync() {
    if (autoSyncInterval) clearInterval(autoSyncInterval)
    // Trigger initial background sync after 1.5 seconds
    setTimeout(triggerBackgroundSync, 1500)
    // Periodic auto-sync every 20 seconds
    autoSyncInterval = setInterval(triggerBackgroundSync, 20000)
  }

  async function triggerBackgroundSync() {
    if (isAutoSyncing) return
    isAutoSyncing = true
    try {
      if (window.syncNow) {
        const res = await window.syncNow()
        if (res && (Number(res.synced_posts) > 0 || Number(res.synced_blocks) > 0 || Number(res.synced_messages) > 0)) {
          // If new content received, reload feed and balances quietly
          await loadFeed(activeFilter)
          await loadBalance()
          await loadUnreadCount()
        }
      }
    } catch (_) {
    } finally {
      isAutoSyncing = false
    }
  }

  function startUnreadPolling() {
    if (unreadPollInterval) clearInterval(unreadPollInterval)
    loadUnreadCount()
    unreadPollInterval = setInterval(loadUnreadCount, 15000)
  }

  async function loadUnreadCount() {
    try {
      if (window.getUnreadCount) {
        const res = await window.getUnreadCount()
        if (res && typeof res.total !== 'undefined') {
          unreadCount = Number(res.total) || 0
        }
      }
    } catch (e) {}
  }

  function toggleLanguage() {
    const next = $currentLang === 'ar' ? 'en' : 'ar'
    setLanguage(next)
  }

  function toggleTheme() {
    const next = $currentTheme === 'oled' ? 'cyber' : 'oled'
    setTheme(next)
  }
</script>

{#if !unlocked}
  <WalletOnboarding on:unlocked={handleUnlocked} />
{:else}
  <!-- Desktop & Mobile Shell Container -->
  <div class="min-h-screen flex flex-col md:flex-row justify-center max-w-[1280px] mx-auto">
    
    <!-- DESKTOP SIDEBAR (Visible on md: >= 768px) -->
    <aside class="hidden md:flex flex-col justify-between w-64 xl:w-72 p-4 h-screen sticky top-0 border-e border-zinc-800/80 glass-nav">
      <div class="space-y-6">
        <!-- Logo Branding -->
        <button 
          type="button" 
          class="flex items-center gap-3 bg-transparent border-0 p-2 text-start cursor-pointer" 
          on:click={() => { activeTab = 'feed'; loadFeed(); }}
        >
          <div class="w-10 h-10 rounded-2xl bg-gradient-to-tr from-amber-500 via-orange-600 to-purple-600 p-0.5 shadow-lg shadow-amber-500/20 group-hover:scale-105 transition-transform duration-200">
            <div class="w-full h-full bg-zinc-950 rounded-[14px] flex items-center justify-center overflow-hidden p-1">
              {#if BRAND_LOGO}
                <img src={BRAND_LOGO} alt="Mejde" class="w-full h-full object-contain" />
              {:else}
                <span class="text-sm font-black text-white">⛓️</span>
              {/if}
            </div>
          </div>
          <div>
            <h1 class="font-black text-xl gradient-text tracking-tight leading-none">{t('appName', $currentLang)}</h1>
            <span class="text-[10px] text-zinc-500 font-mono block mt-1">Mejde Network v1.0</span>
          </div>
        </button>

        <!-- Navigation Links -->
        <nav class="space-y-1.5 pt-2">
          <button 
            type="button"
            on:click={() => { activeTab = 'feed'; loadFeed(); }}
            class="w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition font-bold text-sm {activeTab === 'feed' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30' : 'text-zinc-400 hover:bg-zinc-800/60 hover:text-white'}"
          >
            <span class="text-xl">🏠</span>
            <span>{t('tabFeed', $currentLang)}</span>
          </button>

          <button 
            type="button"
            on:click={() => { activeTab = 'wallet'; loadBalance(); }}
            class="w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition font-bold text-sm {activeTab === 'wallet' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30' : 'text-zinc-400 hover:bg-zinc-800/60 hover:text-white'}"
          >
            <span class="text-xl">🪙</span>
            <span>{t('tabWallet', $currentLang)}</span>
          </button>

          <button 
            type="button"
            on:click={() => { activeTab = 'profile'; }}
            class="w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition font-bold text-sm {activeTab === 'profile' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30' : 'text-zinc-400 hover:bg-zinc-800/60 hover:text-white'}"
          >
            <span class="text-xl">👤</span>
            <span>{t('tabProfile', $currentLang)}</span>
          </button>

          <button 
            type="button"
            on:click={() => { activeTab = 'messages'; }}
            class="w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition font-bold text-sm {activeTab === 'messages' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30' : 'text-zinc-400 hover:bg-zinc-800/60 hover:text-white'} relative"
          >
            <span class="text-xl">💬</span>
            <span>{t('tabMessages', $currentLang)}</span>
            {#if unreadCount > 0}
              <span class="ms-auto text-[10px] bg-indigo-500 text-white rounded-full px-1.5 py-0.5 font-bold min-w-[18px] text-center">{unreadCount}</span>
            {/if}
          </button>

          <button 
            type="button"
            on:click={() => { activeTab = 'node'; }}
            class="w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition font-bold text-sm {activeTab === 'node' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/30' : 'text-zinc-400 hover:bg-zinc-800/60 hover:text-white'}"
          >
            <span class="text-xl">🖥️</span>
            <span>{t('tabNode', $currentLang)}</span>
          </button>
        </nav>
      </div>

      <!-- Footer Preferences (Language & Theme toggles) -->
      <div class="space-y-3 pt-4 border-t border-zinc-800/80">
        <!-- Live Balance Widget in Sidebar -->
        <div class="p-3 bg-zinc-900/80 rounded-2xl border border-amber-500/20 text-xs">
          <div class="text-[10px] text-zinc-400 font-medium mb-0.5">{t('tokenName', $currentLang)}</div>
          <div class="font-black text-amber-300 text-base">{Number(balance).toLocaleString()} WALA</div>
        </div>

        <!-- Controls Row -->
        <div class="flex items-center gap-2">
          <!-- Language Toggle Button -->
          <button 
            type="button"
            on:click={toggleLanguage}
            class="flex-1 py-2 px-3 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-bold text-zinc-300 transition flex items-center justify-center gap-1.5"
            title="تبديل اللغة / Change Language"
          >
            <span>🌐</span>
            <span>{$currentLang === 'ar' ? 'English' : 'عربي'}</span>
          </button>

          <!-- Theme Toggle Button -->
          <button 
            type="button"
            on:click={toggleTheme}
            class="py-2 px-3 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-bold text-zinc-300 transition"
            title="تبديل المظهر / Toggle Theme"
          >
            {$currentTheme === 'oled' ? '🌙 OLED' : '🔷 Cyber'}
          </button>
        </div>

        <!-- Logout Button -->
        <button
          type="button"
          on:click={handleLogout}
          class="w-full py-2 px-3 rounded-xl bg-zinc-900/60 hover:bg-rose-950/40 border border-zinc-800 hover:border-rose-800/40 text-xs font-bold text-zinc-400 hover:text-rose-400 transition flex items-center justify-center gap-1.5"
          title="تسجيل الخروج / Logout"
        >
          <span>🚪</span>
          <span>{$currentLang === 'ar' ? 'تسجيل الخروج' : 'Logout'}</span>
        </button>
      </div>
    </aside>

    <!-- CENTER FEED & ACTIVE TAB VIEW (Responsive for Mobile & Desktop) -->
    <div class="flex-1 max-w-[620px] w-full min-h-screen border-e border-zinc-800/80 pb-24 md:pb-8">
      
      <!-- Top Header (Always visible on mobile, minimal on desktop) -->
      <header class="sticky top-0 z-40 glass-nav border-b border-zinc-800/80 px-4 py-2.5 flex justify-between items-center backdrop-blur-xl">
        <!-- Brand (Mobile only) -->
        <button 
          type="button" 
          class="flex md:hidden items-center gap-2.5 bg-transparent border-0 p-0 text-start cursor-pointer" 
          on:click={() => { activeTab = 'feed'; loadFeed(); }}
        >
          <div class="w-8 h-8 rounded-xl bg-gradient-to-tr from-amber-500 via-orange-600 to-purple-600 p-0.5 shadow-md shadow-amber-500/20">
            <div class="w-full h-full bg-zinc-950 rounded-[10px] flex items-center justify-center overflow-hidden p-0.5">
              {#if BRAND_LOGO}
                <img src={BRAND_LOGO} alt="Mejde" class="w-full h-full object-contain" />
              {:else}
                <span class="text-xs font-black text-white">⛓️</span>
              {/if}
            </div>
          </div>
          <span class="font-black text-lg gradient-text tracking-tight">{t('appName', $currentLang)}</span>
        </button>

        <!-- Current Tab Title (Desktop only) -->
        <div class="hidden md:flex items-center gap-2">
          <span class="font-bold text-sm text-zinc-200">
            {activeTab === 'feed' ? t('tabFeed', $currentLang) :
             activeTab === 'wallet' ? t('tabWallet', $currentLang) :
             activeTab === 'profile' ? t('tabProfile', $currentLang) :
             activeTab === 'messages' ? t('tabMessages', $currentLang) :
             activeTab === 'node' ? t('tabNode', $currentLang) :
             t('tabFeed', $currentLang)}
          </span>
          <span class="text-[10px] bg-emerald-500/10 text-emerald-400 px-2 py-0.5 rounded-full font-mono border border-emerald-500/20">LibSQL Sync ✓</span>
        </div>

        <!-- Top Right Actions -->
        <div class="flex items-center gap-2">
          <!-- Mobile Language / Theme quick toggle -->
          <div class="flex md:hidden items-center gap-1">
            <button 
              type="button"
              on:click={toggleLanguage}
              class="px-2 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-[11px] font-bold text-zinc-400"
            >
              {$currentLang === 'ar' ? 'EN' : 'عربي'}
            </button>
            <button 
              type="button"
              on:click={toggleTheme}
              class="px-2 py-1 rounded-lg bg-zinc-900 border border-zinc-800 text-[11px] font-bold text-zinc-400"
            >
              {$currentTheme === 'oled' ? '🌙' : '🔷'}
            </button>
          </div>

          <!-- Quick Balance Pill (Opens Wallet) -->
          <button 
            type="button"
            on:click={() => { activeTab = 'wallet'; loadBalance(); }}
            class="flex items-center gap-1.5 px-3 py-1 rounded-full bg-zinc-900/90 border border-amber-500/30 text-amber-300 hover:bg-zinc-850 transition active:scale-95 text-xs font-bold shadow-sm"
            title={t('tabWallet', $currentLang)}
          >
            <span>🪙</span>
            <span>{Number(balance).toLocaleString()} WALA</span>
          </button>

          <!-- Notification Bell -->
          <button
            type="button"
            on:click={() => { notifDrawerOpen = true }}
            class="relative w-8 h-8 rounded-full bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-400 hover:text-white transition active:scale-90 text-sm"
            title={t('notifications', $currentLang)}
          >
            🔔
            {#if unreadCount > 0}
              <span class="absolute -top-0.5 -right-0.5 min-w-[16px] h-4 bg-indigo-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1">{unreadCount > 99 ? '99+' : unreadCount}</span>
            {/if}
          </button>

          <!-- Refresh Button -->
          <button 
            type="button"
            on:click={() => { loadFeed(); loadBalance(); }}
            class="w-8 h-8 rounded-full bg-zinc-900 border border-zinc-800 flex items-center justify-center text-zinc-400 hover:text-white transition active:scale-90 text-xs"
            title="تحديث البيانات"
          >
            <span class={isRefreshing ? 'animate-spin' : ''}>🔄</span>
          </button>
        </div>
      </header>

      <!-- Main Body Content for Active Tab -->
      <main class="pt-2">
        {#if activeTab === 'feed'}
          <Stories />
          <div class="h-2"></div>
          <CreatePost on:created={() => loadFeed(activeFilter)} />
          <Feed 
            {posts} 
            {activeFilter}
            on:filterChanged={(e) => loadFeed(e.detail)}
            on:balanceChanged={loadBalance} 
          />
        {:else if activeTab === 'wallet'}
          <WalletView {balance} on:balanceChanged={loadBalance} />
        {:else if activeTab === 'profile'}
          <ProfileView on:logout={handleLogout} on:profileUpdated={() => loadFeed(activeFilter)} />
        {:else if activeTab === 'messages'}
          <div class="p-3">
            <MessagesView currentUser={currentUserId} />
          </div>
        {:else if activeTab === 'node'}
          <NodePanel currentUser={currentUserId} />
        {/if}
      </main>
    </div>

    <!-- DESKTOP RIGHT WIDGET (Visible on xl: >= 1200px) -->
    <aside class="hidden xl:flex flex-col w-72 p-4 h-screen sticky top-0 space-y-4">
      <!-- Search & Discover Widget -->
      <div class="p-4 bg-zinc-900/70 rounded-3xl border border-zinc-800/80 space-y-3">
        <h3 class="font-bold text-sm text-zinc-200">🔍 {t('tabTrends', $currentLang)}</h3>
        <div class="space-y-2 text-xs">
          <div class="p-2.5 rounded-xl bg-zinc-950/60 border border-zinc-800/60 hover:border-indigo-500/40 transition cursor-pointer">
            <div class="text-[10px] text-zinc-500">{t('trendingInMejde', $currentLang)}</div>
            <div class="font-bold text-indigo-300 mt-0.5">#Mejde_Decentralized</div>
            <div class="text-[10px] text-zinc-500 mt-1">1,420 {t('interactionsCount', $currentLang)}</div>
          </div>
          <div class="p-2.5 rounded-xl bg-zinc-950/60 border border-zinc-800/60 hover:border-indigo-500/40 transition cursor-pointer">
            <div class="text-[10px] text-zinc-500">{t('loyaltyEconomy', $currentLang)}</div>
            <div class="font-bold text-indigo-300 mt-0.5">#WalaCoin_Mining</div>
            <div class="text-[10px] text-zinc-500 mt-1">980 {t('txsCount', $currentLang)}</div>
          </div>
        </div>
      </div>

      <!-- Blockchain Telemetry Card -->
      <div class="p-4 bg-zinc-900/70 rounded-3xl border border-zinc-800/80 space-y-2 text-xs">
        <div class="flex items-center justify-between">
          <span class="font-bold text-zinc-200">{t('nodeStatus', $currentLang)}</span>
          <span class="text-[10px] text-emerald-400 font-mono">{t('nodeSynced', $currentLang)}</span>
        </div>
        <div class="text-zinc-400 text-[11px] leading-relaxed">
          {t('nodeDescription', $currentLang)}
        </div>
      </div>
    </aside>

  </div>

  <!-- MOBILE BOTTOM DOCK (Visible on mobile only < md: 768px) -->
  <nav class="fixed bottom-3 left-0 right-0 z-50 px-4 pointer-events-none flex md:hidden justify-center">
    <div class="glass-nav border border-zinc-800/90 rounded-full px-5 py-2 shadow-2xl backdrop-blur-2xl pointer-events-auto flex items-center gap-4 bg-zinc-950/90">
      <!-- Feed Tab -->
      <button 
        type="button"
        on:click={() => { activeTab = 'feed'; loadFeed(); }}
        class="flex items-center gap-1.5 py-1.5 px-3 rounded-full transition-all duration-200 {activeTab === 'feed' ? 'bg-indigo-600 text-white font-bold shadow-md shadow-indigo-600/30' : 'text-zinc-400 hover:text-zinc-200'}"
      >
        <span class="text-base">🏠</span>
        <span class="text-xs">{t('tabFeed', $currentLang)}</span>
      </button>

      <!-- Wallet Tab -->
      <button 
        type="button"
        on:click={() => { activeTab = 'wallet'; loadBalance(); }}
        class="flex items-center gap-1.5 py-1.5 px-3 rounded-full transition-all duration-200 {activeTab === 'wallet' ? 'bg-indigo-600 text-white font-bold shadow-md shadow-indigo-600/30' : 'text-zinc-400 hover:text-zinc-200'}"
      >
        <span class="text-base">🪙</span>
        <span class="text-xs">{t('tabWallet', $currentLang)}</span>
      </button>

      <!-- Messages Tab -->
      <button 
        type="button"
        on:click={() => { activeTab = 'messages'; }}
        class="relative flex items-center gap-1.5 py-1.5 px-3 rounded-full transition-all duration-200 {activeTab === 'messages' ? 'bg-indigo-600 text-white font-bold shadow-md shadow-indigo-600/30' : 'text-zinc-400 hover:text-zinc-200'}"
      >
        <span class="text-base">💬</span>
        {#if unreadCount > 0}
          <span class="absolute -top-1 -right-1 min-w-[14px] h-3.5 bg-indigo-400 text-white text-[8px] font-bold rounded-full flex items-center justify-center px-0.5">{unreadCount}</span>
        {/if}
      </button>

      <!-- Profile Tab -->
      <button 
        type="button"
        on:click={() => { activeTab = 'profile'; }}
        class="flex items-center gap-1.5 py-1.5 px-3 rounded-full transition-all duration-200 {activeTab === 'profile' ? 'bg-indigo-600 text-white font-bold shadow-md shadow-indigo-600/30' : 'text-zinc-400 hover:text-zinc-200'}"
      >
        <span class="text-base">👤</span>
        <span class="text-xs">{t('tabProfile', $currentLang)}</span>
      </button>

      <!-- Node Tab (Mobile) -->
      <button 
        type="button"
        on:click={() => { activeTab = 'node'; }}
        class="flex items-center gap-1.5 py-1.5 px-3 rounded-full transition-all duration-200 {activeTab === 'node' ? 'bg-indigo-600 text-white font-bold shadow-md shadow-indigo-600/30' : 'text-zinc-400 hover:text-zinc-200'}"
        title={t('tabNode', $currentLang)}
      >
        <span class="text-base">🖥️</span>
        <span class="text-xs">{t('tabNode', $currentLang)}</span>
      </button>
    </div>
  </nav>

  <!-- Notifications Drawer (Global overlay) -->
  <NotificationsDrawer
    open={notifDrawerOpen}
    {unreadCount}
    onClose={() => { notifDrawerOpen = false; loadUnreadCount(); }}
  />
{/if}
