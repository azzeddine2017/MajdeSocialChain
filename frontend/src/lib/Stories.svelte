<script>
  const trendingTags = [
    { tag: '#SocialChain', count: '1.2K منشور', icon: '⛓️' },
    { tag: '#Web3_عربي', count: '840 منشور', icon: '🌐' },
    { tag: '#LibSQL', count: '510 منشور', icon: '⚡' },
    { tag: '#تشفير_محلي', count: '390 منشور', icon: '🛡️' },
    { tag: '#لامركزية', count: '920 منشور', icon: '🚀' }
  ]
</script>

<div class="px-3 pt-2 pb-1 overflow-x-auto scrollbar-hide flex gap-2 items-center">
  <!-- Live Network Status Pill -->
  <div class="shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-mono">
    <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
    <span class="font-bold">Mainnet Live</span>
  </div>

  <!-- Trending Tags -->
  {#each trendingTags as item}
    <div class="shrink-0 flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-zinc-900/80 hover:bg-zinc-850 border border-zinc-800 text-xs transition cursor-pointer text-zinc-300">
      <span>{item.icon}</span>
      <span class="font-bold text-indigo-300">{item.tag}</span>
      <span class="text-[10px] text-zinc-500">{item.count}</span>
    </div>
  {/each}
</div>
