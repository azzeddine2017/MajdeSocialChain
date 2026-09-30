import { writable, derived } from 'svelte/store'

// Available languages
export const LANGUAGES = ['ar', 'en']

// Safe in-memory storage fallback for WebView sandboxes where localStorage access throws SecurityError
const memoryStore = {}

function safeGet(key, fallback) {
  try {
    if (typeof window !== 'undefined' && 'localStorage' in window) {
      const val = window.localStorage.getItem(key)
      if (val !== null && val !== undefined) return val
    }
  } catch (e) {
    // SecurityError: Access is denied in WebView setHtml origin
  }
  return memoryStore[key] !== undefined ? memoryStore[key] : fallback
}

function safeSet(key, value) {
  try {
    if (typeof window !== 'undefined' && 'localStorage' in window) {
      window.localStorage.setItem(key, value)
    }
  } catch (e) {
    // SecurityError: Access is denied in WebView setHtml origin
  }
  memoryStore[key] = value
}

// Stored preferences with safe fallback
const savedLang = safeGet('mejde_lang', 'ar')
const savedTheme = safeGet('mejde_theme', 'oled')

export const currentLang = writable(savedLang)
export const currentTheme = writable(savedTheme)

// Translations dictionary
export const translations = {
  ar: {
    // App Branding
    appName: 'Mejde',
    appSub: 'مجد - شبكة اجتماعية لامركزية حرة',
    networkLive: 'الشبكة متصلة',
    onChainVerified: 'موثق على السلسلة ✓',

    // Navigation & Tabs
    tabFeed: 'الرئيسية',
    tabWallet: 'المحفظة',
    tabProfile: 'حسابي',
    tabTrends: 'المواضيع الرائجة',

    // Wallet & Tokens
    tokenName: 'عملة الولاء (WALA)',
    tokenSymbol: 'WALA',
    availableBalance: 'الرصيد المتاح في المحفظة',
    claimFaucet: 'صنبور العملات (+50 WALA)',
    claiming: 'جاري الصرف...',
    sendCoins: 'تحويل فوري',
    refreshChain: 'تحديث السلسلة',
    recipientAddress: 'معرّف المحفظة أو اسم المستلم',
    amountToSend: 'المبلغ المطلوب إرساله',
    signAndSend: 'توقيع وإرسال المعاملة ⚡',
    txHistory: 'سجل المعاملات',
    noTxs: 'لا توجد معاملات بعد',
    feeZero: 'رسوم: 0 WALA',
    faucetSource: 'صنبور الشبكة (Genesis Faucet)',
    txConfirmed: 'مؤكدة ✓',
    ikhlasUnit: 'إخلاص (الوحدة الصغرى)',
    ikhlasRate: '1 ولاء = 1,000,000 إخلاص',
    buyWala: 'شراء عملة الولاء ⚡',
    instantBuy: 'شراء فوري',
    p2pMarket: 'سوق الند للند (P2P Escrow)',
    usdtSwap: 'شراء فوري عبر USDT',
    depositUsdtDesc: 'ادفع بـ USDT (شبكة TRC20 أو Polygon) واستلم عملات WALA فوراً في محفظتك بمعدل 1 USDT = 10 WALA.',
    p2pDesc: 'شراء آمن ومحمي بنظام الضمان الذكي من وسطاء ومجتمع مَجْد بالعملة المحلية.',
    exchangeRateLabel: 'سعر الصرف المعتمد:',
    usdtRateValue: '1 USDT = 10 WALA',

    // Post Composer
    composePlaceholder: 'ماذا يدور في ذهنك؟ شارك المجتمع أفكارك الحرة...',
    publish: 'نشر 🚀',
    publishing: 'جاري النشر...',
    attachMedia: 'إرفاق وسائط أو IPFS CID',
    digitalSignature: 'توقيع رقمي محلي',

    // Feed & Interactions
    noPostsYet: 'لا توجد منشورات حتى الآن',
    noPostsSub: 'كن أول من ينشر محتوى حراً ومكافئاً على Mejde!',
    tipAction: 'إكرامية 5',
    tipSuccess: 'تم إرسال إكرامية 5 WALA بنجاح! 💎',
    selfTipError: 'لا يمكنك إرسال إكرامية لنفسك!',
    repost: 'إعادة نشر',
    comment: 'تعليق',
    writeReply: 'اكتب رداً على هذا المنشور...',
    sendReply: 'رد',
    noCommentsYet: 'لا توجد ردود بعد، كن أول من يشارك!',

    // Profile
    editProfile: 'تعديل الملف ✏️',
    cancel: 'إلغاء',
    saveChanges: 'حفظ التعديلات',
    displayName: 'الاسم المعروض',
    bio: 'النبذة التعريفية (Bio)',
    myPosts: 'منشوراتي',
    noUserPosts: 'لم تنشر أي محتوى بعد',
    activeNode: '🟢 عقدة نشطة',
    secureWallet: '🔐 محفظة مؤكدة',
    idCopied: 'تم نسخ المعرّف إلى الحافظة! 📋',
    changeAvatar: 'تغيير الصورة الشخصية 📷',
    removeAvatar: 'إزالة الصورة',
    avatarUpdated: 'تم تحديث الصورة الشخصية بنجاح!',
    selectAvatar: 'اختر صورة من جهازك',

    // Wallet Onboarding
    createAccount: 'إنشاء حساب ومحفظة جديدة',
    unlockAccount: 'فتح محفظة مسجلة مسبقاً',
    enterPassword: 'أدخل كلمة المرور',
    passwordMin: 'كلمة المرور (8+ أحرف)',
    confirmPassword: 'تأكيد كلمة المرور',
    pwdMismatch: 'كلمتا المرور غير متطابقتين',
    pwdWeak: 'ضعيفة',
    pwdMedium: 'متوسطة',
    pwdStrong: 'قوية وممتازة 🛡️',
    createAndSecure: 'إنشاء وتأمين 🛡️',
    unlockWallet: 'دخول 🔓',
    securityNote: 'يتم تشفير مفتاحك الخاص محلياً عبر AES-256. لا يمكن استعادة المحفظة في حال نسيان كلمة المرور.',
    feature1: 'بياناتك ومفاتيحك ملكك وحدك ومشفرة محلياً',
    feature2: 'بدون وسطاء أو خوادم مركزية تتجسس عليك',
    feature3: 'محفظة وهوية رقمية لا مركزية مدمجة',

    // Themes & Settings
    themeOled: 'OLED أسود',
    themeCyber: 'Cyber كحلي',

    // Widgets & Telemetry
    trendingInMejde: 'رائج في مجد',
    interactionsCount: 'تفاعل',
    loyaltyEconomy: 'اقتصاد الولاء',
    txsCount: 'معاملة',
    nodeStatus: 'حالة العقدة',
    nodeSynced: 'Synchronized ✓',
    nodeDescription: 'قاعدة بيانات LibSQL المصاحبة نشطة ومتزامنة بدون الحاجة لخوادم IPFS وسيطة.',

    // Phase 2: Merit & 12 Words & Follows
    tabMerit: 'الجدارة ⭐',
    tabLatest: 'الأحدث 🕒',
    tabFollowing: 'الاشتراكات 👥',
    mnemonicTitle: 'عبارة الاسترداد السرية (12 كلمة)',
    mnemonicWarning: 'احفظ هذه الكلمات الـ 12 في مكان آمن. هي الطريقة الوحيدة لاستعادة حسابك على أي جهاز آخر!',
    copyMnemonic: 'نسخ الكلمات الـ 12 📋',
    mnemonicCopied: 'تم نسخ الكلمات الـ 12 بنجاح!',
    iSavedMnemonic: 'لقد حفظت الكلمات بأمان ✓',
    recoverWithMnemonic: 'استرداد عبر الكلمات الـ 12 🔑',
    enterMnemonic: 'أدخل الكلمات الـ 12 مفصولة بمسافة',
    restoreAccount: 'استعادة الحساب 🚀',
    follow: 'متابعة',
    following: 'متابَع ✓',
    unfollow: 'إلغاء المتابعة',
    followers: 'المتابعون',
    followingCount: 'تتابع',
    uploadImage: 'صورة من الجهاز',
    dailyQuota: 'الحصة اليومية (مكافحة السبام)',
    quotaRemaining: 'منشور متبقٍ اليوم',
    score: 'نقاط الجدارة',

    // Staking & Smart Contracts
    tabStaking: 'الرهن ومكافحة السبام 🛡️',
    stakedBalance: 'الرصيد المرهون',
    currentQuota: 'الحصة اليومية للنشر',
    postsPerDay: 'منشور / يوم',
    stakeWala: 'رهن WALA لزيادة الحصة',
    unstakeWala: 'إلغاء الرهن واسترجاع',
    stakeAmount: 'الكمية المراد رهنها',
    unstakeAmount: 'الكمية المراد فك رهنها',
    stakeBtn: 'قفل ورهن 🛡️',
    unstakeBtn: 'فك الرهن 🔓',
    stakeSuccess: 'تم رهن العملات بنجاح وزيادة حصتك اليومية! 🛡️',
    unstakeSuccess: 'تم فك رهن العملات واسترجاعها إلى محفظتك! 🔓',
    stakingDesc: 'كل 10 WALA مرهونة تمنحك +1 منشور يومياً فوق الحد الأساسي (25 منشور/يوم)، وتزيد من موثوقية تقييماتك في خوارزمية الجدارة (نموذج Bastyon/Pocketnet).',

    // Phase 4: Messaging & Notifications
    tabMessages: 'الرسائل 💬',
    messages: 'المحادثات',
    noConversations: 'لا توجد محادثات بعد',
    noMessages: 'لا توجد رسائل في هذه المحادثة',
    typeMessage: 'اكتب رسالتك المشفرة هنا...',
    sendMessage: 'إرسال',
    e2eEncrypted: 'مشفرة من الطرفين (E2EE) 🔐',
    newConversation: 'محادثة جديدة',
    recipientId: 'معرّف المستلم',
    tabNotifications: 'الإشعارات 🔔',
    notifications: 'الإشعارات',
    noNotifications: 'لا توجد إشعارات',
    markAllRead: 'تحديد الكل كمقروء',
    notifRating: 'تقييم جديد ⭐',
    notifComment: 'تعليق جديد 💬',
    notifFollow: 'متابع جديد 👥',
    notifTip: 'إكرامية جديدة 💰',
    notifMessage: 'رسالة جديدة 📩',
    notifReward: 'مكافأة عقدة 🖥️',

    // Phase 5: Node Status
    tabNode: 'لوحة العقدة 🖥️',
    nodePanel: 'لوحة تحكم العقدة',
    claimNodeReward: 'استلام مكافأة تشغيل العقدة',
    claiming: 'جاري الاستلام...',
    nodeId: 'معرّف العقدة',
    blocksCount: 'إجمالي الكتل',
    usersCount: 'المستخدمون',
    postsCount: 'المنشورات',
    txsOnChain: 'المعاملات على السلسلة',
    networkName: 'الشبكة',
    nodeVersion: 'الإصدار',
    syncStatus: 'حالة المزامنة',
    logout: 'تسجيل الخروج',
    p2pNetwork: 'شبكة الأقران (P2P Gossip Network)',
    p2pPort: 'منفذ الاستماع المحلي',
    syncNow: 'مزامنة فورية الآن',
    syncing: 'جاري المزامنة مع الأقران...',
    addPeer: 'إضافة نظير',
    peerPlaceholder: 'http://127.0.0.1:8546 أو IP النود',
    connectedPeers: 'النظراء المسجلون',
    noPeers: 'لا توجد نودز مسجلة حالياً',
    statusSynced: 'متزامن ومتصل ✓',
    statusSyncing: 'جاري التبادل...',
    statusStandalone: 'يعمل منفرداً (Standalone)',

    // Economy & Mother Node
    motherNodeRefill: 'تعبئة من النود الأم ⚡',
    motherNodeTitle: 'النود الأولى (الأم)',
    motherNodeDesc: 'المنبع الرئيسي لاقتصاد عملة الولاء WALA',
    peerNodeTitle: 'نود فرعية / نظيرة',
    requestFromMother: 'طلب رصيد من النود الأم',
    motherUrlLabel: 'رابط النود الأم (Genesis Node URL)',
    circulationTitle: 'دورة تداول العملة الحقيقية 🔄',
    circulationDesc: 'العملة لا تُخلق عشوائياً بل تتداول عبر الإرسال المباشر، مكافآت جودة المحتوى، ورهن العملات لمقاومة البوتات.',
    hideMockFaucet: 'إلغاء الصنبور التجريبي (اعتماد التداول الحقيقي)',
    showMockFaucet: 'إظهار الصنبور التجريبي',
    refillSuccess: 'تم استلام رصيد التعبئة بنجاح من النود الأم! 🚀',
    refillError: 'تعذر الاتصال بالنود الأم، تأكد من تشغيلها.',
    refilling: 'جاري طلب التعبئة...',

    // Messenger Upgrades
    searchChat: 'بحث في المحادثات...',
    allChats: 'الكل',
    unreadChats: 'غير مقروءة',
    directChats: 'مباشر',
    onlineStatus: 'متصل الآن • عقدة P2P',
    sendWalaTip: 'إرسال WALA 💰',
    tipUserTitle: 'إرسال WALA إلى المحادثة',
    tipSentSuccess: 'تم إرسال الهدية بنجاح في المحادثة! 🎁',
    quickReactions: 'تفاعلات سريعة',
    backToChats: 'رجوع للمحادثات',
    typeMessage: 'اكتب رسالة مشفرة...',
    today: 'اليوم'
  },

  en: {
    // App Branding
    appName: 'Mejde',
    appSub: 'Decentralized Sovereign Social Network',
    networkLive: 'Mainnet Live',
    onChainVerified: 'On-chain verified ✓',

    // Navigation & Tabs
    tabFeed: 'Home',
    tabWallet: 'Wallet',
    tabProfile: 'Profile',
    tabTrends: 'Trending',

    // Wallet & Tokens
    tokenName: 'WalaCoin (WALA)',
    tokenSymbol: 'WALA',
    availableBalance: 'Available Wallet Balance',
    claimFaucet: 'Claim Faucet (+50 WALA)',
    claiming: 'Claiming...',
    sendCoins: 'Instant Send',
    refreshChain: 'Refresh Chain',
    recipientAddress: 'Recipient User ID or Address',
    amountToSend: 'Amount to Send',
    signAndSend: 'Sign & Broadcast ⚡',
    txHistory: 'Transaction Ledger',
    noTxs: 'No transactions recorded yet',
    feeZero: 'Fee: 0 WALA',
    faucetSource: 'Genesis Faucet',
    txConfirmed: 'Confirmed ✓',
    ikhlasUnit: 'Ikhlas (Sub-unit)',
    ikhlasRate: '1 WALA = 1,000,000 Ikhlas',
    buyWala: 'Buy WalaCoin ⚡',
    instantBuy: 'Instant Buy',
    p2pMarket: 'P2P Escrow Market',
    usdtSwap: 'Instant Buy via USDT',
    depositUsdtDesc: 'Pay with USDT (TRC20 / Polygon) and receive WALA directly into your wallet at 1 USDT = 10 WALA.',
    p2pDesc: 'Buy securely with local currency protected by smart on-chain escrow from verified desks.',
    exchangeRateLabel: 'Exchange Rate:',
    usdtRateValue: '1 USDT = 10 WALA',

    // Post Composer
    composePlaceholder: "What's happening? Share uncensored thoughts on Mejde...",
    publish: 'Post 🚀',
    publishing: 'Posting...',
    attachMedia: 'Attach Media / IPFS CID',
    digitalSignature: 'Local Digital Signature',

    // Feed & Interactions
    noPostsYet: 'No posts yet',
    noPostsSub: 'Be the first to share rewarding sovereign content on Mejde!',
    tipAction: 'Tip 5',
    tipSuccess: 'Successfully tipped 5 WALA! 💎',
    selfTipError: 'Cannot tip your own post!',
    repost: 'Repost',
    comment: 'Comment',
    writeReply: 'Write a response...',
    sendReply: 'Reply',
    noCommentsYet: 'No comments yet. Join the conversation!',

    // Profile
    editProfile: 'Edit Profile ✏️',
    cancel: 'Cancel',
    saveChanges: 'Save Changes',
    displayName: 'Display Name',
    bio: 'Bio',
    myPosts: 'My Posts',
    noUserPosts: 'No posts published yet',
    activeNode: '🟢 Node Synchronized',
    secureWallet: '🔐 Verified Identity',
    idCopied: 'User ID copied to clipboard! 📋',
    changeAvatar: 'Change Avatar 📷',
    removeAvatar: 'Remove Avatar',
    avatarUpdated: 'Avatar updated successfully!',
    selectAvatar: 'Select an image from device',

    // Wallet Onboarding
    createAccount: 'Create New Sovereign Wallet',
    unlockAccount: 'Unlock Existing Wallet',
    enterPassword: 'Enter Password',
    passwordMin: 'Password (8+ chars)',
    confirmPassword: 'Confirm Password',
    pwdMismatch: 'Passwords do not match',
    pwdWeak: 'Weak',
    pwdMedium: 'Medium',
    pwdStrong: 'Strong & Secure 🛡️',
    createAndSecure: 'Generate & Secure 🛡️',
    unlockWallet: 'Unlock 🔓',
    securityNote: 'Your private key is encrypted locally with AES-256. Lost passwords cannot be recovered.',
    feature1: 'Self-custodial keys & data encrypted locally',
    feature2: 'Zero corporate intermediaries or surveillance',
    feature3: 'Integrated decentralized identity & wallet',

    // Themes & Settings
    themeOled: 'OLED Midnight',
    themeCyber: 'Cyber Dark',

    // Widgets & Telemetry
    trendingInMejde: 'Trending on Mejde',
    interactionsCount: 'interactions',
    loyaltyEconomy: 'Loyalty Economy',
    txsCount: 'transactions',
    nodeStatus: 'Node Status',
    nodeSynced: 'Synchronized ✓',
    nodeDescription: 'LibSQL companion database active and replicated without third-party IPFS gateways.',

    // Phase 2: Merit & 12 Words & Follows
    tabMerit: 'Merit ⭐',
    tabLatest: 'Latest 🕒',
    tabFollowing: 'Following 👥',
    mnemonicTitle: 'Secret Recovery Phrase (12 Words)',
    mnemonicWarning: 'Save these 12 words in a safe place. They are the ONLY way to restore your identity on another device!',
    copyMnemonic: 'Copy 12 Words 📋',
    mnemonicCopied: '12 Words copied successfully!',
    iSavedMnemonic: 'I have safely backed up my phrase ✓',
    recoverWithMnemonic: 'Restore via 12-Word Phrase 🔑',
    enterMnemonic: 'Enter your 12 words separated by spaces',
    restoreAccount: 'Restore Account 🚀',
    follow: 'Follow',
    following: 'Following ✓',
    unfollow: 'Unfollow',
    followers: 'Followers',
    followingCount: 'Following',
    uploadImage: 'Upload Image',
    dailyQuota: 'Daily Quota (Anti-Bot)',
    quotaRemaining: 'posts left today',
    score: 'Merit Score',

    // Staking & Smart Contracts
    tabStaking: 'Staking & Anti-Bot 🛡️',
    stakedBalance: 'Staked Balance',
    currentQuota: 'Daily Post Quota',
    postsPerDay: 'posts / day',
    stakeWala: 'Stake WALA (Boost Quota)',
    unstakeWala: 'Unstake WALA',
    stakeAmount: 'Amount to Stake',
    unstakeAmount: 'Amount to Unstake',
    stakeBtn: 'Stake WALA 🛡️',
    unstakeBtn: 'Unstake 🔓',
    stakeSuccess: 'WALA staked successfully! Daily quota boosted. 🛡️',
    unstakeSuccess: 'WALA unstaked and returned to your wallet. 🔓',
    stakingDesc: 'Every 10 WALA staked grants +1 additional post per day above the free tier (25 posts/day) and increases your rating weight in the decentralized merit algorithm.',

    // Phase 4: Messaging & Notifications
    tabMessages: 'Messages 💬',
    messages: 'Conversations',
    noConversations: 'No conversations yet',
    noMessages: 'No messages in this conversation',
    typeMessage: 'Type your encrypted message...',
    sendMessage: 'Send',
    e2eEncrypted: 'End-to-End Encrypted (E2EE) 🔐',
    newConversation: 'New Conversation',
    recipientId: 'Recipient ID',
    tabNotifications: 'Notifications 🔔',
    notifications: 'Notifications',
    noNotifications: 'No notifications yet',
    markAllRead: 'Mark All as Read',
    notifRating: 'New Rating ⭐',
    notifComment: 'New Comment 💬',
    notifFollow: 'New Follower 👥',
    notifTip: 'New Tip 💰',
    notifMessage: 'New Message 📩',
    notifReward: 'Node Reward 🖥️',

    // Phase 5: Node Status
    tabNode: 'Node Panel 🖥️',
    nodePanel: 'Node Control Panel',
    claimNodeReward: 'Claim Node Operator Reward',
    claiming: 'Claiming...',
    nodeId: 'Node ID',
    blocksCount: 'Total Blocks',
    usersCount: 'Users',
    postsCount: 'Posts',
    txsOnChain: 'Transactions On-Chain',
    networkName: 'Network',
    nodeVersion: 'Version',
    syncStatus: 'Sync Status',
    logout: 'Logout',
    p2pNetwork: 'P2P Gossip Network',
    p2pPort: 'Local Listening Port',
    syncNow: 'Sync Now',
    syncing: 'Syncing with peers...',
    addPeer: 'Add Peer',
    peerPlaceholder: 'http://127.0.0.1:8546 or Node IP',
    connectedPeers: 'Connected Peers',
    noPeers: 'No peer nodes registered yet',
    statusSynced: 'Synced & Connected ✓',
    statusSyncing: 'Exchanging data...',
    statusStandalone: 'Standalone Node',

    // Economy & Mother Node
    motherNodeRefill: 'Mother Node Refill ⚡',
    motherNodeTitle: 'Genesis Mother Node',
    motherNodeDesc: 'Origin of WalaCoin circulation and reserves',
    peerNodeTitle: 'Peer / Child Node',
    requestFromMother: 'Request Balance from Mother Node',
    motherUrlLabel: 'Mother Node URL',
    circulationTitle: 'Real Circulation Economy 🔄',
    circulationDesc: 'Coins are not created arbitrarily; they circulate through direct P2P transfers, merit rating rewards, and staking.',
    hideMockFaucet: 'Disable Mock Faucet (Enforce Real Circulation)',
    showMockFaucet: 'Show Mock Faucet',
    refillSuccess: 'Successfully received refill from Mother Node! 🚀',
    refillError: 'Could not connect to Mother Node. Ensure it is running.',
    refilling: 'Requesting refill...',

    // Messenger Upgrades
    searchChat: 'Search conversations...',
    allChats: 'All',
    unreadChats: 'Unread',
    directChats: 'Direct',
    onlineStatus: 'Online • P2P Node',
    sendWalaTip: 'Send WALA 💰',
    tipUserTitle: 'Send WALA to Contact',
    tipSentSuccess: 'Tip sent successfully in conversation! 🎁',
    quickReactions: 'Quick Reactions',
    backToChats: 'Back to Chats',
    typeMessage: 'Type an encrypted message...',
    today: 'Today'
  }
}

// Helper translation function
export function t(key, lang = 'ar') {
  return translations[lang]?.[key] || translations['ar']?.[key] || key
}

// Function to switch language and update document attributes
export function setLanguage(newLang) {
  currentLang.set(newLang)
  safeSet('mejde_lang', newLang)
  if (typeof document !== 'undefined') {
    document.documentElement.lang = newLang
    document.documentElement.dir = (newLang === 'ar' ? 'rtl' : 'ltr')
  }
}

// Function to switch theme
export function setTheme(newTheme) {
  currentTheme.set(newTheme)
  safeSet('mejde_theme', newTheme)
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', newTheme)
  }
}
