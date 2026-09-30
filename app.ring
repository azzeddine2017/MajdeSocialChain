# SocialChain - WebView Desktop Entry

load "stdlibcore.ring"
try
    load "sockets.ring"
catch
done
try
    load "internetlib.ring"
catch
done
load "core/Database.ring"
load "webview.ring"

load "core/Model.ring"
load "core/Service.ring"
load "utils/Crypto_Internal.ring"
load "utils/Logger.ring"
load "utils/Crypto.ring"
load "utils/Validator.ring"
load "models/User.ring"
load "models/Post.ring"
load "models/Block.ring"
load "models/Transaction.ring"
load "blockchain/SmartContract.ring"
load "contracts/TokenContract.ring"
load "contracts/RewardContract.ring"
load "contracts/StakingContract.ring"
load "blockchain/ContractManager.ring"
load "services/MediaStorageService.ring"
load "services/PostService.ring"
load "services/BlockchainService.ring"
load "services/MessageService.ring"
load "services/P2PSyncService.ring"


# Global state
oDatabase = NULL
oCrypto = NULL
oView = NULL
oContractManager = NULL
oMessageService = NULL
oP2PService = NULL
oAppWorkerPool = NULL
cActiveUserId = ""
nP2PPort = 8546
cDbPath = "social.db"

# WebView return codes
WEBVIEW_ERROR_OK = 0
WEBVIEW_ERROR_ERROR = 1

# Single instance / thread re-entry guard
bMejdeMainStarted = false

# Define functions to expose to JavaScript
aBindList = [
    ["createWallet", :js_createWallet],
    ["unlockWallet", :js_unlockWallet],
    ["createPost", :js_createPost],
    ["getFeed", :js_getFeed],
    ["likePost", :js_likePost],
    ["addComment", :js_addComment],
    ["getComments", :js_getComments],
    ["getProfile", :js_getProfile],
    ["updateProfile", :js_updateProfile],
    ["getUserPosts", :js_getUserPosts],
    ["createTransaction", :js_createTransaction],
    ["getBalance", :js_getBalance],
    ["faucet", :js_faucet],
    ["getTransactions", :js_getTransactions],
    ["ratePost", :js_ratePost],
    ["recoverWallet", :js_recoverWallet],
    ["followUser", :js_followUser],
    ["unfollowUser", :js_unfollowUser],
    ["getFollowStats", :js_getFollowStats],
    ["stakeWala", :js_stakeWala],
    ["unstakeWala", :js_unstakeWala],
    ["getStakeInfo", :js_getStakeInfo],
    ["sendMessage", :js_sendMessage],
    ["getMessages", :js_getMessages],
    ["getConversations", :js_getConversations],
    ["getNotifications", :js_getNotifications],
    ["markNotificationsRead", :js_markNotificationsRead],
    ["getUnreadCount", :js_getUnreadCount],
    ["claimNodeReward", :js_claimNodeReward],
    ["getNodeStatus", :js_getNodeStatus],
    ["checkSession", :js_checkSession],
    ["logout", :js_logout],
    ["syncNow", :js_syncNow],
    ["getPeers", :js_getPeers],
    ["addPeer", :js_addPeer],
    ["requestMotherRefill", :js_requestMotherRefill],
    ["getBalanceInfo", :js_getBalanceInfo],
    ["buyWalaWithCrypto", :js_buyWalaWithCrypto],
    ["getP2POffers", :js_getP2POffers],
    ["createP2POffer", :js_createP2POffer],
    ["executeP2PBuy", :js_executeP2PBuy]
]

func getP2PService
    if isNull(oP2PService)
        try
            oP2PService = new P2PSyncService(oDatabase)
        catch
            see "Error creating P2PSyncService: " + cCatchError + nl
        done
    ok
    return oP2PService

func getMessageService
    if isNull(oMessageService)
        try
            oMessageService = new MessageService(oDatabase)
            oP2P = getP2PService()
            if not isNull(oP2P)
                oMessageService.setP2PService(oP2P)
            ok
        catch
            see "Error creating MessageService: " + cCatchError + nl
        done
    ok
    return oMessageService



