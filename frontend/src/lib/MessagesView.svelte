<script>
  import { onMount, onDestroy, afterUpdate } from 'svelte'
  import { currentLang, t } from './i18n.js'

  export let currentUser = ''

  let conversations = []
  let activeConvo = null // partner_id
  let messages = []
  let messageText = ''
  let sending = false
  let loadingConvos = false
  let loadingMsgs = false
  let newRecipient = ''
  let showNewConvo = false
  let msgContainer
  let convoPoll = null

  // Search & Filter state
  let searchQuery = ''
  let activeFilter = 'all' // 'all' | 'unread'

  // In-chat Tip Modal
  let showTipModal = false
  let tipAmount = 10
  let isSendingTip = false
  let tipFeedback = ''

  const quickEmojis = ['👍', '❤️', '🔥', '🚀', '💎', '👏']

  $: lang = $currentLang
  $: dir = lang === 'ar' ? 'rtl' : 'ltr'
  $: if (currentUser) {
    loadConversations()
  }

  $: filteredConvos = conversations.filter(c => {
    const q = searchQuery.toLowerCase().trim()
    const nameMatch = !q || (c.name || '').toLowerCase().includes(q) || (c.partner_id || '').toLowerCase().includes(q)
    const filterMatch = activeFilter === 'all' || (activeFilter === 'unread' && Number(c.unread) > 0)
    return nameMatch && filterMatch
  })

  $: activeConvoObj = conversations.find(c => c.partner_id === activeConvo) || { partner_id: activeConvo, name: activeConvo }

  onMount(() => {
    loadConversations()
  })

  onDestroy(() => {
    stopConvoPolling()
  })

  function startConvoPolling() {
    stopConvoPolling()
    convoPoll = setInterval(async () => {
      if (activeConvo && !sending) {
        try {
          const res = await window.getMessages(activeConvo)
          if (Array.isArray(res)) {
            if (res.length !== messages.length) {
              messages = res
            }
          }
        } catch (_) {}
      }
    }, 3500)
  }

  function stopConvoPolling() {
    if (convoPoll) {
      clearInterval(convoPoll)
      convoPoll = null
    }
  }

  afterUpdate(() => {
    if (msgContainer) {
      msgContainer.scrollTop = msgContainer.scrollHeight
    }
  })

  async function loadConversations() {
    loadingConvos = true
    try {
      const res = await window.getConversations()
      conversations = Array.isArray(res) ? res : []
    } catch (e) {
      console.error('getConversations failed:', e)
      conversations = []
    }
    loadingConvos = false
  }

  async function openConversation(partnerId) {
    activeConvo = partnerId
    loadingMsgs = true
    messages = []
    stopConvoPolling()
    try {
      const res = await window.getMessages(partnerId)
      messages = Array.isArray(res) ? res : []
      startConvoPolling()
    } catch (e) {
      console.error('getMessages failed:', e)
      messages = []
    }
    loadingMsgs = false
    loadConversations()
  }

  function closeConversation() {
    activeConvo = null
    messages = []
    stopConvoPolling()
  }

  async function sendMessage(textToSend = null) {
    const text = (textToSend || messageText).trim()
    if (!text || !activeConvo || sending) return
    sending = true
    if (!textToSend) messageText = ''
    try {
      await window.sendMessage(activeConvo, text)
      messages = [...messages, {
        sender_id: currentUser,
        receiver_id: activeConvo,
        content: text,
        is_read: 1,
        created_at: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }]
      loadConversations()
    } catch (e) {
      console.error('sendMessage failed:', e)
      if (!textToSend) messageText = text
    }
    sending = false
  }

  async function sendInChatTip() {
    if (!activeConvo || tipAmount <= 0 || isSendingTip) return
    isSendingTip = true
    tipFeedback = 'جاري التوقيع والتحويل على البلوكتشين...'
    try {
      if (window.createTransaction) {
        await window.createTransaction('me', activeConvo, Number(tipAmount))
        const tipMsg = `💰 أرسلت لك إكرامية بقيمة ${tipAmount} WALA!`
        await sendMessage(tipMsg)
        tipFeedback = 'تم إرسال الإكرامية بنجاح! 🚀'
        setTimeout(() => {
          showTipModal = false
          tipFeedback = ''
        }, 1500)
      }
    } catch (e) {
      tipFeedback = 'خطأ: ' + (e.message || e)
    } finally {
      isSendingTip = false
    }
  }

  async function startNewConversation() {
    if (!newRecipient.trim()) return
    const id = newRecipient.trim()
    newRecipient = ''
    showNewConvo = false
    await openConversation(id)
  }

  function handleKeydown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendMessage()
    }
  }

  function getAvatar(convo) {
    if (convo?.avatar && (convo.avatar.startsWith('data:') || convo.avatar.startsWith('http://') || convo.avatar.startsWith('https://'))) {
      return convo.avatar
    }
    const name = convo?.name || convo?.partner_id || '?'
    return `https://api.dicebear.com/7.x/identicon/svg?seed=${encodeURIComponent(name)}`
  }

  function formatTime(ts) {
    if (!ts) return ''
    try {
      const d = new Date(ts)
      if (isNaN(d.getTime())) return ts
      return d.toLocaleTimeString(lang === 'ar' ? 'ar-SA' : 'en-US', { hour: '2-digit', minute: '2-digit' })
    } catch { return ts }
  }
