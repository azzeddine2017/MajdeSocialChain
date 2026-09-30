<script>
  import { createEventDispatcher } from 'svelte'
  import { currentLang, t } from './i18n.js'
  const dispatch = createEventDispatcher()
  let content = ''
  let mediaUrl = ''
  let mediaData = ''
  let fileInput
  let showMediaInput = false
  let focused = false
  let loading = false
  let quotaError = ''

  const quickTags = ['#Mejde', '#WalaCoin', '#Web3', '#LibSQL']

  function addTag(tag) {
    if (!content.includes(tag)) {
      content = (content + ' ' + tag).trim()
    }
  }

  function handleFileSelect(e) {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (event) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        const maxW = 800
        const scale = Math.min(1, maxW / Math.max(img.width, img.height))
        canvas.width = Math.round(img.width * scale)
        canvas.height = Math.round(img.height * scale)
        const ctx = canvas.getContext('2d')
        ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
        mediaData = canvas.toDataURL('image/jpeg', 0.82)
      }
      img.src = event.target.result
    }
    reader.readAsDataURL(file)
  }

  async function publish() {
    const text = content.trim()
    if ((!text && !mediaData && !mediaUrl) || loading) return
    loading = true
    quotaError = ''
    try {
      if (window.createPost) {
        let res = await window.createPost('me', text, mediaUrl.trim(), mediaData)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res && res.error) {
          quotaError = res.error
          return
        }
      }
      content = ''
      mediaUrl = ''
      mediaData = ''
      showMediaInput = false
      focused = false
      dispatch('created')
    } catch (err) {
      console.error('Publish error:', err)
      quotaError = err.message || 'Publish failed'
    } finally {
      loading = false
    }
  }
</script>

