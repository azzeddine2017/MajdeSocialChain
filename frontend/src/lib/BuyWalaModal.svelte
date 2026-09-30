<script>
  import { onMount, createEventDispatcher } from 'svelte'
  import { currentLang, t } from './i18n.js'

  export let open = false
  export let onClose = () => {}

  const dispatch = createEventDispatcher()

  let activeTab = 'usdt' // 'usdt' | 'p2p' | 'converter'
  
  // USDT On-Ramp State
  let usdtAmount = 25
  let selectedNetwork = 'TRC20'
  let isBuyingCrypto = false
  let cryptoBuySuccess = ''
  let cryptoBuyError = ''
  const treasuryAddress = 'TFzK8N9h2bQ6YpX7aM3cV5wD1eE4rT9uMe'

  // P2P Escrow State
  let p2pOffers = []
  let loadingP2P = false
  let buyingOfferId = null
  let p2pFeedback = ''
  let showCreateOffer = false
  let newOfferWala = 50
  let newOfferPrice = 1200
  let newOfferCurr = 'DZD'
  let newOfferMethod = 'بريدي موب (BaridiMob)'
  let isCreatingOffer = false

  // Converter State
  let convWala = 1
  let convIkhlas = 1000000

  $: lang = $currentLang
  $: dir = lang === 'ar' ? 'rtl' : 'ltr'
  $: calculatedWala = usdtAmount * 10
  $: calculatedIkhlas = calculatedWala * 1000000

  $: if (open) {
    cryptoBuySuccess = ''
    cryptoBuyError = ''
    p2pFeedback = ''
    if (activeTab === 'p2p') {
      loadP2POffers()
    }
  }

  function handleWalaInput(val) {
    convWala = val
    convIkhlas = Number(val || 0) * 1000000
  }

  function handleIkhlasInput(val) {
    convIkhlas = val
    convWala = Number(val || 0) / 1000000
  }

  async function handleBuyCrypto() {
    if (usdtAmount <= 0 || isBuyingCrypto) return
    isBuyingCrypto = true
    cryptoBuyError = ''
    cryptoBuySuccess = ''
    try {
      if (window.buyWalaWithCrypto) {
        let res = await window.buyWalaWithCrypto('me', Number(usdtAmount), selectedNetwork)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.success) {
          cryptoBuySuccess = `تم استلام ${res.wala_amount} WALA (${Number(res.ikhlas_amount).toLocaleString()} إخلاص) بنجاح! 🚀`
          dispatch('purchased')
          setTimeout(() => {
            cryptoBuySuccess = ''
          }, 6000)
        } else {
          cryptoBuyError = (res && res.error) || 'فشلت المعاملة'
        }
      }
    } catch (e) {
      cryptoBuyError = e.message || 'خطأ في معالجة الشراء'
    } finally {
      isBuyingCrypto = false
    }
  }

  async function loadP2POffers() {
    loadingP2P = true
    p2pFeedback = ''
    try {
      if (window.getP2POffers) {
        let res = await window.getP2POffers()
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        p2pOffers = Array.isArray(res) ? res : []
      }
    } catch (e) {
      console.error('loadP2POffers error:', e)
      p2pOffers = []
    } finally {
      loadingP2P = false
    }
  }

  async function handleP2PBuy(offer) {
    if (buyingOfferId) return
    buyingOfferId = offer.id
    p2pFeedback = 'جاري حجز وتحرير الضمان الذكي...'
    try {
      if (window.executeP2PBuy) {
        let res = await window.executeP2PBuy('me', offer.id)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.success) {
          p2pFeedback = `✓ تم الشراء بنجاح! استلمت ${res.wala_amount} WALA من @${res.seller_id}`
          dispatch('purchased')
          await loadP2POffers()
          setTimeout(() => p2pFeedback = '', 6000)
        } else {
          p2pFeedback = 'خطأ: ' + ((res && res.error) || 'تعذر إتمام الشراء')
        }
      }
    } catch (e) {
      p2pFeedback = 'خطأ: ' + (e.message || e)
    } finally {
      buyingOfferId = null
    }
  }

  async function handleCreateOffer() {
    if (newOfferWala <= 0 || newOfferPrice <= 0 || isCreatingOffer) return
    isCreatingOffer = true
    p2pFeedback = 'جاري نشر العرض في دفتر الضمان...'
    try {
      if (window.createP2POffer) {
        let res = await window.createP2POffer('me', Number(newOfferWala), Number(newOfferPrice), newOfferCurr, newOfferMethod)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.id) {
          p2pFeedback = '✓ تم إنشاء عرض البيع بنجاح!'
          showCreateOffer = false
          await loadP2POffers()
          setTimeout(() => p2pFeedback = '', 4000)
        } else {
          p2pFeedback = 'خطأ: ' + ((res && res.error) || 'فشل إنشاء العرض')
        }
      }
    } catch (e) {
      p2pFeedback = 'خطأ: ' + (e.message || e)
    } finally {
      isCreatingOffer = false
    }
  }

  function copyTreasury() {
    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(treasuryAddress).catch(() => {})
    }
    cryptoBuySuccess = 'تم نسخ عنوان الخزينة إلى الحافظة! 📋'
    setTimeout(() => cryptoBuySuccess = '', 2500)
  }
