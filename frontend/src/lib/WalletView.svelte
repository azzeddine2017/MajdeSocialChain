<script>
  import { onMount, createEventDispatcher } from 'svelte'
  import { currentLang, t } from './i18n.js'
  import BuyWalaModal from './BuyWalaModal.svelte'
  const dispatch = createEventDispatcher()
  export let balance = 0

  let recipient = ''
  let amount = ''
  let txMsg = ''
  let isSending = false
  let isClaiming = false
  let showBuyModal = false
  let transactions = []
  let activeTab = 'overview' // 'overview' | 'send' | 'staking'

  // Staking & Quota state
  let stakedBalance = 0
  let dailyQuota = 25
  let quotaBoost = 0
  let totalPool = 0
  let stakeInput = ''
  let unstakeInput = ''
  let isStaking = false
  let isUnstaking = false
  let stakingMsg = ''

  let isMotherNode = true
  let nodePort = 8545
  let motherUrl = 'http://127.0.0.1:8545'
  let hideMockFaucet = false
  let isRefilling = false
  let refillMsg = ''
  let showMotherConfig = false

  onMount(() => {
    try {
      hideMockFaucet = localStorage.getItem('mejde_hide_mock_faucet') === '1'
    } catch (e) {}
    loadNodeStatus()
    loadTransactions()
    loadStakeInfo()
  })

  async function loadNodeStatus() {
    try {
      if (window.getNodeStatus) {
        let res = await window.getNodeStatus('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res) {
          isMotherNode = !!res.is_mother_node
          nodePort = res.p2p_port || 8545
          motherUrl = res.mother_url || 'http://127.0.0.1:8545'
        }
      }
    } catch (e) {}
  }

  function toggleMockFaucet() {
    hideMockFaucet = !hideMockFaucet
    try {
      localStorage.setItem('mejde_hide_mock_faucet', hideMockFaucet ? '1' : '0')
    } catch (e) {}
  }

  async function refillFromMother() {
    if (isRefilling) return
    isRefilling = true
    refillMsg = t('refilling', $currentLang)
    try {
      if (window.requestMotherRefill) {
        let res = await window.requestMotherRefill(motherUrl, 'me', 50)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.success) {
          refillMsg = t('refillSuccess', $currentLang)
          dispatch('balanceChanged')
          await loadTransactions()
          await loadStakeInfo()
          setTimeout(() => refillMsg = '', 4500)
        } else {
          refillMsg = (res && res.error) || t('refillError', $currentLang)
          setTimeout(() => refillMsg = '', 5000)
        }
      }
    } catch (e) {
      refillMsg = t('refillError', $currentLang)
      setTimeout(() => refillMsg = '', 5000)
    } finally {
      isRefilling = false
    }
  }

  async function loadStakeInfo() {
    try {
      if (window.getStakeInfo) {
        let res = await window.getStakeInfo('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res) {
          stakedBalance = Number(res.staked || 0)
          dailyQuota = Number(res.daily_quota || 25)
          quotaBoost = Number(res.boost || 0)
          totalPool = Number(res.total_pool || 0)
        }
      }
    } catch (e) {
      console.error('Error loading stake info:', e)
    }
  }

  async function loadTransactions() {
    try {
      if (window.getTransactions) {
        let res = await window.getTransactions('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (Array.isArray(res)) {
          transactions = res.map(item => {
            if (Array.isArray(item) && item.length > 0 && Array.isArray(item[0])) {
              const obj = {}
              item.forEach(pair => { if (Array.isArray(pair)) obj[pair[0]] = pair[1] })
              return obj
            }
            return item
          })
        }
      }
    } catch (e) {
      console.error('Error loading transactions:', e)
    }
  }

  async function sendCoins() {
    const target = recipient.trim()
    const val = Number(amount)
    if (!target || !val || val <= 0 || isSending) return
    isSending = true
    txMsg = 'جاري التوقيع والتأكيد على البلوكتشين...'
    try {
      if (window.createTransaction) {
        await window.createTransaction('me', target, val)
        txMsg = 'تم إرسال وتأكيد المعاملة بنجاح! 🚀'
        recipient = ''
        amount = ''
        dispatch('balanceChanged')
        await loadTransactions()
        setTimeout(() => txMsg = '', 3500)
      }
    } catch (e) {
      txMsg = 'خطأ: ' + (e.message || e)
    } finally {
      isSending = false
    }
  }

  async function claimFaucet() {
    if (isClaiming) return
    isClaiming = true
    try {
      if (window.faucet) {
        await window.faucet('me', 50)
        dispatch('balanceChanged')
        await loadTransactions()
        await loadStakeInfo()
      }
    } catch (e) {
      console.error('Faucet error:', e)
    } finally {
      isClaiming = false
    }
  }

  async function executeStake() {
    const val = Number(stakeInput)
    if (!val || val <= 0 || isStaking) return
    if (val > balance) {
      stakingMsg = 'رصيد WALA المتاح غير كافٍ للرهن!'
      return
    }
    isStaking = true
    stakingMsg = 'جاري التوقيع وتنفيذ عقد الرهن...'
    try {
      if (window.stakeWala) {
        await window.stakeWala('me', val)
        stakingMsg = t('stakeSuccess', $currentLang)
        stakeInput = ''
        dispatch('balanceChanged')
        await loadStakeInfo()
        await loadTransactions()
        setTimeout(() => stakingMsg = '', 4000)
      }
    } catch (e) {
      stakingMsg = 'خطأ: ' + (e.message || e)
    } finally {
      isStaking = false
    }
  }

  async function executeUnstake() {
    const val = Number(unstakeInput)
    if (!val || val <= 0 || isUnstaking) return
    if (val > stakedBalance) {
      stakingMsg = 'الكمية المطلوبة أكبر من رصيدك المرهون!'
      return
    }
    isUnstaking = true
    stakingMsg = 'جاري التوقيع وفك رهن العملات...'
    try {
      if (window.unstakeWala) {
        await window.unstakeWala('me', val)
        stakingMsg = t('unstakeSuccess', $currentLang)
        unstakeInput = ''
        dispatch('balanceChanged')
        await loadStakeInfo()
        await loadTransactions()
        setTimeout(() => stakingMsg = '', 4000)
      }
    } catch (e) {
      stakingMsg = 'خطأ: ' + (e.message || e)
    } finally {
      isUnstaking = false
    }
  }