# --- Main ---
func main
    if bMejdeMainStarted { return }
    bMejdeMainStarted = true

    # CLI args: [port] [db_file]
    # sysargv[1] = ring executable
    # sysargv[2] = app.ring
    # sysargv[3] = port (default 8546)
    # sysargv[4] = db_file (default social.db)
    if len(sysargv) >= 3 and sysargv[3] != "" {
        try { nP2PPort = number(sysargv[3]) catch nP2PPort = 8546 }
    }
    if len(sysargv) >= 4 and sysargv[4] != "" {
        cDbPath = sysargv[4]
    }

    # Init DB (local file or custom node db)
    oDatabase = new Database(cDbPath)
    oCrypto = new Crypto()
    oContractManager = new ContractManager("GENESIS_FAUCET", oDatabase)
    oP2PService = getP2PService()
    oMessageService = getMessageService()

    # Detect if Mother Node (8545) is running on localhost
    bMotherActive = false
    try {
        cStatus = oP2PService.httpGet("http://127.0.0.1:8545/p2p/status")
        if not isNull(cStatus) and cStatus != "" {
            bMotherActive = true
            see "[P2P] Mother Node probed successfully on 8545!" + nl
        }
    catch
        bMotherActive = false
    }

    # If port is 8545 and Mother Node is already active externally, switch to 8546
    if nP2PPort = 8545 and bMotherActive {
        nP2PPort = 8546
        see "[P2P] Mother Node detected on 8545. app.ring configured as Peer on port " + string(nP2PPort) + nl
    }

    oP2PService.setMyUrl("http://127.0.0.1:" + string(nP2PPort))

    # Purge any self-peer rows from database
    try {
        oDatabase.execute("DELETE FROM peers WHERE url LIKE '%:" + string(nP2PPort) + "' OR url LIKE '%:" + string(nP2PPort) + "/%'")
    catch
    }

    # Auto-register Mother Node as peer if we are not the Mother Node
    if nP2PPort != 8545 {
        if not isandroid() {
            see "[P2P] Registering default Mother Node at http://127.0.0.1:8545..." + nl
            oP2PService.addPeer("http://127.0.0.1:8545")
            if bMotherActive {
                see "[P2P] Initial background sync with Mother Node..." + nl
                oP2PService.syncAll()
            }
        else
            # On Android Emulator, test 10.0.2.2:8545 (Host PC)
            try {
                cEmuResp = oP2PService.httpGet("http://10.0.2.2:8545/p2p/status")
                if not isNull(cEmuResp) and cEmuResp != "" {
                    see "[P2P Android] Host PC Mother Node detected on 10.0.2.2:8545!" + nl
                    oP2PService.addPeer("http://10.0.2.2:8545")
                    oP2PService.syncAll()
                }
            catch
            }
        ok
    }

    # Restore and auto-sync with saved seed peer (e.g. PC LAN IP configured on mobile)
    try {
        aSeedRow = oDatabase.queryAssoc("SELECT value FROM sync_state WHERE key = 'last_seed_peer' LIMIT 1")
        if not isNull(aSeedRow) and len(aSeedRow) > 0 {
            cSavedSeed = trim(aSeedRow[1][:value])
            if cSavedSeed != "" and not oP2PService.isSelfUrl(cSavedSeed) {
                see "[P2P] Connecting and syncing with saved seed peer: " + cSavedSeed + nl
                oP2PService.addPeer(cSavedSeed)
                oP2PService.syncAll()
            }
        }
    catch
    }


    # Restore last active session if exists
    try{
        aActiveRow = oDatabase.queryAssoc("SELECT value FROM sync_state WHERE key = 'active_user_id' LIMIT 1")
        if not isNull(aActiveRow) and len(aActiveRow) > 0 {
            cSavedUser = aActiveRow[1][:value]
            aCheck = oDatabase.queryAssoc("SELECT id FROM users WHERE id = '" + cSavedUser + "' LIMIT 1")
            if not isNull(aCheck) and len(aCheck) > 0 {
                cActiveUserId = cSavedUser
                see "Restored active session for user: " + cActiveUserId + nl
            }
        }
    catch
    }

    # Create WebView instance
    if not isNull(oView) { return }
    oView = new WebView()
    oView.setTitle("Mejde - Decentralized Sovereign Social")
    oView.setSize(1100, 600, WEBVIEW_HINT_NONE)
    oView.bindMany(aBindList)


    # Load single HTML bundle (built from frontend/)
    cHtml = read("frontend/dist/index.html")
    if cHtml != NULL and cHtml != ""
        oView.setHtml(cHtml)
    else
        # On Android / packaged mobile environments, load from APK assets
        oView.navigate("file:///android_asset/frontend/dist/index.html")
    ok

    oView.run()


# --- Ring functions exposed to JS via bind ---

func js_createWallet nId, aReq
    try
        cPassword = ""
        if len(aReq) >= 1 { cPassword = aReq[1] }
        if len(cPassword) < 8 {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"كلمة المرور يجب أن تكون 8 أحرف على الأقل"')
            return
        }
        
        cMnemonic = oCrypto.generateMnemonic()
        cMnemonicHash = oCrypto.hashMnemonic(cMnemonic)
        
        aKeyPair = oCrypto.generateKeyPair()
        if aKeyPair = NULL {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"فشل توليد مفاتيح التشفير"')
            return
        }
        
        aEncrypted = oCrypto.securePrivateKey(aKeyPair[:private], cPassword)
        if aEncrypted = NULL {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"فشل تشفير المحفظة"')
            return
        }
        
        cUserId = "user_" + left(cMnemonicHash, 8)
        cNow = date() + " " + time()
        
        oStmt = oDatabase.prepare("INSERT OR REPLACE INTO users (id, username, public_key, encrypted_private_key, private_key_iv, private_key_salt, mnemonic_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
        if isNull(oStmt) {
            see "Failed to prepare insert user statement!" + nl
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"فشل حفظ بيانات المستخدم في قاعدة البيانات"')
            return
        }
        oStmt.bindString(1, cUserId)
        oStmt.bindString(2, cUserId)
        oStmt.bindString(3, aKeyPair[:public])
        oStmt.bindString(4, aEncrypted[:key])
        oStmt.bindString(5, aEncrypted[:iv])
        oStmt.bindString(6, aEncrypted[:salt])
        oStmt.bindString(7, cMnemonicHash)
        oStmt.bindString(8, cNow)
        oStmt.execute()
        
        cActiveUserId = cUserId
        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('active_user_id', '" + cUserId + "')")
        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_user_id', '" + cUserId + "')")
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [
            :success = true, 
            :user_id = cUserId,
            :mnemonic = cMnemonic
        ])
    catch
        see "Error in js_createWallet: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_recoverWallet nId, aReq
    try
        cMnemonic = ""
        cPassword = ""
        if len(aReq) >= 1 { cMnemonic = lower(trim(aReq[1])) }
        if len(aReq) >= 2 { cPassword = aReq[2] }
        if len(cPassword) < 8 { cPassword = "mejde_default_secure_pass" }
        
        aWords = split(cMnemonic, " ")
        if len(aWords) < 12 {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"عبارة الاسترداد يجب أن تتكون من 12 كلمة"')
            return
        }
        
        cMnemonicHash = oCrypto.hashMnemonic(cMnemonic)
        cUserId = "user_" + left(cMnemonicHash, 8)
        
        # Generate keypair and encrypt with the password provided during recovery
        aKeyPair = oCrypto.generateKeyPair()
        if aKeyPair = NULL {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"فشل إنشاء مفاتيح التشفير"')
            return
        }
        
        aEncrypted = oCrypto.securePrivateKey(aKeyPair[:private], cPassword)
        cNow = date() + " " + time()
        
        # Save credentials (upsert: preserves profile info if user row already exists)
        oStmt = oDatabase.prepare("INSERT INTO users (id, username, public_key, encrypted_private_key, private_key_iv, private_key_salt, mnemonic_hash, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET public_key = excluded.public_key, encrypted_private_key = excluded.encrypted_private_key, private_key_iv = excluded.private_key_iv, private_key_salt = excluded.private_key_salt, mnemonic_hash = excluded.mnemonic_hash")
        if not isNull(oStmt) {
            oStmt.bindString(1, cUserId)
            oStmt.bindString(2, cUserId)
            oStmt.bindString(3, aKeyPair[:public])
            oStmt.bindString(4, aEncrypted[:key])
            oStmt.bindString(5, aEncrypted[:iv])
            oStmt.bindString(6, aEncrypted[:salt])
            oStmt.bindString(7, cMnemonicHash)
            oStmt.bindString(8, cNow)
            oStmt.execute()
        }
        
        cActiveUserId = cUserId
        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('active_user_id', '" + cUserId + "')")
        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_user_id', '" + cUserId + "')")
        see "Wallet recovered and credentials saved for user: " + cUserId + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:success = true, :user_id = cUserId])
        return
    catch
        see "Error in js_recoverWallet: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_unlockWallet nId, aReq
    try
        cPassword = ""
        if len(aReq) >= 1 { cPassword = aReq[1] }
        if cPassword = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"يرجى إدخال كلمة المرور"')
            return
        }
        
        # 1. First priority: Check last_user_id or active_user_id from sync_state
        cTargetUser = ""
        try {
            aLast = oDatabase.queryAssoc("SELECT value FROM sync_state WHERE key = 'last_user_id' LIMIT 1")
            if not isNull(aLast) and len(aLast) > 0 {
                cTargetUser = aLast[1][:value]
            }
        catch
        }
        if cTargetUser = "" and cActiveUserId != "" {
            cTargetUser = cActiveUserId
        }
        
        # 2. If a specific target user is known, attempt to unlock that user first
        if cTargetUser != "" {
            aTarget = oDatabase.queryAssoc("SELECT id, encrypted_private_key, private_key_iv, private_key_salt FROM users WHERE id = '" + cTargetUser + "' AND encrypted_private_key IS NOT NULL AND encrypted_private_key != '' AND encrypted_private_key != 'none' LIMIT 1")
            if not isNull(aTarget) and len(aTarget) > 0 {
                cEnc  = aTarget[1][:encrypted_private_key]
                cIv   = aTarget[1][:private_key_iv]
                cSalt = aTarget[1][:private_key_salt]
                if cEnc != "" and cEnc != "none" and cEnc != "NULL" {
                    cPrivKey = oCrypto.retrievePrivateKey(cEnc, cIv, cSalt, cPassword)
                    if not isNull(cPrivKey) and substr(cPrivKey, "PRIVATE KEY") > 0 {
                        cActiveUserId = cTargetUser
                        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('active_user_id', '" + cActiveUserId + "')")
                        oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_user_id', '" + cActiveUserId + "')")
                        see "Wallet unlocked successfully for target user: " + cActiveUserId + nl
                        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:success = true, :user_id = cActiveUserId])
                        return
                    }
                }
            }
        }
        
        # 3. If target user didn't unlock (or not set), search all candidate users with valid encrypted keys
        # Ordered by rowid DESC so the most recent accounts are tested first!
        aUsers = oDatabase.queryAssoc("SELECT id, encrypted_private_key, private_key_iv, private_key_salt FROM users WHERE encrypted_private_key IS NOT NULL AND encrypted_private_key != '' AND encrypted_private_key != 'none' AND encrypted_private_key != 'NULL' ORDER BY rowid DESC")
        if isNull(aUsers) or len(aUsers) = 0 {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"لا توجد محفظة محفوظة. يرجى إنشاء أو استرداد محفظة أولاً"')
            return
        }
        
        for aCandidate in aUsers {
            cEnc  = aCandidate[:encrypted_private_key]
            cIv   = aCandidate[:private_key_iv]
            cSalt = aCandidate[:private_key_salt]
            if isNull(cEnc) or cEnc = "" or cEnc = "none" or cEnc = "NULL" { loop }
            if isNull(cIv) or cIv = "NULL" { cIv = "" }
            if isNull(cSalt) or cSalt = "NULL" { cSalt = "" }
            
            cPrivKey = oCrypto.retrievePrivateKey(cEnc, cIv, cSalt, cPassword)
            if not isNull(cPrivKey) and substr(cPrivKey, "PRIVATE KEY") > 0 {
                cActiveUserId = aCandidate[:id]
                oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('active_user_id', '" + cActiveUserId + "')")
                oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_user_id', '" + cActiveUserId + "')")
                see "Wallet unlocked successfully for user: " + cActiveUserId + nl
                oView.wreturn(nId, WEBVIEW_ERROR_OK, [:success = true, :user_id = cActiveUserId])
                return
            }
        }
        
        # 4. If all valid candidate accounts failed decryption, password is truly wrong
        see "Failed to unlock wallet: incorrect password for all local accounts" + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"كلمة المرور غير صحيحة"')
    catch
        see "Error in js_unlockWallet: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_createPost nId, aReq
    try
        cUserId    = "me"
        cContent   = ""
        cMedia     = ""
        cMediaData = ""
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if len(aReq) >= 2 { cContent = aReq[2] }
        if len(aReq) >= 3 { cMedia = aReq[3] }
        if len(aReq) >= 4 { cMediaData = aReq[4] }
        
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        
        see "js_createPost: user=" + cUserId + ", content=" + cContent + nl
        oPostService = new PostService(oDatabase)
        oPostService.setContractManager(oContractManager)
        oPostService.setMessageService(getMessageService())
        oPostService.setP2PService(getP2PService())
        oPostService.setWorkerPool(oAppWorkerPool)
        aRes = oPostService.createPost(cUserId, cContent, cMedia, cMediaData)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_createPost: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getFeed nId, aReq
    try
        cUserId = ""
        cFilter = "latest"
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if len(aReq) >= 2 { cFilter = aReq[2] }
        if (cUserId = "" or cUserId = "me") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        
        oPostService = new PostService(oDatabase)
        oPostService.setContractManager(oContractManager)
        oPostService.setMessageService(getMessageService())
        oPostService.setP2PService(getP2PService())
        aFeed = oPostService.getFeed(cUserId, cFilter)
        if isNull(aFeed) { aFeed = [] }
        see "js_getFeed [" + cFilter + "] returned " + string(len(aFeed)) + " posts" + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aFeed)
    catch
        see "Error in js_getFeed: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_followUser nId, aReq
    try
        cFollower = "me"
        cTarget   = ""
        if len(aReq) >= 1 { cFollower = aReq[1] }
        if len(aReq) >= 2 { cTarget = aReq[2] }
        if (cFollower = "me" or cFollower = "") and cActiveUserId != "" {
            cFollower = cActiveUserId
        }
        oPostService = new PostService(oDatabase)
        oPostService.setContractManager(oContractManager)
        oPostService.setMessageService(getMessageService())
        aRes = oPostService.followUser(cFollower, cTarget)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_followUser: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_unfollowUser nId, aReq
    try
        cFollower = "me"
        cTarget   = ""
        if len(aReq) >= 1 { cFollower = aReq[1] }
        if len(aReq) >= 2 { cTarget = aReq[2] }
        if (cFollower = "me" or cFollower = "") and cActiveUserId != "" {
            cFollower = cActiveUserId
        }
        oPostService = new PostService(oDatabase)
        aRes = oPostService.unfollowUser(cFollower, cTarget)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_unfollowUser: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getFollowStats nId, aReq
    try
        cUserId = "me"
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oPostService = new PostService(oDatabase)
        aRes = oPostService.getFollowStats(cUserId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_getFollowStats: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, [:followers = 0, :following = 0])
    done

