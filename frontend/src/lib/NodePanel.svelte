<script>
  import { onMount } from 'svelte'
  import { currentLang, t } from './i18n.js'

  export let currentUser = ''

  let nodeStatus = null
  let loading = false
  let claiming = false
  let claimResult = null
  let uptimeHours = 1

  // P2P Gossip Sync state
  let peers = []
  let newPeerUrl = ''
  let syncingP2P = false
  let syncFeedback = null
  let addingPeer = false

  $: lang = $currentLang
  $: dir = lang === 'ar' ? 'rtl' : 'ltr'

  onMount(() => {
    loadNodeStatus()
    loadPeers()
  })

  async function loadNodeStatus() {
    loading = true
    try {
      if (window.getNodeStatus) {
        nodeStatus = await window.getNodeStatus()
      }
    } catch (e) {
      console.error('getNodeStatus failed:', e)
    }
    loading = false
  }

  async function loadPeers() {
    try {
      if (window.getPeers) {
        const res = await window.getPeers()
        peers = Array.isArray(res) ? res : []
      }
    } catch (e) {
      console.error('getPeers failed:', e)
    }
  }

  async function syncNow() {
    if (syncingP2P) return
    syncingP2P = true
    syncFeedback = null
    try {
      if (window.syncNow) {
        const res = await window.syncNow()
        syncFeedback = res
        await loadNodeStatus()
        await loadPeers()
      }
    } catch (e) {
      syncFeedback = { status: 'error', error: e.message || String(e) }
    } finally {
      syncingP2P = false
    }
  }

  async function addPeer() {
    const url = newPeerUrl.trim()
    if (!url || addingPeer) return
    addingPeer = true
    try {
      if (window.addPeer) {
        await window.addPeer(url)
        newPeerUrl = ''
        await loadPeers()
        await loadNodeStatus()
      }
    } catch (e) {
      console.error('addPeer failed:', e)
    } finally {
      addingPeer = false
    }
  }

  async function removePeer(peerUrl) {
    try {
      if (window.removePeer) {
        await window.removePeer(peerUrl)
        await loadPeers()
        await loadNodeStatus()
      }
    } catch (e) {
      console.error('removePeer failed:', e)
    }
  }

  async function claimReward() {
    if (claiming || !currentUser) return
    claiming = true
    claimResult = null
    try {
      const res = await window.claimNodeReward(currentUser, uptimeHours)
      claimResult = res
      await loadNodeStatus()
    } catch (e) {
      console.error('claimNodeReward failed:', e)
    }
    claiming = false
  }
</script>