</script>

<div class="p-3 space-y-4 max-w-[560px] mx-auto pb-10">
  <!-- Metallic Web3 Card -->
  <div class="metallic-card p-6 rounded-3xl text-start relative overflow-hidden border border-zinc-700/60 shadow-2xl">
    <!-- Top Card Bar -->
    <div class="flex items-center justify-between relative z-10 mb-6">
      <div class="flex items-center gap-2">
        <span class="w-7 h-7 rounded-lg bg-indigo-500/20 border border-indigo-500/40 flex items-center justify-center text-xs font-bold text-indigo-300">WALA</span>
        <span class="text-xs font-bold tracking-wider text-zinc-300 uppercase">{t('tokenName', $currentLang)}</span>
      </div>
      <!-- Contactless Chip Icon -->
      <div class="w-9 h-7 rounded-md bg-gradient-to-r from-amber-400 to-amber-600 flex items-center justify-center text-[10px] text-zinc-950 font-black shadow-inner">
        CHIP
      </div>
    </div>

    <!-- Balance Section -->
    <div class="relative z-10 mb-5">
      <div class="flex items-center justify-between">
        <div class="text-xs text-zinc-400 font-medium mb-1">{t('availableBalance', $currentLang)}</div>
        <button 
          type="button" 
          on:click={() => showBuyModal = true}
          class="px-3 py-1 rounded-xl bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-zinc-950 font-black text-xs transition active:scale-95 shadow-md flex items-center gap-1 cursor-pointer"
        >
          <span>⚡</span>
          <span>{t('buyWala', $currentLang)}</span>
        </button>
      </div>
      <div class="text-4xl font-black text-white tracking-tight flex items-baseline gap-2">
        <span>{Number(balance).toLocaleString()}</span>
        <span class="text-lg font-bold gradient-gold-text">WALA</span>
      </div>
      
      <!-- Sub-unit Ikhlas Equivalent -->
      <div class="mt-2.5 flex items-center gap-2">
        <span class="px-2.5 py-0.5 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-[11px] font-mono text-emerald-400 font-bold">
          ≈ {Number(balance * 1000000).toLocaleString()} {t('ikhlasUnit', $currentLang)}
        </span>
        <span class="text-[10px] text-zinc-400 font-mono">1 WALA = 10⁶ IKH</span>
      </div>
    </div>

    <!-- Card Bottom Row -->
    <div class="flex items-center justify-between relative z-10 pt-3 border-t border-white/10 text-xs">
      <div class="text-zinc-400 font-mono text-[11px]">
        <span>عقد الولاء: </span>
        <span class="text-zinc-200">Mejde-WalaCoin</span>
      </div>
      <div class="flex items-center gap-1.5 text-emerald-400 font-mono text-[11px]">
        <span class="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
        <span>{t('networkLive', $currentLang)}</span>
      </div>
    </div>
  </div>

  <!-- Node Status Banner -->
  <div class="flex items-center justify-between px-3 py-2 rounded-2xl {isMotherNode ? 'bg-amber-500/10 border border-amber-500/30 text-amber-300' : 'bg-indigo-500/10 border border-indigo-500/30 text-indigo-300'} text-xs font-mono">
    <div class="flex items-center gap-2">
      <span class="w-2 h-2 rounded-full {isMotherNode ? 'bg-amber-400 animate-ping' : 'bg-indigo-400 animate-pulse'}"></span>
      <span class="font-bold">{isMotherNode ? '🌟 ' + t('motherNodeTitle', $currentLang) + ' (Genesis :8545)' : '🛰️ ' + t('peerNodeTitle', $currentLang) + ' (Port :' + nodePort + ')'}</span>
    </div>
    <button 
      type="button"
      on:click={() => showMotherConfig = !showMotherConfig}
      class="text-[11px] underline hover:opacity-80 transition cursor-pointer"
    >
      {showMotherConfig ? 'إغلاق ✕' : 'إدارة التعبئة ⚙️'}
    </button>
  </div>

  <!-- Mother Node Config & Circulation Drawer -->
  {#if showMotherConfig}
    <div class="card p-4 rounded-2xl border border-zinc-800 bg-zinc-950/90 space-y-3.5 text-xs text-start">
      <div class="flex items-center justify-between border-b border-zinc-800/80 pb-2">
        <span class="font-bold text-zinc-200 flex items-center gap-1.5">
          <span>⚡</span>
          <span>{t('circulationTitle', $currentLang)}</span>
        </span>
        <button 
          type="button" 
          on:click={toggleMockFaucet}
          class="text-[10px] px-2.5 py-1 rounded-lg border {hideMockFaucet ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400' : 'bg-zinc-800 border-zinc-700 text-zinc-300'}"
        >
          {hideMockFaucet ? t('showMockFaucet', $currentLang) : t('hideMockFaucet', $currentLang)}
        </button>
      </div>

      <p class="text-zinc-400 text-[11px] leading-relaxed">
        {t('circulationDesc', $currentLang)}
      </p>

      {#if !isMotherNode}
        <div class="space-y-2 pt-1 border-t border-zinc-800/60">
          <label for="mother-url-input" class="block text-[11px] text-zinc-400 font-bold">{t('motherUrlLabel', $currentLang)}</label>
          <div class="flex gap-2">
            <input 
              id="mother-url-input"
              type="text" 
              bind:value={motherUrl} 
              placeholder="http://127.0.0.1:8545" 
              class="input-field text-left font-mono text-xs flex-1 py-1.5"
            />
            <button 
              type="button" 
              on:click={refillFromMother}
              disabled={isRefilling}
              class="btn-primary px-3 py-1.5 text-xs font-bold whitespace-nowrap"
            >
              {isRefilling ? t('refilling', $currentLang) : t('motherNodeRefill', $currentLang)}
            </button>
          </div>
        </div>
      {/if}

      {#if refillMsg}
        <div class="p-2.5 rounded-xl text-center text-xs font-medium {refillMsg.includes('نجاح') || refillMsg.includes('Success') ? 'bg-emerald-950/70 border border-emerald-500/40 text-emerald-300' : 'bg-rose-950/70 border border-rose-500/40 text-rose-300'}">
          {refillMsg}
        </div>
      {/if}
    </div>
  {/if}

  <!-- Quick Action Grid (4 Columns) -->
  <div class="grid grid-cols-4 gap-2">
    <!-- 1. Buy WALA -->
    <button 
      type="button"
      on:click={() => showBuyModal = true}
      class="p-2.5 sm:p-3 rounded-2xl bg-gradient-to-tr from-amber-500/20 via-amber-500/10 to-transparent hover:bg-amber-500/25 border border-amber-500/40 text-center transition active:scale-95 flex flex-col items-center gap-1 shadow-sm cursor-pointer"
    >
      <span class="text-xl sm:text-2xl">⚡</span>
      <span class="text-[11px] sm:text-xs font-black text-amber-300 truncate">{t('buyWala', $currentLang)}</span>
    </button>

    <!-- 2. Faucet / Refill -->
    {#if isMotherNode || !hideMockFaucet}
      <button 
        type="button"
        on:click={claimFaucet}
        disabled={isClaiming}
        class="p-2.5 sm:p-3 rounded-2xl bg-zinc-900/90 hover:bg-zinc-850 border border-zinc-800 text-center transition active:scale-95 flex flex-col items-center gap-1 shadow-sm"
      >
        <span class="text-xl sm:text-2xl">🚰</span>
        <span class="text-[11px] sm:text-xs font-bold text-zinc-200 truncate">{isClaiming ? t('claiming', $currentLang) : t('claimFaucet', $currentLang)}</span>
      </button>
    {:else}
      <button 
        type="button"
        on:click={refillFromMother}
        disabled={isRefilling}
        class="p-2.5 sm:p-3 rounded-2xl bg-indigo-950/40 hover:bg-indigo-900/50 border border-indigo-500/40 text-center transition active:scale-95 flex flex-col items-center gap-1 shadow-sm"
      >
        <span class="text-xl sm:text-2xl">⚡</span>
        <span class="text-[11px] sm:text-xs font-bold text-indigo-200 truncate">{isRefilling ? t('refilling', $currentLang) : t('motherNodeRefill', $currentLang)}</span>
      </button>
    {/if}

    <!-- 3. Send Coins -->
    <button 
      type="button"
      on:click={() => activeTab = 'send'}
      class="p-2.5 sm:p-3 rounded-2xl bg-zinc-900/90 hover:bg-zinc-850 border border-zinc-800 text-center transition active:scale-95 flex flex-col items-center gap-1 shadow-sm {activeTab === 'send' ? 'ring-2 ring-indigo-500' : ''}"
    >
      <span class="text-xl sm:text-2xl">💸</span>
      <span class="text-[11px] sm:text-xs font-bold text-zinc-200 truncate">{t('sendCoins', $currentLang)}</span>
    </button>

    <!-- 4. Staking -->
    <button 
      type="button"
      on:click={() => activeTab = 'staking'}
      class="p-2.5 sm:p-3 rounded-2xl bg-zinc-900/90 hover:bg-zinc-850 border border-zinc-800 text-center transition active:scale-95 flex flex-col items-center gap-1 shadow-sm {activeTab === 'staking' ? 'ring-2 ring-indigo-500' : ''}"
    >
      <span class="text-xl sm:text-2xl">🛡️</span>
      <span class="text-[11px] sm:text-xs font-bold text-zinc-200 truncate">{t('tabStaking', $currentLang)}</span>
    </button>
  </div>

  <!-- Tab Selector: Overview, Send, Staking -->
  <div class="flex rounded-2xl bg-zinc-900 p-1 border border-zinc-800 text-xs font-bold">
    <button 
      type="button"
      on:click={() => activeTab = 'overview'}
      class="flex-1 py-2.5 rounded-xl transition {activeTab === 'overview' ? 'bg-indigo-600 text-white shadow' : 'text-zinc-400 hover:text-white'}"
    >
      {t('txHistory', $currentLang)} ({transactions.length})
    </button>
    <button 
      type="button"
      on:click={() => activeTab = 'send'}
      class="flex-1 py-2.5 rounded-xl transition {activeTab === 'send' ? 'bg-indigo-600 text-white shadow' : 'text-zinc-400 hover:text-white'}"
    >
      {t('sendCoins', $currentLang)}
    </button>
    <button 
      type="button"
      on:click={() => { activeTab = 'staking'; loadStakeInfo(); }}
      class="flex-1 py-2.5 rounded-xl transition {activeTab === 'staking' ? 'bg-indigo-600 text-white shadow' : 'text-zinc-400 hover:text-white'}"
    >
      {t('tabStaking', $currentLang)}
    </button>
  </div>

  <!-- Staking Card -->
  {#if activeTab === 'staking'}
    <div class="card p-5 border border-zinc-800/90 space-y-4 shadow-xl text-start">
      <div class="flex items-center justify-between border-b border-zinc-800/80 pb-3">
        <h3 class="font-bold text-sm text-zinc-100 flex items-center gap-2">
          <span>🛡️</span>
          <span>{t('tabStaking', $currentLang)}</span>
        </h3>
        <span class="text-[10px] font-mono bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 px-2 py-0.5 rounded-full">Anti-Bot Engine</span>
      </div>

      <!-- Explanation banner -->
      <div class="p-3 rounded-xl bg-zinc-950/70 border border-zinc-800 text-xs text-zinc-400 leading-relaxed">
        💡 {t('stakingDesc', $currentLang)}
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-2 gap-3">
        <div class="p-3 rounded-2xl bg-zinc-900/80 border border-zinc-800">
          <div class="text-[11px] text-zinc-400 font-medium mb-1">{t('stakedBalance', $currentLang)}</div>
          <div class="text-xl font-black text-amber-400 font-mono">
            {stakedBalance} <span class="text-xs text-zinc-400">WALA</span>
          </div>
        </div>

        <div class="p-3 rounded-2xl bg-zinc-900/80 border border-zinc-800">
          <div class="text-[11px] text-zinc-400 font-medium mb-1">{t('currentQuota', $currentLang)}</div>
          <div class="text-xl font-black text-emerald-400 font-mono flex items-baseline gap-1">
            <span>{dailyQuota}</span>
            <span class="text-[10px] text-zinc-400">{t('postsPerDay', $currentLang)}</span>
            {#if quotaBoost > 0}
              <span class="text-[10px] text-indigo-400 font-bold">(+{quotaBoost})</span>
            {/if}
          </div>
        </div>
      </div>

      <!-- Stake Form -->
      <div class="pt-2 border-t border-zinc-800/60 space-y-3">
        <label for="stake-input" class="block text-xs text-zinc-300 font-bold">{t('stakeWala', $currentLang)}</label>
        <div class="flex gap-2">
          <input 
            id="stake-input"
            type="number" 
            bind:value={stakeInput} 
            placeholder="10" 
            class="input-field text-left font-mono font-bold flex-1"
          />
          <button 
            type="button"
            on:click={executeStake}
            disabled={isStaking || !stakeInput || Number(stakeInput) <= 0}
            class="btn-primary px-5 py-2 text-xs font-bold whitespace-nowrap"
          >
            {#if isStaking}
              <span class="animate-spin text-xs">⏳</span>
            {:else}
              <span>{t('stakeBtn', $currentLang)}</span>
            {/if}
          </button>
        </div>
      </div>

      <!-- Unstake Form (if user has staked coins) -->
      {#if stakedBalance > 0}
        <div class="pt-3 border-t border-zinc-800/60 space-y-3">
          <label for="unstake-input" class="block text-xs text-zinc-300 font-bold">{t('unstakeWala', $currentLang)}</label>
          <div class="flex gap-2">
            <input 
              id="unstake-input"
              type="number" 
              bind:value={unstakeInput} 
              placeholder={String(stakedBalance)} 
              class="input-field text-left font-mono font-bold flex-1"
            />
            <button 
              type="button"
              on:click={executeUnstake}
              disabled={isUnstaking || !unstakeInput || Number(unstakeInput) <= 0}
              class="px-5 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-zinc-200 border border-zinc-700 text-xs font-bold whitespace-nowrap transition active:scale-95"
            >
              {#if isUnstaking}
                <span class="animate-spin text-xs">⏳</span>
              {:else}
                <span>{t('unstakeBtn', $currentLang)}</span>
              {/if}
            </button>
          </div>
        </div>
      {/if}

      {#if stakingMsg}
        <div class="p-3 rounded-xl text-xs text-center bg-indigo-950/60 border border-indigo-500/40 text-indigo-300 font-medium">
          {stakingMsg}
        </div>
      {/if}
    </div>

  <!-- Send Form Card -->
  {:else if activeTab === 'send'}
    <div class="card p-5 border border-zinc-800/90 space-y-4 shadow-xl text-start">
      <div class="flex items-center justify-between border-b border-zinc-800/80 pb-3">
        <h3 class="font-bold text-sm text-zinc-100 flex items-center gap-2">
          <span>⚡</span>
          <span>{t('sendCoins', $currentLang)}</span>
        </h3>
        <span class="text-[10px] font-mono bg-zinc-800 text-zinc-400 px-2 py-0.5 rounded-full">{t('feeZero', $currentLang)}</span>
      </div>

      <div>
        <label for="recipient-input" class="block text-xs text-zinc-400 mb-1.5 font-medium">{t('recipientAddress', $currentLang)}</label>
        <input 
          id="recipient-input"
          bind:value={recipient} 
          placeholder="user_xxxxxx" 
          class="input-field text-left font-mono"
        />
      </div>

      <div>
        <label for="amount-input" class="block text-xs text-zinc-400 mb-1.5 font-medium">{t('amountToSend', $currentLang)}</label>
        <div class="relative">
          <input 
            id="amount-input"
            type="number" 
            bind:value={amount} 
            placeholder="0.00" 
            class="input-field pl-16 text-left font-mono font-bold text-base"
          />
          <span class="absolute left-4 top-3 text-xs text-zinc-400 font-bold">WALA</span>
        </div>
      </div>

      <button 
        type="button"
        on:click={sendCoins} 
        disabled={isSending || !recipient || !amount}
        class="btn-primary w-full py-3 text-sm font-bold shadow-lg"
      >
        {#if isSending}
          <span class="animate-spin text-xs">⏳</span>
          <span>جاري التأكيد...</span>
        {:else}
          <span>{t('signAndSend', $currentLang)}</span>
        {/if}
      </button>

      {#if txMsg}
        <div class="p-3 rounded-xl text-xs text-center bg-indigo-950/60 border border-indigo-500/40 text-indigo-300 font-medium">
          {txMsg}
        </div>
      {/if}
    </div>
  {:else}
    <!-- Transaction History -->
    <div class="space-y-2">
      {#each transactions as tx}
        <div class="card p-3.5 border border-zinc-800/80 flex items-center justify-between text-xs hover:border-zinc-700 transition">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-2xl flex items-center justify-center font-bold text-base {tx.receiver_id === 'me' || tx.sender_id === 'GENESIS_FAUCET' ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-rose-500/10 text-rose-400 border border-rose-500/20'}">
              {tx.receiver_id === 'me' || tx.sender_id === 'GENESIS_FAUCET' ? '↙' : '↗'}
            </div>
            <div>
              <div class="font-bold text-zinc-200">
                {tx.sender_id === 'GENESIS_FAUCET' ? t('faucetSource', $currentLang) : (tx.receiver_id === 'me' ? `@${tx.sender_id}` : `@${tx.receiver_id}`)}
              </div>
              <div class="text-[10px] text-zinc-500 font-mono">{tx.created_at || 'Confirmed'}</div>
            </div>
          </div>

          <div class="text-left font-mono">
            <div class="font-black text-sm {tx.receiver_id === 'me' || tx.sender_id === 'GENESIS_FAUCET' ? 'text-emerald-400' : 'text-rose-400'}">
              {tx.receiver_id === 'me' || tx.sender_id === 'GENESIS_FAUCET' ? '+' : '-'}{tx.amount} WALA
            </div>
            <span class="text-[9px] text-emerald-400 font-mono">{t('txConfirmed', $currentLang)}</span>
          </div>
        </div>
      {:else}
        <div class="card p-10 text-center text-zinc-500 text-xs border border-zinc-800">
          <div class="text-3xl mb-2">📜</div>
          <p class="font-bold text-zinc-400">{t('noTxs', $currentLang)}</p>
          <p class="text-[11px] text-zinc-500 mt-1">{t('claimFaucet', $currentLang)}</p>
        </div>
      {/each}
    </div>
  {/if}

  <!-- Buy WALA Modal -->
  <BuyWalaModal 
    open={showBuyModal} 
    onClose={() => showBuyModal = false} 
    on:purchased={() => { dispatch('balanceChanged'); loadTransactions(); }} 
  />
</div>