func js_likePost nId, aReq
    try
        cUserId = aReq[1]
        cPostId = aReq[2]
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_likePost: user=" + cUserId + ", post=" + cPostId + nl
        oPostService = new PostService(oDatabase)
        aRes = oPostService.likePost(cUserId, cPostId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_likePost: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_ratePost nId, aReq
    try
        cUserId = aReq[1]
        cPostId = aReq[2]
        nStars = number(aReq[3])
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_ratePost: user=" + cUserId + ", post=" + cPostId + ", stars=" + string(nStars) + nl
        oPostService = new PostService(oDatabase)
        oPostService.setContractManager(oContractManager)
        oPostService.setMessageService(getMessageService())
        oPostService.setP2PService(getP2PService())
        oPostService.setWorkerPool(oAppWorkerPool)
        aRes = oPostService.ratePost(cUserId, cPostId, nStars)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_ratePost: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_createTransaction nId, aReq
    try
        cSender = aReq[1]
        cReceiver = aReq[2]
        nAmount = number(aReq[3])
        if (cSender = "me" or cSender = "") and cActiveUserId != "" {
            cSender = cActiveUserId
        }
        see "js_createTransaction: from=" + cSender + ", to=" + cReceiver + ", amount=" + string(nAmount) + nl
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        oBC.setMessageService(getMessageService())
        oBC.setP2PService(getP2PService())
        oBC.setWorkerPool(oAppWorkerPool)
        aRes = oBC.createTransaction(cSender, cReceiver, nAmount)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_createTransaction: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getBalance nId, aReq
    try
        cUserId = aReq[1]
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        nBalance = oBC.getBalance(cUserId)
        see "js_getBalance for " + cUserId + ": " + string(nBalance) + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, nBalance)
    catch
        see "Error in js_getBalance: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, 0)
    done

