<script>
  import { createEventDispatcher } from 'svelte'
  import { currentLang, t } from './i18n.js'
  const dispatch = createEventDispatcher()
  export let posts = []
  export let activeFilter = 'latest'

  let expandedComments = {} 
  let commentsMap = {}      
  let commentInputs = {}    
  let tipMessages = {}      
  let likedPosts = {} 
  let ratedPosts = {}
  let followedAuthors = {}

  async function handleFollow(authorId) {
    if (!authorId || authorId === 'me') return
    const isFollowed = followedAuthors[authorId]
    followedAuthors[authorId] = !isFollowed
    followedAuthors = { ...followedAuthors }
    try {
      if (isFollowed) {
        if (window.unfollowUser) await window.unfollowUser('me', authorId)
      } else {
        if (window.followUser) await window.followUser('me', authorId)
      }
    } catch (e) {
      console.error('Follow error:', e)
    }
  }

  function changeFilter(filter) {
    activeFilter = filter
    dispatch('filterChanged', filter)
  }

  async function handleRate(post, stars) {
    ratedPosts[post.id] = stars
    ratedPosts = { ...ratedPosts }
    try {
      if (window.ratePost && post.id) {
        await window.ratePost('me', post.id, stars)
      }
    } catch (e) {
      console.error('Rate error:', e)
    }
  } 

  async function handleLike(post) {
    if (post.isLiking) return
    post.isLiking = true
    const isAlreadyLiked = likedPosts[post.id]
    
    // Optimistic UI update
    likedPosts[post.id] = !isAlreadyLiked
    likedPosts = { ...likedPosts }
    post.likes_count = (Number(post.likes_count) || 0) + (isAlreadyLiked ? -1 : 1)
    posts = [...posts]

    try {
      if (window.likePost && post.id) {
        await window.likePost('me', post.id)
      }
    } catch (e) {
      console.error('Like error:', e)
    } finally {
      post.isLiking = false
    }
  }

  async function toggleComments(postId) {
    expandedComments[postId] = !expandedComments[postId]
    expandedComments = { ...expandedComments }
    if (expandedComments[postId] && !commentsMap[postId]) {
      await loadComments(postId)
    }
  }

  async function loadComments(postId) {
    try {
      if (window.getComments) {
        let res = await window.getComments(postId)
        if (typeof res === 'string') {
          try { res = JSON.parse(res) } catch (e) {}
        }
        if (Array.isArray(res)) {
          commentsMap[postId] = res.map(item => {
            if (Array.isArray(item) && item.length > 0 && Array.isArray(item[0])) {
              const obj = {}
              item.forEach(pair => { if (Array.isArray(pair)) obj[pair[0]] = pair[1] })
              return obj
            }
            return item
          })
          commentsMap = { ...commentsMap }
        }
      }
    } catch (e) {
      console.error('Error loading comments:', e)
    }
  }

  async function addComment(postId) {
    const text = (commentInputs[postId] || '').trim()
    if (!text) return
    try {
      if (window.addComment) {
        await window.addComment('me', postId, text)
        commentInputs[postId] = ''
        commentInputs = { ...commentInputs }
        await loadComments(postId)
      }
    } catch (e) {
      console.error('Error adding comment:', e)
    }
  }

  async function tipPost(post, amount = 5) {
    if (!post.author || post.author === 'me') {
      tipMessages[post.id] = t('selfTipError', $currentLang)
      tipMessages = { ...tipMessages }
      setTimeout(() => { delete tipMessages[post.id]; tipMessages = { ...tipMessages } }, 2500)
      return
    }
    try {
      if (window.createTransaction) {
        await window.createTransaction('me', post.author, amount)
        tipMessages[post.id] = t('tipSuccess', $currentLang)
        tipMessages = { ...tipMessages }
        dispatch('balanceChanged')
        setTimeout(() => { delete tipMessages[post.id]; tipMessages = { ...tipMessages } }, 3000)
      }
    } catch (e) {
      tipMessages[post.id] = 'Error: ' + (e.message || 'Balance insufficient')
      tipMessages = { ...tipMessages }
      setTimeout(() => { delete tipMessages[post.id]; tipMessages = { ...tipMessages } }, 3000)
    }
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
</script>

<!-- Feed Category Filter Tabs -->
<div class="flex items-center gap-1.5 px-3 py-1.5 border-b border-zinc-800/60 bg-zinc-950/40 backdrop-blur-md sticky top-[48px] md:top-0 z-30 mb-2">
  <button 
    type="button" 
    on:click={() => changeFilter('latest')}
    class="flex-1 py-1.5 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 {activeFilter === 'latest' ? 'bg-indigo-600/20 text-indigo-300 border border-indigo-500/30' : 'text-zinc-400 hover:text-zinc-200'}"
  >
    <span>🕒</span>
    <span>{t('tabLatest', $currentLang)}</span>
  </button>
  <button 
    type="button" 
    on:click={() => changeFilter('merit')}
    class="flex-1 py-1.5 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 {activeFilter === 'merit' ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30' : 'text-zinc-400 hover:text-zinc-200'}"
  >
    <span>⭐</span>
    <span>{t('tabMerit', $currentLang)}</span>
  </button>
  <button 
    type="button" 
    on:click={() => changeFilter('following')}
    class="flex-1 py-1.5 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5 {activeFilter === 'following' ? 'bg-purple-600/20 text-purple-300 border border-purple-500/30' : 'text-zinc-400 hover:text-zinc-200'}"
  >
    <span>👥</span>
    <span>{t('tabFollowing', $currentLang)}</span>
  </button>
</div>

<div class="space-y-3 px-3 pb-6">
  {#each posts as post (post.id || Math.random())}
    <article class="card p-4 border border-zinc-800/80 hover:border-zinc-700/80 transition-all duration-200 shadow-lg">
      <!-- Post Author Header -->
      <div class="flex items-center justify-between mb-2.5">
        <div class="flex items-center gap-2.5 min-w-0">
          <!-- Avatar with dynamic gradient or custom photo -->
          {#if post.author_avatar && (post.author_avatar.startsWith('data:') || post.author_avatar.startsWith('http'))}
            <img src={post.author_avatar} alt="avatar" class="w-10 h-10 rounded-full object-cover border border-indigo-500/40 shrink-0 shadow-md" />
          {:else}
            <div class="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-600 via-purple-600 to-pink-500 flex items-center justify-center text-xs font-black text-white shrink-0 shadow-md">
              {(post.author || 'ME').slice(0, 2).toUpperCase()}
            </div>
          {/if}
          
          <div class="min-w-0">
            <div class="flex items-center gap-1.5 leading-tight">
              <span class="font-bold text-sm text-zinc-100 truncate hover:text-indigo-400 transition cursor-pointer">
                {post.author || 'User'}
              </span>
              <span class="text-indigo-400 text-xs" title={t('onChainVerified', $currentLang)}>✓</span>
            </div>
            <div class="flex items-center gap-1.5 text-[11px] text-zinc-500 mt-0.5 font-mono">
              <span class="truncate max-w-[120px]">@{post.author || 'anon'}</span>
              <span>•</span>
              <span>{post.time || 'now'}</span>
              {#if post.merit_score && post.merit_score > 0}
                <span class="text-[10px] px-1.5 py-0.2 rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20 font-bold">
                  ⭐ {Math.round(post.merit_score)}
                </span>
              {/if}
            </div>
          </div>
        </div>

        <div class="flex items-center gap-1.5">
          <!-- Follow User Button -->
          {#if post.author && post.author !== 'me'}
            <button 
              type="button" 
              on:click|stopPropagation={() => handleFollow(post.author)}
              class="text-[10px] font-bold px-2.5 py-1 rounded-full border transition {followedAuthors[post.author] ? 'border-emerald-500/40 bg-emerald-500/10 text-emerald-400' : 'border-zinc-700 bg-zinc-800/80 text-zinc-300 hover:border-indigo-500/50'}"
            >
              {followedAuthors[post.author] ? t('following', $currentLang) : t('follow', $currentLang)}
            </button>
          {/if}

          <!-- Quick Tip Button -->
          <button 
            type="button"
            on:click={() => tipPost(post, 5)}
            class="px-2.5 py-1 rounded-full bg-gradient-to-r from-amber-500/10 to-amber-600/10 hover:from-amber-500/20 hover:to-amber-600/20 text-amber-300 border border-amber-500/30 text-xs font-bold transition-all active:scale-95 flex items-center gap-1 shrink-0"
            title="Send 5 WALA tip"
          >
            <span>🪙</span>
            <span>{t('tipAction', $currentLang)}</span>
          </button>
        </div>
      </div>

      <!-- Tip Status Message -->
      {#if tipMessages[post.id]}
        <div class="mb-2.5 px-3 py-1.5 rounded-xl text-xs bg-indigo-950/70 border border-indigo-500/40 text-indigo-200 animate-pulse text-center">
          {tipMessages[post.id]}
        </div>
      {/if}

      <!-- Post Text Content -->
      <div class="text-[14px] leading-relaxed text-zinc-200 whitespace-pre-wrap pr-1 pl-1">
        {post.content}
      </div>

      <!-- Media Attachment if exists -->
      {#if getPostMedia(post)}
        <div class="mt-3 rounded-2xl overflow-hidden border border-zinc-800 bg-zinc-950">
          <img 
            src={getPostMedia(post)} 
            alt="media" 
            class="w-full max-h-96 object-cover block hover:scale-[1.01] transition-transform duration-300"
            loading="lazy"
            on:error={(e) => { e.currentTarget.parentElement.style.display = 'none' }}
          />
        </div>
      {/if}

      <!-- Interaction Bar -->
      <div class="flex items-center justify-between mt-3.5 pt-2.5 border-t border-zinc-800/60 text-xs text-zinc-400">
        <!-- Like Button -->
        <button 
          type="button"
          on:click={() => handleLike(post)} 
          class="flex items-center gap-1.5 hover:text-rose-400 transition group p-1 -m-1"
        >
          <span class="text-base transition-transform group-hover:scale-125 {likedPosts[post.id] ? 'heart-pop' : ''}">
            {likedPosts[post.id] ? '❤️' : '🤍'}
          </span>
          <span class="font-semibold {likedPosts[post.id] ? 'text-rose-400 font-bold' : ''}">
            {post.likes_count || 0}
          </span>
        </button>

        <!-- Merit Star Rating (1-5 Stars) -->
        <div class="flex items-center gap-0.5 text-xs text-zinc-500 hover:text-amber-400 transition">
          {#each [1, 2, 3, 4, 5] as star}
            <button 
              type="button"
              class="hover:scale-125 transition-transform text-xs p-0.5 focus:outline-none"
              on:click|stopPropagation={() => handleRate(post, star)}
              title={`${star} / 5`}
            >
              {(ratedPosts[post.id] || 0) >= star ? '⭐' : '☆'}
            </button>
          {/each}
        </div>

        <!-- Comments Button -->
        <button 
          type="button"
          on:click={() => toggleComments(post.id)}
          class="flex items-center gap-1.5 hover:text-indigo-400 transition group p-1 -m-1"
        >
          <span class="text-base group-hover:scale-110 transition-transform">💬</span>
          <span class="font-semibold">
            {commentsMap[post.id] ? commentsMap[post.id].length : t('comment', $currentLang)}
          </span>
        </button>

        <!-- Repost Button -->
        <button 
          type="button"
          class="flex items-center gap-1.5 hover:text-emerald-400 transition group p-1 -m-1"
        >
          <span class="text-base group-hover:scale-110 transition-transform">🔁</span>
          <span class="font-semibold">{t('repost', $currentLang)}</span>
        </button>

        <!-- Share / Blockchain Verification Pill -->
        <div class="text-[10px] text-zinc-500 font-mono bg-zinc-900/60 px-2 py-0.5 rounded-full border border-zinc-800">
          LibSQL on-chain ✓
        </div>
      </div>

      <!-- Expandable Comments Drawer -->
      {#if expandedComments[post.id]}
        <div class="mt-3 pt-3 border-t border-zinc-800/80 space-y-2.5 bg-zinc-950/40 p-3 rounded-2xl border border-zinc-800/40">
          <!-- Comments List -->
          <div class="space-y-2 max-h-52 overflow-y-auto pr-1">
            {#if commentsMap[post.id] && commentsMap[post.id].length > 0}
              {#each commentsMap[post.id] as comment}
                <div class="bg-zinc-900/90 p-2.5 rounded-xl border border-zinc-800/60 text-xs">
                  <div class="flex items-center justify-between text-zinc-400 mb-1">
                    <span class="font-bold text-indigo-300">@{comment.user_id || 'user'}</span>
                    <span class="text-[10px] text-zinc-500 font-mono">{comment.created_at || ''}</span>
                  </div>
                  <div class="text-zinc-200 leading-relaxed">{comment.content}</div>
                </div>
              {/each}
            {:else}
              <div class="text-xs text-zinc-500 text-center py-2 font-medium">{t('noCommentsYet', $currentLang)}</div>
            {/if}
          </div>

          <!-- Add Comment Input -->
          <div class="flex gap-2 pt-1">
            <input 
              bind:value={commentInputs[post.id]}
              on:keydown={(e) => e.key === 'Enter' && addComment(post.id)}
              placeholder={t('writeReply', $currentLang)}
              class="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl px-3 py-1.5 text-xs text-zinc-100 outline-none focus:border-indigo-500"
            />
            <button 
              type="button"
              on:click={() => addComment(post.id)}
              class="px-3.5 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold transition active:scale-95 shrink-0"
            >
              {t('sendReply', $currentLang)}
            </button>
          </div>
        </div>
      {/if}
    </article>
  {:else}
    <div class="card p-12 text-center text-zinc-500 border border-zinc-800 my-4 shadow-xl">
      <div class="w-16 h-16 mx-auto mb-4 rounded-3xl bg-zinc-900 flex items-center justify-center text-3xl">
        📝
      </div>
      <h3 class="font-bold text-base text-zinc-300 mb-1">{t('noPostsYet', $currentLang)}</h3>
      <p class="text-xs text-zinc-500 max-w-xs mx-auto">{t('noPostsSub', $currentLang)}</p>
    </div>
  {/each}
</div>