</script>

{#if open}
  <!-- Backdrop -->
  <div class="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-3 sm:p-4" {dir} on:click|self={onClose} role="presentation">
    <!-- Modal Card -->
    <div class="w-full max-w-lg bg-zinc-950 border border-zinc-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] animate-in fade-in zoom-in-95 duration-200">
      
      <!-- Header -->
      <div class="p-4 sm:p-5 border-b border-zinc-800/80 flex items-center justify-between bg-zinc-900/60">
        <div class="flex items-center gap-2.5">
          <div class="w-9 h-9 rounded-2xl bg-gradient-to-tr from-amber-500 to-amber-600 flex items-center justify-center text-lg font-black text-zinc-950 shadow-md">
            ⚡
          </div>
          <div class="text-start">
            <h2 class="text-base font-black text-white">{t('buyWala', lang)}</h2>
            <div class="text-[11px] text-amber-400 font-mono">{t('ikhlasRate', lang)}</div>
          </div>
        </div>
        <button 
          type="button" 
          on:click={onClose} 
          class="w-8 h-8 rounded-xl bg-zinc-800 text-zinc-400 hover:text-white flex items-center justify-center transition active:scale-90"
        >
          ✕
        </button>
      </div>

      <!-- Navigation Tabs -->
      <div class="flex p-2 gap-1.5 border-b border-zinc-800/80 bg-zinc-900/30 text-xs font-bold">
        <button 
          type="button" 
          on:click={() => activeTab = 'usdt'}
          class="flex-1 py-2 rounded-xl transition flex items-center justify-center gap-1.5 {activeTab === 'usdt' ? 'bg-amber-500 text-zinc-950 font-black shadow-sm' : 'text-zinc-400 hover:text-zinc-200'}"
        >
          <span>💵</span>
          <span>شراء بـ USDT</span>
        </button>
        <button 
          type="button" 
          on:click={() => { activeTab = 'p2p'; loadP2POffers(); }}
          class="flex-1 py-2 rounded-xl transition flex items-center justify-center gap-1.5 {activeTab === 'p2p' ? 'bg-indigo-600 text-white shadow-sm' : 'text-zinc-400 hover:text-zinc-200'}"
        >
          <span>🛡️</span>
          <span>سوق P2P Escrow</span>
        </button>
        <button 
          type="button" 
          on:click={() => activeTab = 'converter'}
          class="flex-1 py-2 rounded-xl transition flex items-center justify-center gap-1.5 {activeTab === 'converter' ? 'bg-purple-600 text-white shadow-sm' : 'text-zinc-400 hover:text-zinc-200'}"
        >
          <span>🔄</span>
          <span>محول الإخلاص</span>
        </button>
      </div>

      <!-- Body -->
      <div class="p-4 sm:p-5 overflow-y-auto space-y-4 text-start">
        
        <!-- TAB 1: Direct USDT On-Ramp -->
        {#if activeTab === 'usdt'}
          <div class="space-y-4">
            <!-- Rate Banner -->
            <div class="p-3.5 rounded-2xl bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-transparent border border-amber-500/30 flex items-center justify-between text-xs">
              <span class="text-zinc-300 font-medium">سعر الصرف الرسمي المعتمد:</span>
              <span class="font-black text-amber-300 font-mono text-sm">1 USDT = 10 WALA</span>
            </div>

            <!-- Preset Amount Buttons -->
            <div>
              <span class="block text-xs font-bold text-zinc-300 mb-2">اختر باقة الشراء (USDT):</span>
              <div class="grid grid-cols-4 gap-2">
                {#each [10, 25, 50, 100] as amt}
                  <button 
                    type="button" 
                    on:click={() => usdtAmount = amt}
                    class="py-2.5 rounded-xl border font-mono font-bold text-xs transition active:scale-95 {usdtAmount === amt ? 'bg-amber-500/20 border-amber-500 text-amber-300 font-black' : 'bg-zinc-900 border-zinc-800 text-zinc-400 hover:text-zinc-200'}"
                  >
                    ${amt}
                  </button>
                {/each}
              </div>
            </div>

            <!-- Custom Amount & Calculation Box -->
            <div class="p-4 rounded-2xl bg-zinc-900/80 border border-zinc-800 space-y-3">
              <div class="flex items-center justify-between text-xs">
                <span class="text-zinc-400">المبلغ المدفوع (USDT):</span>
                <input 
                  type="number" 
                  bind:value={usdtAmount} 
                  min="1" 
                  class="w-24 text-end bg-zinc-950 border border-zinc-700 rounded-lg px-2 py-1 text-white font-mono font-bold text-xs" 
                />
              </div>

              <div class="flex items-center justify-between text-xs border-t border-zinc-800/80 pt-2.5">
                <span class="text-zinc-400">ستحصل على (ولاء):</span>
                <span class="text-base font-black text-amber-300 font-mono">+{Number(calculatedWala).toLocaleString()} WALA</span>
              </div>

              <div class="flex items-center justify-between text-[11px] text-zinc-500 border-t border-zinc-800/40 pt-1.5 font-mono">
                <span>المعادل بوحدة الإخلاص:</span>
                <span class="text-emerald-400">+{Number(calculatedIkhlas).toLocaleString()} IKH</span>
              </div>
            </div>

            <!-- Network Selection & Treasury Info -->
            <div class="space-y-2">
              <div class="flex items-center justify-between text-xs">
                <span class="font-bold text-zinc-300">الشبكة المستخدمة:</span>
                <div class="flex gap-1.5">
                  <button 
                    type="button" 
                    on:click={() => selectedNetwork = 'TRC20'}
                    class="px-2.5 py-1 rounded-lg text-xs font-mono font-bold border {selectedNetwork === 'TRC20' ? 'bg-amber-500/20 border-amber-500 text-amber-300' : 'bg-zinc-900 border-zinc-800 text-zinc-500'}"
                  >
                    Tron (TRC-20)
                  </button>
                  <button 
                    type="button" 
                    on:click={() => selectedNetwork = 'POLYGON'}
                    class="px-2.5 py-1 rounded-lg text-xs font-mono font-bold border {selectedNetwork === 'POLYGON' ? 'bg-purple-500/20 border-purple-500 text-purple-300' : 'bg-zinc-900 border-zinc-800 text-zinc-500'}"
                  >
                    Polygon (MATIC)
                  </button>
                </div>
              </div>

              <!-- Treasury Address Card -->
              <div class="p-3 rounded-xl bg-zinc-950 border border-zinc-800 flex items-center justify-between gap-2 text-xs">
                <div class="min-w-0 flex-1">
                  <div class="text-[10px] text-zinc-500 mb-0.5">عنوان محفظة الخزينة (Treasury Vault):</div>
                  <div class="font-mono text-zinc-300 text-[11px] truncate">{treasuryAddress}</div>
                </div>
                <button 
                  type="button" 
                  on:click={copyTreasury}
                  class="px-2.5 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-300 text-xs font-bold shrink-0 transition"
                  title="نسخ العنوان"
                >
                  نسخ 📋
                </button>
              </div>
            </div>

            <!-- Confirm Buy Button -->
            <button 
              type="button" 
              on:click={handleBuyCrypto}
              disabled={isBuyingCrypto || usdtAmount <= 0}
              class="w-full py-3 rounded-2xl bg-gradient-to-r from-amber-500 via-amber-600 to-amber-700 text-zinc-950 font-black text-sm shadow-lg shadow-amber-500/20 hover:brightness-110 active:scale-[0.98] transition cursor-pointer"
            >
              {isBuyingCrypto ? 'جاري التحقق وشحن المحفظة...' : `تأكيد الشراء واستلام ${Number(calculatedWala).toLocaleString()} WALA ⚡`}
            </button>

            {#if cryptoBuySuccess}
              <div class="p-3 rounded-xl bg-emerald-950/70 border border-emerald-500/40 text-emerald-300 text-xs text-center font-bold animate-pulse">
                {cryptoBuySuccess}
              </div>
            {/if}

            {#if cryptoBuyError}
              <div class="p-3 rounded-xl bg-rose-950/70 border border-rose-500/40 text-rose-300 text-xs text-center font-bold">
                {cryptoBuyError}
              </div>
            {/if}
          </div>

        <!-- TAB 2: P2P Escrow Market -->
        {:else if activeTab === 'p2p'}
          <div class="space-y-3.5">
            <!-- Escrow Notice -->
            <div class="p-3 rounded-xl bg-indigo-500/10 border border-indigo-500/30 text-xs text-indigo-300 flex items-center justify-between">
              <span class="leading-relaxed">🛡️ جميع العملات مجمدة في عقد الضمان الذكي حتى تأكيد استلام التحويل.</span>
              <button 
                type="button" 
                on:click={() => showCreateOffer = !showCreateOffer}
                class="px-2.5 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shrink-0 transition"
              >
                {showCreateOffer ? 'إلغاء' : '+ بيع WALA'}
              </button>
            </div>

            <!-- Create Offer Form -->
            {#if showCreateOffer}
              <div class="p-4 rounded-2xl bg-zinc-900 border border-zinc-700 space-y-3 text-xs">
                <div class="font-bold text-white mb-1">إنشاء عرض بيع جديد بنظام الضمان:</div>
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <span class="block text-zinc-400 text-[11px] mb-1">الكمية المعروضة (WALA):</span>
                    <input type="number" bind:value={newOfferWala} min="1" class="input-field text-xs py-1" />
                  </div>
                  <div>
                    <span class="block text-zinc-400 text-[11px] mb-1">السعر الإجمالي:</span>
                    <input type="number" bind:value={newOfferPrice} min="1" class="input-field text-xs py-1" />
                  </div>
                </div>
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <span class="block text-zinc-400 text-[11px] mb-1">العملة:</span>
                    <select bind:value={newOfferCurr} class="input-field text-xs py-1">
                      <option value="DZD">DZD (دينار جزائري)</option>
                      <option value="EGP">EGP (جنيه مصري)</option>
                      <option value="SAR">SAR (ريال سعودي)</option>
                      <option value="USD">USD (دولار)</option>
                    </select>
                  </div>
                  <div>
                    <span class="block text-zinc-400 text-[11px] mb-1">طريقة الدفع:</span>
                    <input type="text" bind:value={newOfferMethod} class="input-field text-xs py-1" />
                  </div>
                </div>
                <button 
                  type="button" 
                  on:click={handleCreateOffer}
                  disabled={isCreatingOffer || newOfferWala <= 0}
                  class="btn-primary w-full py-2 text-xs font-bold"
                >
                  {isCreatingOffer ? 'جاري قفل الضمان والنشر...' : 'نشر العرض في سوق P2P 🚀'}
                </button>
              </div>
            {/if}

            {#if p2pFeedback}
              <div class="p-3 rounded-xl bg-indigo-950/80 border border-indigo-500/40 text-indigo-300 text-xs text-center font-bold">
                {p2pFeedback}
              </div>
            {/if}

            <!-- Offers List -->
            {#if loadingP2P}
              <div class="p-8 text-center text-zinc-500 text-xs flex items-center justify-center gap-2">
                <span class="animate-spin">⏳</span>
                <span>جاري استعلام عروض شبكة مَجْد...</span>
              </div>
            {:else if p2pOffers.length === 0}
              <div class="p-8 text-center text-zinc-500 text-xs">
                لا توجد عروض بيع نشطة حالياً. يمكنك إنشاء أول عرض!
              </div>
            {:else}
              <div class="space-y-2.5">
                {#each p2pOffers as offer}
                  <div class="p-3.5 rounded-2xl bg-zinc-900/80 border border-zinc-800 hover:border-zinc-700 transition flex items-center justify-between gap-3 text-xs">
                    <div class="space-y-1 text-start min-w-0">
                      <div class="flex items-center gap-2">
                        <span class="font-bold text-white">@{offer.seller_id}</span>
                        <span class="px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 text-[10px] font-mono border border-emerald-500/20">ضمان مفعل ✓</span>
                      </div>
                      <div class="text-zinc-400 text-[11px] flex items-center gap-2">
                        <span>{offer.payment_method}</span>
                        <span>•</span>
                        <span class="text-zinc-500">{Number(offer.wala_amount * 1000000).toLocaleString()} إخلاص</span>
                      </div>
                    </div>

                    <div class="text-end shrink-0">
                      <div class="font-black text-amber-300 text-sm">{Number(offer.wala_amount).toLocaleString()} WALA</div>
                      <div class="text-zinc-300 font-mono text-xs font-bold mb-1.5">{Number(offer.fiat_price).toLocaleString()} {offer.currency}</div>
                      <button 
                        type="button" 
                        on:click={() => handleP2PBuy(offer)}
                        disabled={buyingOfferId === offer.id}
                        class="px-3 py-1 rounded-xl bg-gradient-to-r from-indigo-600 to-purple-600 text-white font-bold text-xs transition active:scale-95 shadow-sm"
                      >
                        {buyingOfferId === offer.id ? 'جاري التحويل...' : 'شراء فوري ⚡'}
                      </button>
                    </div>
                  </div>
                {/each}
              </div>
            {/if}
          </div>

        <!-- TAB 3: Converter (WALA <-> Ikhlas) -->
        {:else if activeTab === 'converter'}
          <div class="space-y-4">
            <div class="p-4 rounded-2xl bg-gradient-to-tr from-purple-950/40 via-zinc-900 to-zinc-950 border border-purple-500/30 text-xs space-y-3">
              <div class="font-bold text-purple-300 flex items-center gap-2 text-sm">
                <span>🔄</span>
                <span>محول وحدات عملة الولاء المجهرية</span>
              </div>
              <p class="text-zinc-400 text-[11px] leading-relaxed">
                كل 1 ولاء (WALA) ينقسم رياضياً إلى 1,000,000 إخلاص (IKH) لتسهيل المعاملات الدقيقة والإكراميات وقراءة المقالات.
              </p>
            </div>

            <!-- Converter Box -->
            <div class="p-5 rounded-2xl bg-zinc-900/90 border border-zinc-800 space-y-4">
              <div>
                <span class="block text-xs font-bold text-zinc-300 mb-1">الكمية بوحدة الولاء (WALA):</span>
                <div class="relative">
                  <input 
                    type="number" 
                    value={convWala} 
                    on:input={(e) => handleWalaInput(e.target.value)} 
                    class="input-field font-mono font-bold text-sm pe-16" 
                    step="any"
                  />
                  <span class="absolute end-3 top-2.5 text-xs font-black text-amber-400 font-mono">WALA</span>
                </div>
              </div>

              <div class="flex justify-center text-lg text-purple-400">
                ⇅
              </div>

              <div>
                <span class="block text-xs font-bold text-zinc-300 mb-1">الكمية المعادل بوحدة الإخلاص (IKH):</span>
                <div class="relative">
                  <input 
                    type="number" 
                    value={convIkhlas} 
                    on:input={(e) => handleIkhlasInput(e.target.value)} 
                    class="input-field font-mono font-bold text-sm pe-16" 
                    step="1"
                  />
                  <span class="absolute end-3 top-2.5 text-xs font-black text-emerald-400 font-mono">إخلاص</span>
                </div>
              </div>

              <!-- Quick reference table -->
              <div class="pt-3 border-t border-zinc-800 text-[11px] font-mono text-zinc-400 space-y-1.5">
                <div class="flex justify-between">
                  <span>0.000001 WALA</span>
                  <span class="text-zinc-200">= 1 إخلاص (رسوم معاملة)</span>
                </div>
                <div class="flex justify-between">
                  <span>0.001 WALA</span>
                  <span class="text-zinc-200">= 1,000 إخلاص (مروءة / إكرامية)</span>
                </div>
                <div class="flex justify-between">
                  <span>1.0 WALA</span>
                  <span class="text-amber-300 font-bold">= 1,000,000 إخلاص (ولاء كامل)</span>
                </div>
              </div>
            </div>
          </div>
        {/if}

      </div>
    </div>
  </div>
{/if}