func js_getBalanceInfo nId, aReq
    try
        cUserId = "me"
        if len(aReq) >= 1 and aReq[1] != "" { cUserId = aReq[1] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        aInfo = oBC.getBalanceInfo(cUserId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aInfo)
    catch
        see "Error in js_getBalanceInfo: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, [:balance = 0, :balance_ikhlas = 0])
    done

func js_buyWalaWithCrypto nId, aReq
    try
        cUserId = "me"
        nUsdt = 10
        cNetwork = "TRC20"
        if len(aReq) >= 1 and aReq[1] != "" { cUserId = aReq[1] }
        if len(aReq) >= 2 { nUsdt = number(aReq[2]) }
        if len(aReq) >= 3 and aReq[3] != "" { cNetwork = aReq[3] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        oBC.setMessageService(getMessageService())
        oBC.setP2PService(getP2PService())
        oBC.setWorkerPool(oAppWorkerPool)
        aRes = oBC.buyWalaWithCrypto(cUserId, nUsdt, cNetwork)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_buyWalaWithCrypto: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getP2POffers nId, aReq
    try
        oBC = new BlockchainService(oDatabase)
        aOffers = oBC.getP2POffers()
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aOffers)
    catch
        see "Error in js_getP2POffers: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
    done

func js_createP2POffer nId, aReq
    try
        cSeller = cActiveUserId
        nWala = 50
        nFiat = 1200
        cCurr = "DZD"
        cPay = "BaridiMob"
        if len(aReq) >= 1 and aReq[1] != "" and aReq[1] != "me" { cSeller = aReq[1] }
        if len(aReq) >= 2 { nWala = number(aReq[2]) }
        if len(aReq) >= 3 { nFiat = number(aReq[3]) }
        if len(aReq) >= 4 and aReq[4] != "" { cCurr = aReq[4] }
        if len(aReq) >= 5 and aReq[5] != "" { cPay = aReq[5] }

        oBC = new BlockchainService(oDatabase)
        aRes = oBC.createP2POffer(cSeller, nWala, nFiat, cCurr, cPay)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_createP2POffer: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_executeP2PBuy nId, aReq
    try
        cBuyer = cActiveUserId
        cOfferId = ""
        if len(aReq) >= 1 and aReq[1] != "" and aReq[1] != "me" { cBuyer = aReq[1] }
        if len(aReq) >= 2 { cOfferId = aReq[2] }

        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        oBC.setMessageService(getMessageService())
        oBC.setP2PService(getP2PService())
        oBC.setWorkerPool(oAppWorkerPool)
        aRes = oBC.executeP2PBuy(cBuyer, cOfferId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_executeP2PBuy: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_addComment nId, aReq
    try
        cUserId = aReq[1]
        cPostId = aReq[2]
        cContent = aReq[3]
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_addComment: user=" + cUserId + ", post=" + cPostId + nl
        oPostService = new PostService(oDatabase)
        oPostService.setContractManager(oContractManager)
        oPostService.setMessageService(getMessageService())
        oPostService.setP2PService(getP2PService())
        oPostService.setWorkerPool(oAppWorkerPool)
        aRes = oPostService.addComment(cUserId, cPostId, cContent)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_addComment: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getComments nId, aReq
    try
        cPostId = aReq[1]
        oPostService = new PostService(oDatabase)
        aComments = oPostService.getComments(cPostId)
        if isNull(aComments) { aComments = [] }
        see "js_getComments: post=" + cPostId + ", count=" + string(len(aComments)) + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aComments)
    catch
        see "Error in js_getComments: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getProfile nId, aReq
    try
        cUserId = aReq[1]
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oPostService = new PostService(oDatabase)
        aProfile = oPostService.getProfile(cUserId)
        see "js_getProfile for: " + cUserId + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aProfile)
    catch
        see "Error in js_getProfile: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_updateProfile nId, aReq
    try
        cUserId = aReq[1]
        cUsername = aReq[2]
        cBio = aReq[3]
        cAvatar = ""
        if len(aReq) >= 4 { cAvatar = aReq[4] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_updateProfile for: " + cUserId + " avatar length=" + string(len(cAvatar)) + nl
        oPostService = new PostService(oDatabase)
        oPostService.setP2PService(getP2PService())
        oPostService.setWorkerPool(oAppWorkerPool)
        aRes = oPostService.updateProfile(cUserId, cUsername, cBio, cAvatar)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_updateProfile: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getUserPosts nId, aReq
    try
        cUserId = aReq[1]
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oPostService = new PostService(oDatabase)
        aPosts = oPostService.getUserPosts(cUserId)
        if isNull(aPosts) { aPosts = [] }
        see "js_getUserPosts for: " + cUserId + " count=" + string(len(aPosts)) + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aPosts)
    catch
        see "Error in js_getUserPosts: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_faucet nId, aReq
    try
        cUserId = "me"
        nAmount = 50
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if len(aReq) >= 2 { nAmount = number(aReq[2]) }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        oBC.setP2PService(getP2PService())
        aRes = oBC.faucet(cUserId, nAmount)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_faucet: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getTransactions nId, aReq
    try
        cUserId = "me"
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        aTxs = oBC.getTransactions(cUserId)
        if isNull(aTxs) { aTxs = [] }
        see "js_getTransactions for " + cUserId + " count=" + string(len(aTxs)) + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aTxs)
    catch
        see "Error in js_getTransactions: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_stakeWala nId, aReq
    try
        cUserId = "me"
        nAmount = 0
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if len(aReq) >= 2 { nAmount = number(aReq[2]) }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_stakeWala: user=" + cUserId + " amount=" + string(nAmount) + nl
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        aRes = oBC.stakeWala(cUserId, nAmount)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_stakeWala: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_unstakeWala nId, aReq
    try
        cUserId = "me"
        nAmount = 0
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if len(aReq) >= 2 { nAmount = number(aReq[2]) }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        see "js_unstakeWala: user=" + cUserId + " amount=" + string(nAmount) + nl
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        aRes = oBC.unstakeWala(cUserId, nAmount)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_unstakeWala: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getStakeInfo nId, aReq
    try
        cUserId = "me"
        if len(aReq) >= 1 { cUserId = aReq[1] }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oBC = new BlockchainService(oDatabase)
        oBC.setContractManager(oContractManager)
        aInfo = oBC.getStakeInfo(cUserId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aInfo)
    catch
        see "Error in js_getStakeInfo: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, [:staked = 0, :daily_quota = 25, :boost = 0, :total_pool = 0])
    done