<div class="node-panel" {dir}>
  <div class="panel-header">
    <div class="flex items-center gap-3">
      <h2>🖥️ {t('nodePanel', lang)}</h2>
      {#if nodeStatus}
        <span class="px-2.5 py-0.5 rounded-full text-[11px] font-bold border {nodeStatus.sync_status === 'synced' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' : 'bg-amber-500/10 text-amber-400 border-amber-500/30'}">
          {nodeStatus.sync_status === 'synced' ? t('statusSynced', lang) : t('statusStandalone', lang)}
        </span>
      {/if}
    </div>
    <button 
      type="button" 
      class="btn-sync {syncingP2P ? 'syncing' : ''}" 
      on:click={syncNow} 
      disabled={syncingP2P}
      title={t('syncNow', lang)}
    >
      <span class={syncingP2P ? 'animate-spin' : ''}>🔄</span>
      <span>{syncingP2P ? t('syncing', lang) : t('syncNow', lang)}</span>
    </button>
  </div>

  {#if syncFeedback}
    <div class="sync-feedback-banner {syncFeedback.status === 'success' ? 'success' : 'error'}">
      {#if syncFeedback.status === 'success'}
        <span>✓ {t('syncSuccess', lang)} (+{syncFeedback.synced_posts || 0} منشور، +{syncFeedback.synced_blocks || 0} كتلة، {syncFeedback.connected || 0} نود متصل)</span>
      {:else}
        <span>⚠️ {syncFeedback.error || 'فشلت المزامنة، تحقق من تشغيل نود الأقران'}</span>
      {/if}
    </div>
  {/if}

  {#if loading}
    <div class="panel-loading">
      <div class="spinner"></div>
    </div>
  {:else if nodeStatus}
    <!-- Stats grid -->
    <div class="stats-grid">
      <div class="stat-card">
        <span class="stat-icon">⛓️</span>
        <span class="stat-value">{nodeStatus.blocks ?? 0}</span>
        <span class="stat-label">{t('blocksCount', lang)}</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon">👥</span>
        <span class="stat-value">{nodeStatus.users ?? 0}</span>
        <span class="stat-label">{t('usersCount', lang)}</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon">📝</span>
        <span class="stat-value">{nodeStatus.posts ?? 0}</span>
        <span class="stat-label">{t('postsCount', lang)}</span>
      </div>
      <div class="stat-card">
        <span class="stat-icon">🌐</span>
        <span class="stat-value">{nodeStatus.peers_count ?? peers.length}</span>
        <span class="stat-label">{t('connectedPeers', lang)}</span>
      </div>
    </div>

    <!-- P2P Gossip Network Management Block -->
    <div class="p2p-block">
      <div class="p2p-header">
        <div>
          <h3>🌐 {t('p2pNetwork', lang)}</h3>
          <p class="text-xs text-zinc-400 mt-0.5">
            {t('p2pPort', lang)}: <strong class="text-indigo-400 font-mono">http://127.0.0.1:{nodeStatus.p2p_port || 8545}</strong>
          </p>
        </div>
        <button 
          type="button" 
          class="btn-secondary text-xs py-1.5 px-3"
          on:click={loadPeers}
        >
          🔄 تحديث
        </button>
      </div>

      <!-- Add Peer Form -->
      <div class="p-3 mb-2 rounded-xl bg-indigo-950/30 border border-indigo-500/20 text-xs text-indigo-300 flex items-start gap-2">
        <span class="text-base">💡</span>
        <div class="leading-relaxed">
          {lang === 'ar' 
            ? 'لربط الهاتف بحاسوبك، شغّل (ring node.ring 8545) على الكمبيوتر، ثم اكتب عنوان الـ IP المحلي لحاسوبك هنا (مثال: http://192.168.1.15:8545).'
            : 'To sync phone with your PC, run (ring node.ring 8545) on PC, then enter your PC\'s LAN IP here (e.g. http://192.168.1.15:8545).'}
        </div>
      </div>

      <div class="add-peer-box">
        <input 
          type="text" 
          bind:value={newPeerUrl} 
          placeholder={t('peerPlaceholder', lang)} 
          class="peer-input font-mono"
          on:keydown={(e) => e.key === 'Enter' && addPeer()}
        />
        <button 
          type="button" 
          class="btn-add-peer" 
          on:click={addPeer}
          disabled={addingPeer || !newPeerUrl.trim()}
        >
          {addingPeer ? '...' : '+ ' + t('addPeer', lang)}
        </button>
      </div>

      <!-- Peers List -->
      <div class="peers-list">
        {#if peers.length === 0}
          <div class="p-4 text-center text-xs text-zinc-500 bg-zinc-950/40 rounded-xl border border-zinc-800/60">
            {t('noPeers', lang)}
          </div>
        {:else}
          {#each peers as peer}
            <div class="peer-row">
              <div class="flex items-center gap-2 min-w-0">
                <span class="w-2 h-2 rounded-full {peer.status === 'active' ? 'bg-emerald-400 shadow-sm shadow-emerald-400/50' : 'bg-zinc-600'}"></span>
                <span class="font-mono text-xs text-zinc-200 truncate">{peer.url}</span>
                {#if peer.last_seen}
                  <span class="text-[10px] text-zinc-500 hidden sm:inline font-mono">({peer.last_seen})</span>
                {/if}
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span class="text-[10px] font-bold px-2 py-0.5 rounded-full {peer.status === 'active' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-zinc-800 text-zinc-400'}">
                  {peer.status === 'active' ? '🟢 متصل' : '⚪ غير متاح'}
                </span>
                <button 
                  type="button" 
                  class="text-zinc-500 hover:text-rose-400 text-xs p-1 transition"
                  on:click={() => removePeer(peer.url)}
                  title="حذف النظير"
                >
                  ✕
                </button>
              </div>
            </div>
          {/each}
        {/if}
      </div>
    </div>

    <!-- Node info -->
    <div class="node-info-block">
      <div class="info-row">
        <span class="info-label">{t('networkName', lang)}</span>
        <span class="info-value network-badge">{nodeStatus.network ?? 'Mejde'}</span>
      </div>
      <div class="info-row">
        <span class="info-label">{t('nodeVersion', lang)}</span>
        <span class="info-value">{nodeStatus.version ?? '1.0.0'}</span>
      </div>
      <div class="info-row">
        <span class="info-label">{t('syncStatus', lang)}</span>
        <span class="info-value sync-ok">✓ {nodeStatus.sync_status ?? 'local'}</span>
      </div>
      {#if nodeStatus.last_sync}
        <div class="info-row">
          <span class="info-label">آخر مزامنة ناجحة</span>
          <span class="info-value text-xs font-mono text-indigo-300">{nodeStatus.last_sync}</span>
        </div>
      {/if}
      {#if nodeStatus.node_id}
        <div class="info-row">
          <span class="info-label">{t('nodeId', lang)}</span>
          <span class="info-value node-id-val">{nodeStatus.node_id}</span>
        </div>
      {/if}
    </div>

    <!-- Claim node reward -->
    <div class="reward-block">
      <h3>🎁 {t('claimNodeReward', lang)}</h3>
      <div class="uptime-input">
        <label for="uptime-hours">{lang === 'ar' ? 'ساعات التشغيل المؤكدة' : 'Verified Uptime Hours'}</label>
        <input
          id="uptime-hours"
          type="number"
          min="1"
          max="24"
          bind:value={uptimeHours}
          class="hours-input"
        />
      </div>
      <button class="btn-claim {claiming ? 'loading' : ''}" on:click={claimReward} disabled={claiming || !currentUser}>
        {claiming ? t('claiming', lang) : '⚡ ' + t('claimNodeReward', lang)}
      </button>

      {#if claimResult}
        <div class="claim-result {claimResult.claimed ? 'success' : 'error'}">
          {#if claimResult.claimed}
            ✅ {lang === 'ar' ? `تم الاستلام! ${claimResult.hours} WALA ← عقدة نشطة` : `Claimed! ${claimResult.hours} WALA ← Active Node`}
          {:else}
            ❌ {lang === 'ar' ? 'فشل الاستلام، تحقق من رصيد مكافآت الشبكة' : 'Claim failed. Check network reward pool.'}
          {/if}
        </div>
      {/if}
    </div>

    <!-- Deployment hints -->
    <div class="deployment-block">
      <h3>🚀 {lang === 'ar' ? 'تشغيل أكثر من نود محلياً' : 'Run Multiple Nodes Locally'}</h3>
      <p class="deploy-note">
        {lang === 'ar' 
          ? 'يمكنك تشغيل نود إضافي على نفس الجهاز باختيار منفذ وقاعدة بيانات مخصصة ثم إضافة المنفذ في خانة الأقران بالأعلى:' 
          : 'You can run a secondary node on the same device with a custom port and database, then connect them via the peers input above:'}
      </p>
      <div class="code-block">
        <pre><code># Node 1 (Default: Port 8545)
ring app.ring

# Node 2 (Port 8546 + social_2.db)
ring app.ring 8546 social_2.db</code></pre>
      </div>
    </div>
  {/if}
</div>

<style>
  .node-panel {
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding: 16px;
    max-width: 600px;
    margin: 0 auto;
  }
  .panel-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 10px;
    border-bottom: 1px solid rgba(255,255,255,0.07);
    padding-bottom: 14px;
  }
  .panel-header h2 { margin: 0; font-size: 1.25rem; font-weight: 800; color: #e2e8f0; }

  .btn-sync {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 7px 14px;
    border-radius: 12px;
    background: linear-gradient(135deg, #6366f1, #a855f7);
    color: white;
    font-size: 0.82rem;
    font-weight: 700;
    border: none;
    cursor: pointer;
    transition: opacity 0.2s, transform 0.1s;
    box-shadow: 0 4px 12px rgba(99,102,241,0.25);
  }
  .btn-sync:hover:not(:disabled) { opacity: 0.9; }
  .btn-sync:active:not(:disabled) { transform: scale(0.97); }
  .btn-sync:disabled { opacity: 0.6; cursor: not-allowed; }

  .sync-feedback-banner {
    padding: 10px 16px;
    border-radius: 12px;
    font-size: 0.82rem;
    font-weight: 600;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .sync-feedback-banner.success {
    background: rgba(74,222,128,0.1);
    border: 1px solid rgba(74,222,128,0.25);
    color: #4ade80;
  }
  .sync-feedback-banner.error {
    background: rgba(239,68,68,0.1);
    border: 1px solid rgba(239,68,68,0.25);
    color: #f87171;
  }

  .panel-loading {
    display: flex; justify-content: center; align-items: center;
    height: 180px;
  }
  .spinner {
    width: 32px; height: 32px;
    border: 3px solid rgba(96,165,250,0.2);
    border-top-color: #60a5fa;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* Stats grid */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }
  @media (min-width: 480px) {
    .stats-grid { grid-template-columns: repeat(4, 1fr); }
  }
  .stat-card {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 14px;
    padding: 16px 12px;
    display: flex; flex-direction: column; align-items: center; gap: 6px;
    transition: border-color 0.2s, background 0.2s;
  }
  .stat-card:hover {
    border-color: rgba(96,165,250,0.4);
    background: rgba(96,165,250,0.06);
  }
  .stat-icon { font-size: 1.5rem; }
  .stat-value {
    font-size: 1.6rem; font-weight: 800;
    background: linear-gradient(135deg, #60a5fa, #818cf8);
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  }
  .stat-label { font-size: 0.75rem; color: rgba(148,163,184,0.7); text-align: center; }

  /* P2P Gossip Block */
  .p2p-block {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(129,140,248,0.2);
    border-radius: 14px;
    padding: 18px;
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .p2p-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .p2p-header h3 { margin: 0; font-size: 1rem; color: #818cf8; font-weight: 700; }

  .add-peer-box {
    display: flex;
    gap: 8px;
  }
  .peer-input {
    flex: 1;
    background: rgba(0,0,0,0.4);
    border: 1px solid rgba(255,255,255,0.12);
    border-radius: 10px;
    color: #e2e8f0;
    padding: 8px 12px;
    font-size: 0.82rem;
    outline: none;
    transition: border-color 0.2s;
  }
  .peer-input:focus { border-color: #818cf8; }
  .btn-add-peer {
    background: #4f46e5;
    color: white;
    border: none;
    border-radius: 10px;
    padding: 8px 16px;
    font-size: 0.82rem;
    font-weight: 700;
    cursor: pointer;
    transition: opacity 0.2s;
    white-space: nowrap;
  }
  .btn-add-peer:hover:not(:disabled) { opacity: 0.9; }
  .btn-add-peer:disabled { opacity: 0.5; cursor: not-allowed; }

  .peers-list {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .peer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    padding: 8px 12px;
    background: rgba(0,0,0,0.3);
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 10px;
  }

  /* Node info */
  .node-info-block {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 14px;
    padding: 16px 20px;
    display: flex; flex-direction: column; gap: 10px;
  }
  .info-row { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 6px; }
  .info-label { font-size: 0.82rem; color: rgba(148,163,184,0.6); }
  .info-value { font-size: 0.88rem; font-weight: 600; color: #e2e8f0; }
  .network-badge {
    background: rgba(96,165,250,0.15);
    border: 1px solid rgba(96,165,250,0.3);
    color: #60a5fa; padding: 3px 10px; border-radius: 20px; font-size: 0.8rem;
  }
  .sync-ok { color: #4ade80; }
  .node-id-val { font-size: 0.78rem; font-family: monospace; color: rgba(148,163,184,0.7); word-break: break-all; }

  /* Reward block */
  .reward-block {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(129,140,248,0.2);
    border-radius: 14px;
    padding: 20px;
    display: flex; flex-direction: column; gap: 14px;
  }
  .reward-block h3 { margin: 0; font-size: 1rem; color: #818cf8; }

  .uptime-input { display: flex; flex-direction: column; gap: 6px; }
  .uptime-input label { font-size: 0.85rem; color: rgba(148,163,184,0.7); }
  .hours-input {
    width: 120px;
    background: rgba(255,255,255,0.06);
    border: 1px solid rgba(129,140,248,0.3);
    border-radius: 8px; color: #e2e8f0;
    font-size: 1rem; padding: 8px 12px; outline: none;
  }
  .hours-input:focus { border-color: #818cf8; }

  .btn-claim {
    background: linear-gradient(135deg, #60a5fa, #818cf8);
    border: none; border-radius: 12px;
    color: white; font-size: 0.95rem; font-weight: 600;
    padding: 12px 24px; cursor: pointer; align-self: flex-start;
    transition: opacity 0.2s, transform 0.1s;
  }
  .btn-claim:hover:not(:disabled) { opacity: 0.85; }
  .btn-claim:active:not(:disabled) { transform: scale(0.97); }
  .btn-claim:disabled { opacity: 0.4; cursor: not-allowed; }
  .btn-claim.loading { animation: pulse 0.8s infinite; }
  @keyframes pulse { 0%,100% { opacity: 0.7; } 50% { opacity: 1; } }

  .claim-result {
    padding: 10px 14px; border-radius: 10px;
    font-size: 0.88rem; font-weight: 500;
  }
  .claim-result.success { background: rgba(74,222,128,0.1); border: 1px solid rgba(74,222,128,0.25); color: #4ade80; }
  .claim-result.error { background: rgba(239,68,68,0.1); border: 1px solid rgba(239,68,68,0.2); color: #f87171; }

  /* Deployment */
  .deployment-block {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 14px;
    padding: 20px;
    display: flex; flex-direction: column; gap: 12px;
  }
  .deployment-block h3 { margin: 0; font-size: 1rem; color: #e2e8f0; }
  .code-block {
    background: rgba(0,0,0,0.4);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 10px; padding: 12px 16px;
  }
  .code-block pre { margin: 0; }
  .code-block code { font-size: 0.82rem; color: #93c5fd; font-family: 'JetBrains Mono', 'Fira Code', monospace; }
  .deploy-note { margin: 0; font-size: 0.82rem; color: rgba(148,163,184,0.6); line-height: 1.5; }
</style>
