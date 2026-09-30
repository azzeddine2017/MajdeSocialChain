<script>
  import { createEventDispatcher } from 'svelte'
  import { currentLang, t, setLanguage } from './i18n.js'
  import { BRAND_LOGO } from './brandLogo.js'
  const dispatch = createEventDispatcher()
  let mode = 'choose' // 'choose' | 'create' | 'mnemonic' | 'recover' | 'unlock'
  let password = ''
  let confirmPassword = ''
  let mnemonicWords = []
  let mnemonicInput = ''
  let copiedMnemonic = false
  let error = ''
  let loading = false
  let showPassword = false

  $: passwordStrength = calculateStrength(password)

  function calculateStrength(pwd) {
    if (!pwd) return { score: 0, text: '', color: 'bg-zinc-700' }
    let s = 0
    if (pwd.length >= 8) s++
    if (pwd.length >= 12) s++
    if (/[A-Z]/.test(pwd)) s++
    if (/[0-9]/.test(pwd)) s++
    if (/[^A-Za-z0-9]/.test(pwd)) s++

    if (s <= 2) return { score: 33, text: t('pwdWeak', $currentLang), color: 'bg-rose-500' }
    if (s <= 4) return { score: 66, text: t('pwdMedium', $currentLang), color: 'bg-amber-500' }
    return { score: 100, text: t('pwdStrong', $currentLang), color: 'bg-emerald-500' }
  }

  async function createWallet() {
    if (password.length < 8) {
      error = t('passwordMin', $currentLang)
      return
    }
    if (password !== confirmPassword) {
      error = t('pwdMismatch', $currentLang)
      return
    }
    error = ''
    loading = true
    try {
      if (window.createWallet) {
        let res = await window.createWallet(password)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.mnemonic) {
          mnemonicWords = res.mnemonic.trim().split(/\s+/)
          mode = 'mnemonic'
          return
        }
      }
      dispatch('unlocked')
    } catch (e) {
      error = e.message || 'Error generating wallet'
    } finally {
      loading = false
    }
  }

  async function copyPhrase() {
    if (!mnemonicWords || mnemonicWords.length === 0) return
    const text = mnemonicWords.join(' ')
    let success = false

    // Method 1: Modern Async Clipboard API
    if (navigator?.clipboard?.writeText) {
      try {
        await navigator.clipboard.writeText(text)
        success = true
      } catch (_) {}
    }

    // Method 2: Synchronous execCommand fallback for WebView sandboxes
    if (!success) {
      try {
        const textarea = document.createElement('textarea')
        textarea.value = text
        textarea.setAttribute('readonly', '')
        textarea.style.position = 'fixed'
        textarea.style.left = '-9999px'
        textarea.style.top = '-9999px'
        textarea.style.opacity = '0'
        document.body.appendChild(textarea)
        textarea.focus()
        textarea.select()
        success = document.execCommand('copy')
        document.body.removeChild(textarea)
      } catch (err) {
        console.warn('execCommand copy failed:', err)
      }
    }

    copiedMnemonic = true
    setTimeout(() => copiedMnemonic = false, 2500)
  }

  async function recoverWallet() {
    const phrase = mnemonicInput.trim()
    const words = phrase.split(/\s+/)
    if (words.length < 12) {
      error = t('enterMnemonic', $currentLang)
      return
    }
    error = ''
    loading = true
    try {
      if (window.recoverWallet) {
        await window.recoverWallet(phrase, password || 'mejde_default_secure_pass')
      }
      dispatch('unlocked')
    } catch (e) {
      error = typeof e === 'string' ? e : (e.message || 'Recovery failed')
    } finally {
      loading = false
    }
  }

  async function unlockWallet() {
    if (!password) {
      error = t('enterPassword', $currentLang)
      return
    }
    error = ''
    loading = true
    try {
      if (window.unlockWallet) {
        await window.unlockWallet(password)
      }
      dispatch('unlocked')
    } catch (e) {
      error = 'Wrong password / فشل فك التشفير'
      password = ''
    } finally {
      loading = false
    }
  }

  function reset() {
    password = ''
    confirmPassword = ''
    mnemonicInput = ''
    mnemonicWords = []
    copiedMnemonic = false
    error = ''
    loading = false
  }

  function toggleLang() {
    setLanguage($currentLang === 'ar' ? 'en' : 'ar')
  }