# =============================================================================
# Phase 4: E2EE Messaging & Notifications
# =============================================================================

func js_sendMessage nId, aReq
    try
        cSender = cActiveUserId
        cReceiver = ""
        cContent = ""
        if len(aReq) >= 1 { cReceiver = aReq[1] }
        if len(aReq) >= 2 { cContent = aReq[2] }
        if cSender = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"يجب تسجيل الدخول أولاً"')
            return
        }
        if cReceiver = "" or cContent = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"مستلم أو محتوى غير صالح"')
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"خدمة المراسلة غير متوفرة"')
            return
        }
        aRes = oMsg.sendMessage(cSender, cReceiver, cContent)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_sendMessage: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getMessages nId, aReq
    try
        cUser1 = cActiveUserId
        cUser2 = ""
        if len(aReq) >= 1 { cUser2 = aReq[1] }
        if cUser1 = "" or cUser2 = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        aMsgs = oMsg.getMessages(cUser1, cUser2)
        if isNull(aMsgs) { aMsgs = [] }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aMsgs)
    catch
        see "Error in js_getMessages: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
    done

func js_getConversations nId, aReq
    try
        cUserId = cActiveUserId
        if cUserId = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        aList = oMsg.getConversations(cUserId)
        if isNull(aList) { aList = [] }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aList)
    catch
        see "Error in js_getConversations: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
    done

