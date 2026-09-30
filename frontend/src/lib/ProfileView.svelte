<script>
  import { onMount, createEventDispatcher } from 'svelte'
  import { currentLang, t } from './i18n.js'

  const dispatch = createEventDispatcher()

  let profile = { id: '', username: '', bio: '', avatar_data: '', avatar_cid: '' }
  let userPosts = []
  let followStats = { followers: 0, following: 0 }
  let isEditing = false
  let newUsername = ''
  let newBio = ''
  let newAvatar = ''
  let saveMsg = ''
  let avatarFileInput

  onMount(async () => {
    await loadProfile()
    await loadMyPosts()
    await loadFollowStats()
  })

  async function loadFollowStats() {
    try {
      if (window.getFollowStats) {
        let res = await window.getFollowStats('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (res) followStats = res
      }
    } catch (e) {}
  }

  async function loadProfile() {
    try {
      if (window.getProfile) {
        let res = await window.getProfile('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (Array.isArray(res) && res.length > 0 && Array.isArray(res[0])) {
          const obj = {}
          res.forEach(pair => { if (Array.isArray(pair)) obj[pair[0]] = pair[1] })
          profile = obj
        } else if (res && typeof res === 'object') {
          profile = res
        }
        newUsername = profile.username || profile.id || ''
        newBio = profile.bio || ''
        newAvatar = profile.avatar_data || profile.avatar_cid || ''
      }
    } catch (e) {
      console.error('Error loading profile:', e)
    }
  }

  function handleAvatarSelect(e) {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (event) => {
      const img = new Image()
      img.onload = () => {
        const canvas = document.createElement('canvas')
        const size = 200
        canvas.width = size
        canvas.height = size
        const ctx = canvas.getContext('2d')
        // Center-crop to square
        const minDim = Math.min(img.width, img.height)
        const sx = (img.width - minDim) / 2
        const sy = (img.height - minDim) / 2
        ctx.drawImage(img, sx, sy, minDim, minDim, 0, 0, size, size)
        newAvatar = canvas.toDataURL('image/jpeg', 0.85)
      }
      img.src = event.target.result
    }
    reader.readAsDataURL(file)
  }

  function removeAvatar() {
    newAvatar = ''
  }

  function getPostMedia(post) {
    if (!post) return null
    const data = post.media_data || post.media || post.media_url
    if (data && typeof data === 'string' && data.trim() !== '' && data !== 'null' && data !== 'undefined') {
      return data.trim()
    }
    const cid = post.media_cid
    if (cid && typeof cid === 'string' && cid.trim() !== '' && cid !== 'null' && cid !== 'undefined') {
      const trimmed = cid.trim()
      if (trimmed.startsWith('data:') || trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed
      }
      return `https://ipfs.io/ipfs/${trimmed}`
    }
    return null
  }

  async function loadMyPosts() {
    try {
      if (window.getUserPosts) {
        let res = await window.getUserPosts('me')
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (Array.isArray(res)) {
          userPosts = res.map(item => {
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
      console.error('Error loading user posts:', e)
    }
  }

  async function saveProfile() {
    try {
      if (window.updateProfile) {
        const avatarToSave = newAvatar !== undefined ? newAvatar : (profile.avatar_data || '')
        await window.updateProfile('me', newUsername, newBio, avatarToSave)
        profile.username = newUsername
        profile.bio = newBio
        profile.avatar_data = avatarToSave
        isEditing = false
        saveMsg = '✓ ' + t('saveChanges', $currentLang)
        dispatch('profileUpdated')
        setTimeout(() => saveMsg = '', 3000)
      }
    } catch (e) {
      saveMsg = 'Error: ' + (e.message || e)
    }
  }

  function copyId() {
    const text = profile.id || ''
    if (!text) return
    let success = false
    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(text).catch(() => {})
      success = true
    }
    if (!success) {
      try {
        const textarea = document.createElement('textarea')
        textarea.value = text
        textarea.setAttribute('readonly', '')
        textarea.style.position = 'fixed'
        textarea.style.left = '-9999px'
        document.body.appendChild(textarea)
        textarea.select()
        document.execCommand('copy')
        document.body.removeChild(textarea)
      } catch (_) {}
    }
    saveMsg = t('idCopied', $currentLang)
    setTimeout(() => saveMsg = '', 2500)
  }
</script>

<div class="space-y-4 max-w-[560px] mx-auto pb-10">
  <!-- Profile Banner & Header -->
  <div class="card overflow-hidden border border-zinc-800 shadow-xl">
    <!-- Banner Cover -->
    <div class="h-28 bg-gradient-to-r from-indigo-900 via-purple-900 to-zinc-950 relative">
      <div class="absolute inset-0 bg-black/20"></div>
    </div>

    <!-- Hidden file input for Avatar selection -->
    <input 
      type="file" 
      accept="image/*" 
      bind:this={avatarFileInput} 
      on:change={handleAvatarSelect} 
      class="hidden" 
    />

    <!-- Profile Details Box -->
    <div class="px-5 pb-5 relative text-start">
      <!-- Avatar overlapping banner -->
      <div class="flex justify-between items-end -mt-12 mb-3">
        <div class="relative group">
          <button 
            type="button" 
            class="avatar-ring shadow-2xl overflow-hidden cursor-pointer p-0 border-0 bg-transparent text-start block" 
            on:click={() => isEditing && avatarFileInput.click()}
          >
            {#if isEditing}
              {#if newAvatar}
                <img src={newAvatar} alt="Avatar" class="w-20 h-20 rounded-full object-cover" />
              {:else}
                <div class="w-20 h-20 rounded-full bg-zinc-950 flex flex-col items-center justify-center text-xs font-bold text-zinc-400">
                  <span class="text-xl">📷</span>
                </div>
              {/if}
              <!-- Hover Overlay for editing -->
              <div class="absolute inset-0 bg-black/60 rounded-full flex flex-col items-center justify-center text-white text-[10px] font-bold opacity-80 group-hover:opacity-100 transition">
                <span>📷</span>
                <span>تعديل</span>
              </div>
            {:else}
              {#if (profile.avatar_data && (profile.avatar_data.startsWith('data:') || profile.avatar_data.startsWith('http'))) || (profile.avatar_cid && (profile.avatar_cid.startsWith('data:') || profile.avatar_cid.startsWith('http')))}
                <img src={profile.avatar_data || profile.avatar_cid} alt="Avatar" class="w-20 h-20 rounded-full object-cover" />
              {:else}
                <div class="w-20 h-20 rounded-full bg-zinc-950 flex items-center justify-center text-2xl font-black text-white">
                  {(profile.username || 'ME').slice(0, 2).toUpperCase()}
                </div>
              {/if}
            {/if}
          </button>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center gap-2">
          <button 
            type="button"
            on:click={() => { isEditing = !isEditing; if (isEditing) newAvatar = profile.avatar_data || profile.avatar_cid || ''; }}
            class="btn-secondary text-xs font-bold py-1.5 px-4"
          >
            {isEditing ? t('cancel', $currentLang) : t('editProfile', $currentLang)}
          </button>
          {#if !isEditing}
            <button 
              type="button" 
              on:click={() => dispatch('logout')}
              class="btn-secondary text-xs font-bold py-1.5 px-3 border-rose-900/40 text-rose-400 hover:bg-rose-950/30"
              title={t('logout', $currentLang)}
            >
              🚪 {t('logout', $currentLang)}
            </button>
          {/if}
        </div>
      </div>

      <!-- Identity Info -->
      {#if !isEditing}
        <div class="space-y-1">
          <div class="flex items-center gap-1.5">
            <h2 class="text-lg font-bold text-zinc-100">{profile.username || profile.id || 'Mejde Sovereign User'}</h2>
            <span class="text-indigo-400 text-sm">✓</span>
          </div>

          <div class="flex items-center gap-2 text-xs text-zinc-500 font-mono">
            <span>@{profile.id || 'user_anon'}</span>
            <button type="button" on:click={copyId} class="text-indigo-400 hover:text-indigo-300" title="Copy ID">📋</button>
          </div>

          <p class="text-xs text-zinc-300 pt-2 leading-relaxed">
            {profile.bio || 'Mejde Sovereign Creator & Node Operator.'}
          </p>

          <!-- Follows Counters -->
          <div class="flex items-center gap-4 pt-2 text-xs">
            <div>
              <span class="font-bold text-zinc-100">{followStats.followers || 0}</span>
              <span class="text-zinc-500">{t('followers', $currentLang)}</span>
            </div>
            <div>
              <span class="font-bold text-zinc-100">{followStats.following || 0}</span>
              <span class="text-zinc-500">{t('followingCount', $currentLang)}</span>
            </div>
          </div>

          <!-- Badges Bar -->
          <div class="flex flex-wrap gap-2 pt-2">
            <span class="text-[10px] bg-indigo-500/10 text-indigo-400 px-2.5 py-1 rounded-full border border-indigo-500/20 font-semibold">
              {t('secureWallet', $currentLang)}
            </span>
            <span class="text-[10px] bg-emerald-500/10 text-emerald-400 px-2.5 py-1 rounded-full border border-emerald-500/20 font-semibold">
              {t('activeNode', $currentLang)}
            </span>
          </div>
        </div>
      {:else}
        <!-- Edit Profile Form -->
        <div class="space-y-3 pt-2 text-start">
          <!-- Avatar Buttons in Edit mode -->
          <div class="flex items-center gap-2 pb-2 border-b border-zinc-800/80">
            <button 
              type="button" 
              on:click={() => avatarFileInput.click()} 
              class="px-3 py-1.5 rounded-xl bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-300 border border-indigo-500/30 text-xs font-bold transition flex items-center gap-1.5"
            >
              <span>📷</span>
              <span>{t('changeAvatar', $currentLang)}</span>
            </button>
            {#if newAvatar}
              <button 
                type="button" 
                on:click={removeAvatar} 
                class="px-3 py-1.5 rounded-xl bg-zinc-800 hover:bg-rose-500/20 text-zinc-400 hover:text-rose-300 border border-zinc-700 text-xs font-medium transition"
              >
                {t('removeAvatar', $currentLang)}
              </button>
            {/if}
          </div>

          <div>
            <label for="edit-user-name" class="block text-xs text-zinc-400 mb-1">{t('displayName', $currentLang)}</label>
            <input 
              id="edit-user-name"
              bind:value={newUsername} 
              class="input-field"
            />
          </div>
          <div>
            <label for="edit-user-bio" class="block text-xs text-zinc-400 mb-1">{t('bio', $currentLang)}</label>
            <textarea 
              id="edit-user-bio"
              bind:value={newBio} 
              rows="3"
              class="input-field resize-none leading-relaxed"
            ></textarea>
          </div>
          <div class="flex gap-2 pt-1">
            <button type="button" on:click={saveProfile} class="btn-primary flex-1 py-2 text-xs font-bold">
              {t('saveChanges', $currentLang)}
            </button>
            <button type="button" on:click={() => isEditing = false} class="btn-secondary py-2 text-xs">
              {t('cancel', $currentLang)}
            </button>
          </div>
        </div>
      {/if}

      {#if saveMsg}
        <div class="mt-3 text-xs text-indigo-400 font-medium animate-pulse text-center">{saveMsg}</div>
      {/if}
    </div>
  </div>

  <!-- Stats Grid -->
  <div class="grid grid-cols-2 gap-2.5 px-1">
    <div class="card p-3 text-center border border-zinc-800">
      <div class="text-xs text-zinc-500 font-medium">{t('myPosts', $currentLang)}</div>
      <div class="text-xl font-black text-zinc-100 mt-1">{userPosts.length}</div>
    </div>
    <div class="card p-3 text-center border border-zinc-800">
      <div class="text-xs text-zinc-500 font-medium">LibSQL State</div>
      <div class="text-xs font-bold text-emerald-400 mt-2 font-mono">Synchronized ✓</div>
    </div>
  </div>

  <!-- User Posts Section -->
  <div class="space-y-2.5 px-1">
    <h3 class="font-bold text-sm text-zinc-300 pr-1">{t('myPosts', $currentLang)} ({userPosts.length})</h3>
    {#each userPosts as post}
      <div class="card p-4 border border-zinc-800 space-y-2.5">
        <div class="flex items-center justify-between text-xs text-zinc-500 font-mono">
          <span class="font-bold text-zinc-300">@{profile.username || 'me'}</span>
          <span>{post.time || ''}</span>
        </div>
        {#if post.content}
          <p class="text-zinc-200 text-sm leading-relaxed whitespace-pre-wrap">{post.content}</p>
        {/if}

        <!-- Post Image Attachment in User Profile -->
        {#if getPostMedia(post)}
          <div class="rounded-2xl overflow-hidden border border-zinc-800 bg-zinc-950">
            <img 
              src={getPostMedia(post)} 
              alt="media" 
              class="w-full max-h-80 object-cover block"
              loading="lazy"
              on:error={(e) => { e.currentTarget.parentElement.style.display = 'none' }}
            />
          </div>
        {/if}

        <div class="text-zinc-500 flex items-center gap-2 text-xs pt-1 border-t border-zinc-800/40">
          <span>❤️ {post.likes_count || 0}</span>
          <span>•</span>
          <span class="text-emerald-400 font-mono">LibSQL on-chain ✓</span>
        </div>
      </div>
    {:else}
      <div class="card p-8 text-center text-zinc-500 text-xs border border-zinc-800">
        {t('noUserPosts', $currentLang)}
      </div>
    {/each}
  </div>
</div>