</script>

<div class="min-h-screen flex flex-col items-center justify-center p-4 relative">
  <!-- Glowing Background Orbs -->
  <div class="absolute w-72 h-72 bg-indigo-600/15 rounded-full blur-3xl pointer-events-none -top-10"></div>
  <div class="absolute w-72 h-72 bg-purple-600/10 rounded-full blur-3xl pointer-events-none -bottom-10"></div>

  <!-- Top Language Switcher on Onboarding -->
  <div class="absolute top-4 right-4 z-20">
    <button 
      type="button" 
      on:click={toggleLang}
      class="px-3 py-1.5 rounded-full bg-zinc-900/80 hover:bg-zinc-800 border border-zinc-800 text-xs font-bold text-zinc-300 transition"
    >
      {$currentLang === 'ar' ? 'English' : 'عربي'}
    </button>
  </div>

  <div class="card p-7 w-full max-w-sm text-center relative z-10 border border-zinc-800/80 shadow-2xl backdrop-blur-xl">
    <!-- Header Branding -->
    <div class="mb-6">
      <div class="w-16 h-16 mx-auto mb-3 rounded-2xl bg-gradient-to-tr from-amber-500 via-orange-600 to-purple-600 p-0.5 shadow-xl shadow-amber-500/20">
        <div class="w-full h-full bg-zinc-950 rounded-2xl flex items-center justify-center overflow-hidden p-2">
          {#if BRAND_LOGO}
            <img src={BRAND_LOGO} alt="Mejde" class="w-full h-full object-contain" />
          {:else}
            <span class="text-3xl">⛓️</span>
          {/if}
        </div>
      </div>
      <h1 class="text-2xl font-black gradient-text tracking-tight mb-1">{t('appName', $currentLang)}</h1>
      <p class="text-xs text-zinc-400 font-medium">{t('appSub', $currentLang)}</p>
      <div class="flex items-center justify-center gap-2 mt-2">
        <span class="text-[10px] bg-emerald-500/10 text-emerald-400 px-2 py-0.5 rounded-full border border-emerald-500/20 font-mono">LibSQL Companion DB</span>
        <span class="text-[10px] bg-indigo-500/10 text-indigo-400 px-2 py-0.5 rounded-full border border-indigo-500/20 font-mono">WALA Token</span>
      </div>
    </div>

    <!-- Mode: Choose -->
    {#if mode === 'choose'}
      <div class="space-y-4">
        <!-- Feature Highlights -->
        <div class="bg-zinc-900/60 p-3 rounded-xl border border-zinc-800/60 text-start space-y-1.5 text-xs text-zinc-300">
          <div class="flex items-center gap-2">
            <span class="text-emerald-400 font-bold">✓</span>
            <span>{t('feature1', $currentLang)}</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-emerald-400 font-bold">✓</span>
            <span>{t('feature2', $currentLang)}</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-emerald-400 font-bold">✓</span>
            <span>{t('feature3', $currentLang)}</span>
          </div>
        </div>

        <div class="space-y-2.5 pt-2">
          <button class="btn-primary w-full py-3 text-sm font-bold shadow-lg" on:click={() => { reset(); mode = 'create'; }}>
            <span>✨</span>
            <span>{t('createAccount', $currentLang)}</span>
          </button>
          <button class="btn-secondary w-full py-3 text-sm font-bold" on:click={() => { reset(); mode = 'unlock'; }}>
            <span>🔑</span>
            <span>{t('unlockAccount', $currentLang)}</span>
          </button>
          <button class="btn-secondary w-full py-2.5 text-xs font-bold border-indigo-500/30 text-indigo-300 hover:bg-indigo-500/10" on:click={() => { reset(); mode = 'recover'; }}>
            <span>🗝️</span>
            <span>{t('recoverWithMnemonic', $currentLang)}</span>
          </button>
        </div>
      </div>

    <!-- Mode: Mnemonic Display Backup (After Wallet Creation) -->
    {:else if mode === 'mnemonic'}
      <div class="space-y-4 text-start">
        <div class="text-center">
          <div class="w-10 h-10 mx-auto mb-2 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center text-xl">
            🛡️
          </div>
          <h2 class="text-base font-black text-zinc-100">{t('mnemonicTitle', $currentLang)}</h2>
          <p class="text-[11px] text-amber-300/90 mt-1 leading-relaxed bg-amber-500/10 p-2.5 rounded-xl border border-amber-500/20">
            ⚠️ {t('mnemonicWarning', $currentLang)}
          </p>
        </div>

        <!-- 12-Word Numbered Grid -->
        <div class="grid grid-cols-3 gap-2 py-1">
          {#each mnemonicWords as word, idx}
            <div class="flex items-center gap-1.5 p-2 rounded-xl bg-zinc-900/90 border border-zinc-800 text-xs font-mono">
              <span class="text-[10px] text-zinc-500 font-bold select-none">{idx + 1}.</span>
              <span class="text-zinc-200 font-bold">{word}</span>
            </div>
          {/each}
        </div>

        <!-- Full Selectable Text Box for direct copy -->
        <div class="p-2.5 rounded-xl bg-zinc-950/80 border border-zinc-800 text-[11px] font-mono text-zinc-300 select-all leading-relaxed break-words text-center">
          {mnemonicWords.join(' ')}
        </div>

        <button 
          type="button" 
          class="btn-secondary w-full py-2.5 text-xs font-bold flex items-center justify-center gap-2 {copiedMnemonic ? 'border-emerald-500/50 text-emerald-400 bg-emerald-500/10' : ''}" 
          on:click={copyPhrase}
        >
          <span>{copiedMnemonic ? '✓' : '📋'}</span>
          <span>{copiedMnemonic ? t('mnemonicCopied', $currentLang) : t('copyMnemonic', $currentLang)}</span>
        </button>

        <button 
          type="button" 
          class="btn-primary w-full py-3 text-sm font-bold shadow-lg shadow-indigo-600/30" 
          on:click={() => dispatch('unlocked')}
        >
          {t('iSavedMnemonic', $currentLang)}
        </button>
      </div>

    <!-- Mode: Recover with 12 Words -->
    {:else if mode === 'recover'}
      <div class="space-y-4 text-start">
        <div>
          <h2 class="text-base font-bold text-zinc-100 text-center">{t('recoverWithMnemonic', $currentLang)}</h2>
          <p class="text-[11px] text-zinc-400 text-center mt-1 leading-relaxed">
            {t('enterMnemonic', $currentLang)}
          </p>
        </div>

        <div>
          <textarea
            bind:value={mnemonicInput}
            rows="3"
            class="input-field text-xs font-mono leading-relaxed resize-none"
            placeholder="abandon ability able about above absent absorb abstract absurd abuse access accident"
          ></textarea>
        </div>

        {#if error}
          <div class="p-2.5 rounded-lg bg-rose-950/50 border border-rose-500/30 text-xs text-rose-300 text-center font-medium">
            {error}
          </div>
        {/if}

        <div class="flex gap-2 pt-1">
          <button class="btn-secondary flex-1 py-2.5 text-xs font-bold" on:click={() => { reset(); mode = 'choose'; }}>
            {t('cancel', $currentLang)}
          </button>
          <button class="btn-primary flex-1 py-2.5 text-xs font-bold" on:click={recoverWallet} disabled={loading || !mnemonicInput}>
            {#if loading}
              <span class="animate-spin text-xs">⏳</span>
              <span>...</span>
            {:else}
              <span>{t('restoreAccount', $currentLang)}</span>
            {/if}
          </button>
        </div>
      </div>

    <!-- Mode: Create Wallet -->
    {:else if mode === 'create'}
      <div class="space-y-4 text-start">
        <div>
          <h2 class="text-base font-bold text-zinc-100 text-center">{t('createAccount', $currentLang)}</h2>
          <p class="text-[11px] text-zinc-400 text-center mt-1 leading-relaxed">
            {t('securityNote', $currentLang)}
          </p>
        </div>

        <!-- Password input with eye toggle -->
        <div>
          <label for="create-pwd" class="block text-xs text-zinc-400 mb-1">{t('passwordMin', $currentLang)}</label>
          <div class="relative">
            {#if showPassword}
              <input 
                id="create-pwd"
                type="text" 
                class="input-field pl-10" 
                placeholder="••••••••••••" 
                bind:value={password} 
              />
            {:else}
              <input 
                id="create-pwd"
                type="password" 
                class="input-field pl-10" 
                placeholder="••••••••••••" 
                bind:value={password} 
              />
            {/if}
            <button 
              type="button" 
              class="absolute left-3 top-3 text-sm text-zinc-500 hover:text-zinc-300"
              on:click={() => showPassword = !showPassword}
              title={showPassword ? 'Hide' : 'Show'}
            >
              {showPassword ? '🙈' : '👁️'}
            </button>
          </div>
          {#if password}
            <div class="mt-1.5 flex items-center justify-between text-[11px]">
              <div class="flex-1 h-1.5 bg-zinc-800 rounded-full overflow-hidden ml-2">
                <div class="h-full {passwordStrength.color} transition-all duration-300" style="width: {passwordStrength.score}%"></div>
              </div>
              <span class="text-zinc-400 font-medium">{passwordStrength.text}</span>
            </div>
          {/if}
        </div>

        <div>
          <label for="confirm-pwd" class="block text-xs text-zinc-400 mb-1">{t('confirmPassword', $currentLang)}</label>
          {#if showPassword}
            <input 
              id="confirm-pwd"
              type="text" 
              class="input-field" 
              placeholder="••••••••••••" 
              bind:value={confirmPassword} 
            />
          {:else}
            <input 
              id="confirm-pwd"
              type="password" 
              class="input-field" 
              placeholder="••••••••••••" 
              bind:value={confirmPassword} 
            />
          {/if}
        </div>

        {#if error}
          <div class="p-2.5 rounded-lg bg-rose-950/50 border border-rose-500/30 text-xs text-rose-300 text-center font-medium">
            {error}
          </div>
        {/if}

        <div class="flex gap-2 pt-1">
          <button class="btn-secondary flex-1 py-2.5 text-xs font-bold" on:click={() => { reset(); mode = 'choose'; }}>
            {t('cancel', $currentLang)}
          </button>
          <button class="btn-primary flex-1 py-2.5 text-xs font-bold" on:click={createWallet} disabled={loading || !password}>
            {#if loading}
              <span class="animate-spin text-xs">⏳</span>
              <span>...</span>
            {:else}
              <span>{t('createAndSecure', $currentLang)}</span>
            {/if}
          </button>
        </div>
      </div>

    <!-- Mode: Unlock Wallet -->
    {:else if mode === 'unlock'}
      <div class="space-y-4 text-start">
        <div>
          <h2 class="text-base font-bold text-zinc-100 text-center">{t('unlockAccount', $currentLang)}</h2>
          <p class="text-[11px] text-zinc-400 text-center mt-1">{t('enterPassword', $currentLang)}</p>
        </div>

        <div>
          <label for="unlock-pwd" class="block text-xs text-zinc-400 mb-1">{t('enterPassword', $currentLang)}</label>
          <div class="relative">
            {#if showPassword}
              <input 
                id="unlock-pwd"
                type="text" 
                class="input-field pl-10" 
                placeholder="••••••••••••" 
                bind:value={password}
                on:keydown={(e) => e.key === 'Enter' && unlockWallet()} 
              />
            {:else}
              <input 
                id="unlock-pwd"
                type="password" 
                class="input-field pl-10" 
                placeholder="••••••••••••" 
                bind:value={password}
                on:keydown={(e) => e.key === 'Enter' && unlockWallet()} 
              />
            {/if}
            <button 
              type="button" 
              class="absolute left-3 top-3 text-sm text-zinc-500 hover:text-zinc-300"
              on:click={() => showPassword = !showPassword}
            >
              {showPassword ? '🙈' : '👁️'}
            </button>
          </div>
        </div>

        {#if error}
          <div class="p-2.5 rounded-lg bg-rose-950/50 border border-rose-500/30 text-xs text-rose-300 text-center font-medium">
            {error}
          </div>
        {/if}

        <div class="flex gap-2 pt-1">
          <button class="btn-secondary flex-1 py-2.5 text-xs font-bold" on:click={() => { reset(); mode = 'choose'; }}>
            {t('cancel', $currentLang)}
          </button>
          <button class="btn-primary flex-1 py-2.5 text-xs font-bold" on:click={unlockWallet} disabled={loading || !password}>
            {#if loading}
              <span class="animate-spin text-xs">⏳</span>
              <span>...</span>
            {:else}
              <span>{t('unlockWallet', $currentLang)}</span>
            {/if}
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>