func js_getNotifications nId, aReq
    try
        cUserId = cActiveUserId
        if len(aReq) >= 1 and aReq[1] != "" and aReq[1] != "me" { cUserId = aReq[1] }
        if cUserId = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        aNotifs = oMsg.getNotifications(cUserId)
        if isNull(aNotifs) { aNotifs = [] }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aNotifs)
    catch
        see "Error in js_getNotifications: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
    done

func js_markNotificationsRead nId, aReq
    try
        cUserId = cActiveUserId
        if cUserId = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, false)
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, false)
            return
        }
        aRes = oMsg.markNotificationsRead(cUserId)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_markNotificationsRead: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, false)
    done

func js_getUnreadCount nId, aReq
    try
        cUserId = cActiveUserId
        if cUserId = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [:notifications = 0, :messages = 0, :total = 0])
            return
        }
        oMsg = getMessageService()
        if isNull(oMsg) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [:notifications = 0, :messages = 0, :total = 0])
            return
        }
        aCounts = oMsg.getUnreadCount(cUserId)
        if isNull(aCounts) { aCounts = [:notifications = 0, :messages = 0, :total = 0] }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aCounts)
    catch
        see "Error in js_getUnreadCount: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:notifications = 0, :messages = 0, :total = 0])
    done

# =============================================================================
# Phase 5: Node Validator Rewards & Status
# =============================================================================