</script>

<div class="messages-shell" {dir}>
  <!-- Sidebar Panel: List of Conversations -->
  <aside class="convos-panel {activeConvo ? 'hidden-on-mobile' : ''}">
    <!-- Header -->
    <div class="convos-header">
      <div class="flex items-center gap-2">
        <span class="text-xl">💬</span>
        <h2 class="text-base font-black text-white tracking-wide">{t('messages', lang)}</h2>
      </div>
      <button 
        type="button" 
        class="w-8 h-8 rounded-xl bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 border border-indigo-500/30 flex items-center justify-center transition active:scale-95 cursor-pointer text-sm shadow-sm"
        on:click={() => (showNewConvo = !showNewConvo)} 
        title={t('newConversation', lang)}
      >
        ✏️
      </button>
    </div>

    <!-- Search & Filter Bar -->
    <div class="p-3 border-b border-zinc-800/80 space-y-2.5 bg-zinc-950/40">
      <div class="relative">
        <span class="absolute inset-y-0 start-3 flex items-center text-zinc-500 text-xs pointer-events-none">🔍</span>
        <input 
          type="text" 
          bind:value={searchQuery} 
          placeholder={t('searchChat', lang)}
          class="w-full bg-zinc-900/90 border border-zinc-800 focus:border-indigo-500/50 rounded-xl py-2 ps-9 pe-3 text-xs text-zinc-200 outline-none transition"
        />
        {#if searchQuery}
          <button 
            type="button" 
            on:click={() => searchQuery = ''}
            class="absolute inset-y-0 end-2.5 flex items-center text-zinc-500 hover:text-zinc-300 text-xs"
          >
            ✕
          </button>
        {/if}
      </div>

      <!-- Filter tabs -->
      <div class="flex gap-1.5 text-[11px] font-bold">
        <button 
          type="button" 
          on:click={() => activeFilter = 'all'}
          class="px-3 py-1 rounded-lg transition {activeFilter === 'all' ? 'bg-indigo-600 text-white shadow' : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200'}"
        >
          {t('allChats', lang)} ({conversations.length})
        </button>
        <button 
          type="button" 
          on:click={() => activeFilter = 'unread'}
          class="px-3 py-1 rounded-lg transition {activeFilter === 'unread' ? 'bg-indigo-600 text-white shadow' : 'bg-zinc-900 text-zinc-400 hover:text-zinc-200'}"
        >
          {t('unreadChats', lang)}
        </button>
      </div>
    </div>

    <!-- New Conversation Input Drawer -->
    {#if showNewConvo}
      <div class="p-3 border-b border-indigo-500/30 bg-indigo-950/20 space-y-2 animate-fadeIn">
        <label for="new-convo-input" class="block text-[11px] font-bold text-indigo-300">{t('recipientId', lang)}</label>
        <div class="flex gap-2">
          <input
            id="new-convo-input"
            type="text"
            bind:value={newRecipient}
            placeholder="user_xxxxxx"
            on:keydown={(e) => e.key === 'Enter' && startNewConversation()}
            class="input-field text-left font-mono text-xs flex-1 py-1.5"
          />
          <button 
            type="button"
            class="btn-primary px-3 py-1.5 text-xs font-bold whitespace-nowrap" 
            on:click={startNewConversation}
          >
            بدء 💬
          </button>
        </div>
      </div>
    {/if}

    <!-- Conversation Cards List -->
    <div class="convos-scroll-container">
      {#if loadingConvos}
        <div class="flex items-center justify-center p-8 text-zinc-500 gap-2 text-xs">
          <span class="animate-spin text-base">⏳</span>
          <span>جاري تحميل المحادثات...</span>
        </div>
      {:else if filteredConvos.length === 0}
        <div class="empty-state">
          <div class="text-3xl mb-2">💬</div>
          <p class="font-bold text-zinc-400 text-xs">{t('noConversations', lang)}</p>
          <button 
            type="button"
            on:click={() => showNewConvo = true}
            class="mt-3 text-[11px] text-indigo-400 hover:underline font-bold"
          >
            + {t('newConversation', lang)}
          </button>
        </div>
      {:else}
        <ul class="space-y-1 p-2">
          {#each filteredConvos as convo}
            <li>
              <button
                type="button"
                class="convo-card {activeConvo === convo.partner_id ? 'active' : ''}"
                on:click={() => openConversation(convo.partner_id)}
              >
                <!-- Avatar with Online Beacon -->
                <div class="relative shrink-0">
                  <img src={getAvatar(convo)} alt={convo.name} class="w-11 h-11 rounded-2xl object-cover bg-zinc-800 border border-zinc-700/80 shadow-sm" />
                  <span class="absolute -bottom-0.5 -end-0.5 w-3 h-3 rounded-full bg-emerald-500 border-2 border-zinc-950"></span>
                </div>

                <!-- Info -->
                <div class="flex-1 min-w-0 text-start">
                  <div class="flex items-center justify-between mb-0.5">
                    <span class="font-bold text-xs text-zinc-100 truncate">{convo.name || convo.partner_id}</span>
                    <span class="text-[10px] text-zinc-500 font-mono">{formatTime(convo.last_time)}</span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-[11px] text-zinc-400 truncate max-w-[150px]">
                      {convo.last_message || 'محادثة مشفرة E2EE'}
                    </span>
                    {#if Number(convo.unread) > 0}
                      <span class="unread-pill">{convo.unread}</span>
                    {/if}
                  </div>
                </div>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
    </div>
  </aside>

  <!-- Main Chat Panel -->
  <main class="chat-panel {!activeConvo ? 'hidden-on-mobile' : ''}">
    {#if !activeConvo}
      <!-- Empty State / No Conversation Selected -->
      <div class="no-chat-container">
        <div class="w-20 h-20 rounded-3xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-4xl mb-3 shadow-inner">
          🔐
        </div>
        <h3 class="text-base font-bold text-zinc-200 mb-1">{t('e2eEncrypted', lang)}</h3>
        <p class="text-xs text-zinc-500 max-w-sm leading-relaxed mb-4">
          جميع الرسائل مشفرة محلياً بواسطة مفاتيح RSA-2048 و AES-CBC. لا يمكن لأي نود أو متلصص فك تشفيرها.
        </p>
        <button 
          type="button" 
          on:click={() => showNewConvo = true}
          class="btn-primary px-5 py-2.5 text-xs font-bold shadow-lg"
        >
          + {t('newConversation', lang)}
        </button>
      </div>
    {:else}
      <!-- Active Chat Header -->
      <div class="chat-header">
        <div class="flex items-center gap-3">
          <!-- Back button on Mobile -->
          <button 
            type="button" 
            on:click={closeConversation}
            class="md:hidden w-8 h-8 rounded-xl bg-zinc-800 text-zinc-300 flex items-center justify-center text-sm font-bold"
            title={t('backToChats', lang)}
          >
            {dir === 'rtl' ? '→' : '←'}
          </button>

          <div class="relative shrink-0">
            <img src={getAvatar(activeConvoObj)} alt={activeConvoObj.name} class="w-10 h-10 rounded-2xl object-cover bg-zinc-800 border border-zinc-700 shadow-sm" />
            <span class="absolute -bottom-0.5 -end-0.5 w-2.5 h-2.5 rounded-full bg-emerald-500 border-2 border-zinc-950 animate-pulse"></span>
          </div>

          <div class="text-start">
            <div class="font-bold text-sm text-zinc-100 flex items-center gap-2">
              <span>{activeConvoObj.name || activeConvo}</span>
            </div>
            <div class="flex items-center gap-1.5 text-[10px] text-emerald-400 font-mono">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-400"></span>
              <span>{t('onlineStatus', lang)}</span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <!-- Direct Tip Button -->
          <button 
            type="button"
            on:click={() => showTipModal = true}
            class="px-3 py-1.5 rounded-xl bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-bold flex items-center gap-1.5 transition active:scale-95 shadow-sm cursor-pointer"
            title={t('tipUserTitle', lang)}
          >
            <span>💰</span>
            <span class="hidden sm:inline">{t('sendWalaTip', lang)}</span>
          </button>

          <!-- Security Badge -->
          <div class="px-2.5 py-1 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-[11px] text-indigo-300 font-mono hidden sm:flex items-center gap-1">
            <span>🛡️</span>
            <span>RSA-2048</span>
          </div>
        </div>
      </div>

      <!-- Quick Tip Modal Popup -->
      {#if showTipModal}
        <div class="p-4 border-b border-amber-500/30 bg-amber-950/20 animate-fadeIn space-y-3">
          <div class="flex items-center justify-between">
            <span class="font-bold text-xs text-amber-300 flex items-center gap-1.5">
              <span>💰</span>
              <span>إرسال إكرامية WALA فورية إلى @{activeConvo}</span>
            </span>
            <button type="button" on:click={() => showTipModal = false} class="text-zinc-400 hover:text-white text-xs">✕</button>
          </div>

          <div class="flex items-center gap-2">
            {#each [5, 10, 25, 50] as amt}
              <button 
                type="button" 
                on:click={() => tipAmount = amt}
                class="px-3 py-1 rounded-lg text-xs font-mono font-bold transition {tipAmount === amt ? 'bg-amber-500 text-zinc-950 font-black' : 'bg-zinc-800 text-zinc-300'}"
              >
                +{amt}
              </button>
            {/each}
            <input 
              type="number" 
              bind:value={tipAmount} 
              class="w-20 input-field text-center font-mono font-bold text-xs py-1"
            />
            <button 
              type="button" 
              on:click={sendInChatTip}
              disabled={isSendingTip || tipAmount <= 0}
              class="btn-primary bg-gradient-to-r from-amber-500 to-amber-600 text-zinc-950 font-black px-4 py-1 text-xs whitespace-nowrap"
            >
              {isSendingTip ? 'جاري التحويل...' : 'تأكيد الإرسال ⚡'}
            </button>
          </div>

          {#if tipFeedback}
            <div class="text-[11px] text-amber-300 font-medium">{tipFeedback}</div>
          {/if}
        </div>
      {/if}

      <!-- Message Bubbles Container -->
      <div class="messages-container" bind:this={msgContainer}>
        {#if loadingMsgs}
          <div class="flex items-center justify-center p-12 text-zinc-500 gap-2 text-xs">
            <span class="animate-spin text-base">⏳</span>
            <span>جاري فك تشفير الرسائل...</span>
          </div>
        {:else if messages.length === 0}
          <div class="empty-msgs">
            <span class="text-2xl mb-1">👋</span>
            <span class="font-bold text-zinc-400">{t('noMessages', lang)}</span>
            <span class="text-[11px] text-zinc-500">ابدأ المحادثة المشفرة بكلمة طيبة!</span>
          </div>
        {:else}
          <!-- Day divider -->
          <div class="flex justify-center my-2">
            <span class="text-[10px] font-bold text-zinc-500 bg-zinc-900/80 border border-zinc-800 px-3 py-0.5 rounded-full">
              {t('today', lang)}
            </span>
          </div>

          {#each messages as msg}
            <div class="msg-row {msg.sender_id === currentUser ? 'outgoing-row' : 'incoming-row'} flex items-end gap-2">
              {#if msg.sender_id !== currentUser}
                {#if msg.sender_avatar && (msg.sender_avatar.startsWith('data:') || msg.sender_avatar.startsWith('http'))}
                  <img src={msg.sender_avatar} alt="avatar" class="w-7 h-7 rounded-full object-cover shrink-0 border border-zinc-700 shadow-sm mb-1" />
                {:else}
                  <div class="w-7 h-7 rounded-full bg-gradient-to-tr from-indigo-600 via-purple-600 to-pink-500 flex items-center justify-center text-[10px] font-black text-white shrink-0 mb-1 shadow-sm">
                    {(msg.sender_id || '?').slice(0, 2).toUpperCase()}
                  </div>
                {/if}
              {/if}
              <div class="msg-bubble {msg.sender_id === currentUser ? 'outgoing-bubble' : 'incoming-bubble'} {msg.content && msg.content.includes('💰') ? 'tip-bubble' : ''}">
                <div class="msg-content">
                  {#if msg.content && msg.content.includes('💰')}
                    <div class="flex items-center gap-1.5 font-bold text-amber-300 text-xs mb-1">
                      <span>💎</span>
                      <span>معاملة على السلسلة</span>
                    </div>
                  {/if}
                  <span>{msg.content}</span>
                </div>

                <div class="msg-meta">
                  <span class="msg-time">{formatTime(msg.created_at)}</span>
                  {#if msg.sender_id === currentUser}
                    <span class="msg-status">{msg.is_read ? '✓✓' : '✓'}</span>
                  {/if}
                </div>
              </div>
            </div>
          {/each}
        {/if}
      </div>

      <!-- Quick Reactions Bar -->
      <div class="px-4 py-1.5 bg-zinc-950/60 border-t border-zinc-800/60 flex items-center gap-1.5 overflow-x-auto text-xs">
        <span class="text-[10px] text-zinc-500 font-bold shrink-0">{t('quickReactions', lang)}:</span>
        {#each quickEmojis as em}
          <button 
            type="button" 
            on:click={() => sendMessage(em)}
            class="px-2 py-0.5 rounded-lg bg-zinc-900 hover:bg-zinc-800 hover:scale-110 transition active:scale-95 cursor-pointer text-sm"
          >
            {em}
          </button>
        {/each}
      </div>

      <!-- Input Area -->
      <div class="message-input-bar">
        <button 
          type="button"
          on:click={() => showTipModal = !showTipModal}
          class="w-10 h-10 rounded-2xl bg-zinc-900 hover:bg-zinc-800 text-amber-400 border border-zinc-800 flex items-center justify-center text-lg transition active:scale-95 shrink-0"
          title="إرسال WALA 💰"
        >
          💰
        </button>

        <textarea
          bind:value={messageText}
          placeholder={t('typeMessage', lang)}
          on:keydown={handleKeydown}
          rows="1"
          class="msg-input"
          disabled={sending}
        ></textarea>

        <button 
          type="button"
          class="btn-send {sending ? 'sending' : ''}" 
          on:click={() => sendMessage()} 
          disabled={!messageText.trim() || sending}
        >
          {#if sending}
            <span class="animate-spin text-sm">⏳</span>
          {:else}
            <span class="text-base font-bold">{dir === 'rtl' ? '◀' : '▶'}</span>
          {/if}
        </button>
      </div>
    {/if}
  </main>
</div>

<style>
  .messages-shell {
    display: flex;
    height: calc(100vh - 120px);
    min-height: 480px;
    border-radius: 24px;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(18, 18, 28, 0.7);
    backdrop-filter: blur(16px);
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
  }

  /* Sidebar */
  .convos-panel {
    width: 310px;
    min-width: 260px;
    border-right: 1px solid rgba(255, 255, 255, 0.07);
    display: flex;
    flex-direction: column;
    background: rgba(10, 10, 16, 0.6);
  }
  :global([dir="rtl"]) .convos-panel {
    border-right: none;
    border-left: 1px solid rgba(255, 255, 255, 0.07);
  }

  .convos-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 16px 12px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }

  .convos-scroll-container {
    flex: 1;
    overflow-y: auto;
  }

  .convo-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    border-radius: 16px;
    width: 100%;
    border: 1px solid transparent;
    background: transparent;
    font-family: inherit;
  }
  .convo-card:hover {
    background: rgba(255, 255, 255, 0.04);
  }
  .convo-card.active {
    background: rgba(99, 102, 241, 0.12);
    border-color: rgba(99, 102, 241, 0.25);
  }

  .unread-pill {
    background: #6366f1;
    color: white;
    font-size: 0.65rem;
    font-weight: 800;
    border-radius: 9999px;
    padding: 1px 7px;
    box-shadow: 0 0 10px rgba(99, 102, 241, 0.5);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
    text-align: center;
  }

  /* Chat Panel */
  .chat-panel {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-width: 0;
    background: rgba(8, 8, 14, 0.8);
  }

  .no-chat-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 30px;
    text-align: center;
  }

  .chat-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 18px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    background: rgba(15, 15, 22, 0.5);
  }

  .messages-container {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .empty-msgs {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
  }

  .msg-row {
    display: flex;
    width: 100%;
  }
  .outgoing-row {
    justify-content: flex-end;
  }
  .incoming-row {
    justify-content: flex-start;
  }

  .msg-bubble {
    max-width: 75%;
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px 14px;
    border-radius: 20px;
    animation: fadeInBubble 0.2s ease-out;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
  }
  @keyframes fadeInBubble {
    from { opacity: 0; transform: translateY(4px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .outgoing-bubble {
    background: linear-gradient(135deg, #4f46e5, #7c3aed);
    color: white;
    border-bottom-right-radius: 4px;
  }
  :global([dir="rtl"]) .outgoing-bubble {
    border-bottom-right-radius: 20px;
    border-bottom-left-radius: 4px;
  }

  .incoming-bubble {
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
    color: #f1f5f9;
    border-bottom-left-radius: 4px;
  }
  :global([dir="rtl"]) .incoming-bubble {
    border-bottom-left-radius: 20px;
    border-bottom-right-radius: 4px;
  }

  .tip-bubble {
    border: 1px solid rgba(245, 158, 11, 0.4);
    box-shadow: 0 0 15px rgba(245, 158, 11, 0.15);
  }

  .msg-content {
    font-size: 0.88rem;
    line-height: 1.5;
    word-break: break-word;
  }

  .msg-meta {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 0.68rem;
    opacity: 0.7;
    margin-top: 2px;
  }
  .outgoing-bubble .msg-meta {
    align-self: flex-end;
  }
  .incoming-bubble .msg-meta {
    align-self: flex-start;
  }
  .msg-status {
    color: #cbd5e1;
    font-weight: 700;
  }

  .message-input-bar {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 14px;
    border-top: 1px solid rgba(255, 255, 255, 0.06);
    background: rgba(10, 10, 16, 0.8);
  }

  .msg-input {
    flex: 1;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 16px;
    color: #e2e8f0;
    font-size: 0.88rem;
    padding: 10px 14px;
    resize: none;
    outline: none;
    font-family: inherit;
    max-height: 100px;
    transition: all 0.2s;
  }
  .msg-input:focus {
    border-color: rgba(99, 102, 241, 0.5);
    background: rgba(255, 255, 255, 0.07);
  }

  .btn-send {
    background: linear-gradient(135deg, #4f46e5, #7c3aed);
    border: none;
    border-radius: 16px;
    color: white;
    width: 42px;
    height: 42px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s;
    box-shadow: 0 4px 12px rgba(79, 70, 229, 0.3);
    flex-shrink: 0;
  }
  .btn-send:hover:not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 6px 16px rgba(79, 70, 229, 0.4);
  }
  .btn-send:active:not(:disabled) {
    transform: scale(0.95);
  }
  .btn-send:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* Responsive styling */
  @media (max-width: 768px) {
    .messages-shell {
      height: calc(100vh - 80px);
      border-radius: 0;
      border: none;
    }
    .hidden-on-mobile {
      display: none !important;
    }
    .convos-panel {
      width: 100%;
      border: none;
    }
  }
</style>