<div class="card p-4 mx-3 mb-3 border border-zinc-800/80 shadow-xl {focused ? 'ring-1 ring-indigo-500/50 border-indigo-500/30' : ''} transition-all duration-200">
  <div class="flex gap-3 items-start">
    <!-- User Avatar -->
    <div class="avatar-ring shrink-0 mt-0.5">
      <div class="w-9 h-9 rounded-full bg-zinc-900 flex items-center justify-center text-xs font-black text-indigo-300">
        ME
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="flex-1 min-w-0">
      <textarea
        bind:value={content}
        on:focus={() => focused = true}
        on:blur={() => focused = false}
        on:keydown={(e) => (e.ctrlKey || e.metaKey) && e.key === 'Enter' && publish()}
        rows={focused || content.length > 50 ? 3 : 2}
        placeholder={t('composePlaceholder', $currentLang)}
        disabled={loading}
        class="w-full bg-transparent text-sm text-zinc-100 placeholder-zinc-500 outline-none resize-none leading-relaxed"
      ></textarea>

      <!-- Attached Local Image Preview -->
      {#if mediaData}
        <div class="mt-2 relative rounded-xl overflow-hidden border border-zinc-700/80 bg-zinc-950 max-h-48 group">
          <img src={mediaData} alt="معاينة" class="w-full max-h-48 object-cover" />
          <button 
            type="button" 
            on:click={() => mediaData = ''}
            class="absolute top-2 right-2 p-1.5 rounded-full bg-zinc-900/90 text-zinc-300 hover:text-white border border-zinc-700 text-xs shadow-lg"
            title="إزالة الصورة"
          >
            ✕
          </button>
        </div>
      {/if}

      <!-- Hidden file input for device image upload -->
      <input 
        type="file" 
        accept="image/*" 
        bind:this={fileInput} 
        on:change={handleFileSelect} 
        class="hidden" 
      />

      {#if quotaError}
        <div class="mt-2 p-2 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-300 text-start">
          ⚠️ {quotaError}
        </div>
      {/if}

      <!-- Media URL Input Drawer -->
      {#if showMediaInput}
        <div class="mt-2 p-2.5 bg-zinc-900/80 border border-zinc-800 rounded-xl space-y-2">
          <div class="flex items-center justify-between text-xs text-zinc-400">
            <span>🔗 {t('attachMedia', $currentLang)}</span>
            <button type="button" on:click={() => { showMediaInput = false; mediaUrl = ''; }} class="text-zinc-500 hover:text-zinc-300">✕</button>
          </div>
          <input 
            type="text" 
            bind:value={mediaUrl} 
            placeholder="https://... or ipfs://..." 
            class="w-full bg-zinc-950 border border-zinc-700/60 rounded-lg px-3 py-1.5 text-xs text-zinc-200 outline-none focus:border-indigo-500 font-mono"
          />
          {#if mediaUrl}
            <div class="relative rounded-lg overflow-hidden border border-zinc-800 max-h-32 bg-zinc-950">
              <img src={mediaUrl} alt="معاينة" class="w-full h-32 object-cover" on:error={(e) => e.target.style.display = 'none'} />
            </div>
          {/if}
        </div>
      {/if}

      <!-- Quick Hashtags -->
      <div class="flex flex-wrap gap-1.5 mt-2 pt-1 border-t border-zinc-800/40">
        {#each quickTags as tag}
          <button 
            type="button" 
            on:click={() => addTag(tag)}
            class="text-[11px] px-2 py-0.5 rounded-full bg-zinc-800/60 hover:bg-indigo-500/20 text-zinc-400 hover:text-indigo-300 transition font-mono"
          >
            {tag}
          </button>
        {/each}
      </div>

      <!-- Action Toolbar (Responsive for mobile screens) -->
      <div class="flex flex-wrap sm:flex-nowrap items-center justify-between gap-2 mt-3 pt-2 border-t border-zinc-800/40">
        <div class="flex items-center gap-1 min-w-0">
          <!-- Device Image Upload Button -->
          <button 
            type="button"
            on:click={() => fileInput.click()}
            class="p-1.5 sm:p-2 rounded-xl text-zinc-400 hover:text-emerald-400 hover:bg-zinc-800/60 transition {mediaData ? 'text-emerald-400 bg-emerald-500/10' : ''}"
            title={t('uploadImage', $currentLang)}
          >
            📸
          </button>

          <!-- Attach Media URL Button -->
          <button 
            type="button"
            on:click={() => showMediaInput = !showMediaInput}
            class="p-1.5 sm:p-2 rounded-xl text-zinc-400 hover:text-indigo-400 hover:bg-zinc-800/60 transition {showMediaInput ? 'text-indigo-400 bg-indigo-500/10' : ''}"
            title={t('attachMedia', $currentLang)}
          >
            🔗
          </button>

          <!-- Blockchain Signature Indicator (Compact icon on mobile, full label on larger screens) -->
          <span class="text-[10px] text-zinc-500 flex items-center gap-1 font-mono pr-1 truncate" title={t('digitalSignature', $currentLang)}>
            <span>🔒</span>
            <span class="hidden sm:inline">{t('digitalSignature', $currentLang)}</span>
          </span>
        </div>

        <div class="flex items-center gap-2 shrink-0 ms-auto">
          <!-- Character count indicator -->
          <span class="text-[10px] sm:text-[11px] font-mono {content.length > 250 ? 'text-amber-400 font-bold' : 'text-zinc-500'}">
            {content.length}/280
          </span>

          <!-- Publish button (shrink-0 to guarantee it remains fully visible) -->
          <button 
            type="button"
            on:click={publish} 
            class="btn-primary text-xs font-bold px-3 py-1.5 sm:px-4 sm:py-2 shrink-0 whitespace-nowrap shadow-md" 
            disabled={(!content.trim() && !mediaData && !mediaUrl) || loading}
          >
            {#if loading}
              <span class="inline-block animate-spin text-xs">⏳</span>
              <span class="hidden sm:inline">{t('publishing', $currentLang)}</span>
            {:else}
              <span>{t('publish', $currentLang)}</span>
            {/if}
          </button>
        </div>
      </div>
    </div>
  </div>
</div>