func js_claimNodeReward nId, aReq
    try
        cNodeAddress = cActiveUserId
        nUptimeHours = 1
        if len(aReq) >= 1 and aReq[1] != "" { cNodeAddress = aReq[1] }
        if len(aReq) >= 2 { nUptimeHours = number(aReq[2]) }
        if cNodeAddress = "" {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"يجب تسجيل الدخول لاستلام مكافأة العقدة"')
            return
        }
        if nUptimeHours <= 0 { nUptimeHours = 1 }
        bOk = oContractManager.rewardNode(cNodeAddress, nUptimeHours)
        if bOk {
            oMsg = getMessageService()
            if not isNull(oMsg) {
                oMsg.createNotification(cNodeAddress, "GENESIS_FAUCET", "reward", "node_" + cNodeAddress, "مكافأة عقدة", "استلمت مكافأة تشغيل عقدة: " + string(nUptimeHours) + " WALA 🖥️")
            }
        }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:claimed = bOk, :hours = nUptimeHours, :node = cNodeAddress])
    catch
        see "Error in js_claimNodeReward: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getNodeStatus nId, aReq
    try
        cNodeId = cActiveUserId
        if len(aReq) >= 1 and aReq[1] != "" { cNodeId = aReq[1] }

        # Gather node stats from DB
        aBlocks = oDatabase.queryAssoc("SELECT count(*) as cnt FROM blocks")
        nBlocks = 0
        if not isNull(aBlocks) and len(aBlocks) > 0 { nBlocks = number(aBlocks[1][:cnt]) }

        aUsers = oDatabase.queryAssoc("SELECT count(*) as cnt FROM users")
        nUsers = 0
        if not isNull(aUsers) and len(aUsers) > 0 { nUsers = number(aUsers[1][:cnt]) }

        aPosts = oDatabase.queryAssoc("SELECT count(*) as cnt FROM posts")
        nPosts = 0
        if not isNull(aPosts) and len(aPosts) > 0 { nPosts = number(aPosts[1][:cnt]) }

        aTxs = oDatabase.queryAssoc("SELECT count(*) as cnt FROM transactions")
        nTxs = 0
        if not isNull(aTxs) and len(aTxs) > 0 { nTxs = number(aTxs[1][:cnt]) }

        oP2P = getP2PService()
        nPeers = 0
        nActivePeers = 0
        cLastSyncTime = ""
        if not isNull(oP2P) {
            aPeers = oP2P.getPeers()
            if not isNull(aPeers) {
                nPeers = len(aPeers)
                for p in aPeers {
                    if p[:status] = "active" { nActivePeers++ }
                }
            }
            cLastSyncTime = oP2P.getLastSync()
        }
        cSync = "standalone"
        if nActivePeers > 0 { cSync = "synced" }

        oView.wreturn(nId, WEBVIEW_ERROR_OK, [
            :node_id = cNodeId,
            :p2p_port = nP2PPort,
            :is_mother_node = (nP2PPort = 8545),
            :mother_url = "http://127.0.0.1:8545",
            :blocks = nBlocks,
            :users = nUsers,
            :posts = nPosts,
            :transactions = nTxs,
            :peers_count = nPeers,
            :active_peers = nActivePeers,
            :sync_status = cSync,
            :last_sync = cLastSyncTime,
            :version = "1.0.0-mejde",
            :network = "Mejde MainNet Alpha"
        ])
    catch
        see "Error in js_getNodeStatus: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_syncNow nId, aReq
    try
        oP2P = getP2PService()
        if isNull(oP2P) {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"خدمة P2P غير متوفرة"')
            return
        }
        aRes = oP2P.syncAll()
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_syncNow: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_getPeers nId, aReq
    try
        oP2P = getP2PService()
        if isNull(oP2P) {
            oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
            return
        }
        aPeers = oP2P.getPeers()
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aPeers)
    catch
        see "Error in js_getPeers: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [])
    done

func js_addPeer nId, aReq
    try
        cUrl = ""
        if len(aReq) >= 1 { cUrl = trim(aReq[1]) }
        oP2P = getP2PService()
        if isNull(oP2P) {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"خدمة P2P غير متوفرة"')
            return
        }
        aRes = oP2P.addPeer(cUrl)
        if not isNull(aRes) {
            try {
                oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value, updated_at) VALUES ('last_seed_peer', '" + cUrl + "', '" + date() + " " + time() + "')")
            catch
            }
        }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_addPeer: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_removePeer nId, aReq
    try
        cUrl = ""
        if len(aReq) >= 1 { cUrl = aReq[1] }
        oP2P = getP2PService()
        if isNull(oP2P) {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"خدمة P2P غير متوفرة"')
            return
        }
        aRes = oP2P.removePeer(cUrl)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_removePeer: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done

func js_checkSession nId, aReq
    try
        if cActiveUserId != "" {
            aUser = oDatabase.queryAssoc("SELECT id, username, bio, avatar_cid, avatar_data FROM users WHERE id = '" + cActiveUserId + "' LIMIT 1")
            if not isNull(aUser) and len(aUser) > 0 {
                cUsername = aUser[1][:username]
                cAvatar = aUser[1][:avatar_data]
                if isNull(cAvatar) or cAvatar = "" { cAvatar = aUser[1][:avatar_cid] }
                oView.wreturn(nId, WEBVIEW_ERROR_OK, [
                    :authenticated = true,
                    :user_id = cActiveUserId,
                    :username = cUsername,
                    :avatar = cAvatar
                ])
                return
            }
        }
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:authenticated = false, :user_id = ""])
    catch
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:authenticated = false, :user_id = ""])
    done

func js_logout nId, aReq
    try
        if cActiveUserId != "" {
            oDatabase.execute("INSERT OR REPLACE INTO sync_state (key, value) VALUES ('last_user_id', '" + cActiveUserId + "')")
        }
        cActiveUserId = ""
        oDatabase.execute("DELETE FROM sync_state WHERE key = 'active_user_id'")
        see "User logged out." + nl
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:success = true])
    catch
        oView.wreturn(nId, WEBVIEW_ERROR_OK, [:success = false])
    done

func js_requestMotherRefill nId, aReq
    try
        cMotherUrl = "http://127.0.0.1:8545"
        cUserId = "me"
        nAmount = 50
        if len(aReq) >= 1 and aReq[1] != "" { cMotherUrl = aReq[1] }
        if len(aReq) >= 2 and aReq[2] != "" { cUserId = aReq[2] }
        if len(aReq) >= 3 { nAmount = number(aReq[3]) }
        if (cUserId = "me" or cUserId = "") and cActiveUserId != "" {
            cUserId = cActiveUserId
        }
        oP2P = getP2PService()
        if isNull(oP2P) {
            oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"خدمة P2P غير متوفرة"')
            return
        }
        see "js_requestMotherRefill: requesting " + string(nAmount) + " WALA from Mother Node (" + cMotherUrl + ") for @" + cUserId + nl
        aRes = oP2P.requestMotherRefill(cMotherUrl, cUserId, nAmount)
        oView.wreturn(nId, WEBVIEW_ERROR_OK, aRes)
    catch
        see "Error in js_requestMotherRefill: " + cCatchError + nl
        oView.wreturn(nId, WEBVIEW_ERROR_ERROR, '"' + cCatchError + '"')
    done
