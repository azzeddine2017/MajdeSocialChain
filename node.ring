/* ====================================================================
 * Mejde Network - Headless Server Node (خادم نود لا مركزي بدون واجهة)
 * Runs a standalone full node in terminal / background / server.
 *
 * Usage:
 *   ring node.ring [port] [db_file] [seed_peer_url]
 *
 * Examples:
 *   # Mother Node (Port 8545, Genesis DB):
 *   ring node.ring 8545 social_mother.db
 *
 *   # Peer Node 1 (Port 8546, Peer DB, auto-syncing with Mother Node):
 *   ring node.ring 8546 social_peer1.db http://127.0.0.1:8545
 *
 *   # Peer Node 2 (Port 8547):
 *   ring node.ring 8547 social_peer2.db http://127.0.0.1:8545
 * ==================================================================== */

load "stdlib.ring"
load "sockets.ring"
if iswindows()
    try
        loadlib("ring_openssl.dll")
    catch
    done
ok

load "core/Database.ring"
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
load "services/PostService.ring"
load "services/BlockchainService.ring"
load "services/MessageService.ring"
load "services/P2PSyncService.ring"
load "services/MediaStorageService.ring"
load "p2p/P2PWorkerPool.ring"

# ----------------------------------------------------------------------
# CLI Arguments Parsing
# sysargv[1] = ring executable
# sysargv[2] = node.ring
# sysargv[3] = port (default 8545)
# sysargv[4] = db_path (default social_mother.db)
# sysargv[5] = seed_peer (default "" for 8545, or "http://127.0.0.1:8545" for peers)
# ----------------------------------------------------------------------

nPort = 8545
cDbPath = "social_mother.db"
cSeedPeer = ""

if len(sysargv) >= 3 and sysargv[3] != "" {
    try {
        nPort = number(sysargv[3])
    catch
        nPort = 8545
    }
}

if len(sysargv) >= 4 and sysargv[4] != "" {
    cDbPath = sysargv[4]
else
    if nPort != 8545 {
        cDbPath = "social_node_" + string(nPort) + ".db"
    }
}

if len(sysargv) >= 5 and sysargv[5] != "" {
    cSeedPeer = sysargv[5]
else
    # If not port 8545, default seed peer to local 8545 Mother node
    if nPort != 8545 {
        cSeedPeer = "http://127.0.0.1:8545"
    }
}

# ----------------------------------------------------------------------
# Initialization
# ----------------------------------------------------------------------

see "" + nl
see "========================================================================" + nl
see "               MEJDE NETWORK - HEADLESS NODE SERVER                     " + nl
see "           شبكة مَجْد اللامركزية - خادم النود المستقل (بدون واجهة)        " + nl
see "========================================================================" + nl
see "  Listening Port:    " + string(nPort) + nl
see "  Companion DB:      " + cDbPath + nl
if cSeedPeer != "" {
    see "  Seed Peer Node:    " + cSeedPeer + " (Auto-Sync Enabled)" + nl
else
    see "  Node Role:         GENESIS MOTHER NODE (Primary Authority)" + nl
}
see "------------------------------------------------------------------------" + nl

oDatabase = new Database(cDbPath)
oMediaStorage = new MediaStorageService("")
oMediaStorage.setDB(oDatabase)
oCrypto = new Crypto()
oContractManager = new ContractManager("GENESIS_FAUCET", oDatabase)
oBlockchain = new BlockchainService(oDatabase)
oPosts = new PostService(oDatabase)
oMessages = new MessageService(oDatabase)
oP2P = new P2PSyncService(oDatabase)
oP2P.setMyUrl("http://127.0.0.1:" + string(nPort))

# Purge any self-peer rows from database
try {
    oDatabase.execute("DELETE FROM peers WHERE url LIKE '%:" + string(nPort) + "' OR url LIKE '%:" + string(nPort) + "/%'")
catch
}

oBlockchain.setContractManager(oContractManager)
oBlockchain.setMessageService(oMessages)
oBlockchain.setP2PService(oP2P)
oPosts.setP2PService(oP2P)

# Initialize Multi-threaded P2P Worker Pool (RingThreadPro)
oWorkerPool = new P2PWorkerPool(4)
oWorkerPool.setContext(oDatabase, oBlockchain, oPosts, oMessages, oP2P, nPort)
oWorkerPool.start()
oPosts.setWorkerPool(oWorkerPool)

# Initialize TCP Server Socket FIRST so node is reachable for mutual handshakes
sock = socket(AF_INET, SOCK_STREAM, 0)
if isNull(sock) {
    see "[Error] Failed to create socket!" + nl
    return
}

nBind = bind(sock, "127.0.0.1", nPort)
if nBind != 0 {
    bind(sock, "0.0.0.0", nPort)
}
listen(sock, 25)

# If seed peer provided, add peer and perform initial sync
if cSeedPeer != "" {
    see "[Startup] Registering and syncing with Seed Peer: " + cSeedPeer + "..." + nl
    oP2P.addPeer(cSeedPeer)
    oP2P.syncAll()
    see "[Startup] Initial synchronization completed!" + nl
}

see "[Ready] Node server is active and listening on http://127.0.0.1:" + string(nPort) + nl
see "[Endpoints Available]:" + nl
see "  - GET  /p2p/status        Node telemetry and stats" + nl
see "  - GET  /p2p/blocks        Synchronize blocks" + nl
see "  - GET  /p2p/posts         Synchronize posts" + nl
see "  - GET  /p2p/transactions  Synchronize transactions" + nl
see "  - POST /p2p/broadcast     Receive gossip events" + nl
see "  - POST /p2p/faucet_request WALA refill from Mother Node" + nl
see "  - POST /api/post          Create & broadcast post" + nl
see "  - POST /api/send          Transfer WALA tokens" + nl
see "  - GET  /api/balance       Check user balance" + nl
see "  - POST /api/sync          Trigger manual P2P sync" + nl
see "========================================================================" + nl
see "Press Ctrl+C to terminate node." + nl + nl

# ----------------------------------------------------------------------
# Main Multi-threaded Listener Loop
# ----------------------------------------------------------------------

while true
    client = accept(sock)
    if not isNull(client) {
        # Dispatch client socket instantly to worker pool (non-blocking)
        oWorkerPool.dispatchClient(client)
    }
end

# ----------------------------------------------------------------------
# Request Dispatcher
# ----------------------------------------------------------------------

func handleServerRequest(client, oDatabase, oBlockchain, oPosts, oMessages, oP2P, nPort) {
    try {
        cData = recv(client, 65536)
        if isNull(cData) or cData = "" {
            close(client)
            return
        }

        aLines = split(cData, nl)
        if len(aLines) = 0 {
            close(client)
            return
        }

        cFirstLine = trim(aLines[1])
        aParts = split(cFirstLine, " ")
        if len(aParts) < 2 {
            close(client)
            return
        }

        cMethod = upper(aParts[1])
        cPath = aParts[2]
        while substr(cPath, "//") = 1
            cPath = substr(cPath, 2)
        end
        if cPath = "" { cPath = "/" }
        see "[Incoming HTTP] " + cMethod + " " + cPath + nl

        # Extract Body if present
        cBody = ""
        nBodyStart = substr(cData, char(13) + char(10) + char(13) + char(10))
        if nBodyStart > 0 {
            cBody = substr(cData, nBodyStart + 4)
        else
            nBodyStart = substr(cData, char(10) + char(10))
            if nBodyStart > 0 {
                cBody = substr(cData, nBodyStart + 2)
            }
        }

        # Handle CORS
        if cMethod = "OPTIONS" {
            sendHttp(client, 200, "OK", '{"status":"ok"}')
            return
        }

        # 0. Mother Node Web Dashboard Console
        if cMethod = "GET" and (cPath = "/" or cPath = "/dashboard" or cPath = "/admin") {
            sendHtml(client, getMotherNodeDashboardHtml(nPort, cDbPath))
            return
        }

        # 1. P2P Telemetry Status
        if cMethod = "GET" and (cPath = "/p2p/status" or cPath = "/api/status") {
            aBlocks = oDatabase.queryAssoc("SELECT count(*) as cnt FROM blocks")
            aPosts  = oDatabase.queryAssoc("SELECT count(*) as cnt FROM posts")
            aUsers  = oDatabase.queryAssoc("SELECT count(*) as cnt FROM users")
            aTxs    = oDatabase.queryAssoc("SELECT count(*) as cnt FROM transactions")
            aPeers  = oDatabase.queryAssoc("SELECT count(*) as cnt FROM peers WHERE status='active'")

            nB = 0 ; nP = 0 ; nU = 0 ; nT = 0 ; nPr = 0
            if len(aBlocks) > 0 { nB = number(aBlocks[1][:cnt]) }
            if len(aPosts) > 0 { nP = number(aPosts[1][:cnt]) }
            if len(aUsers) > 0 { nU = number(aUsers[1][:cnt]) }
            if len(aTxs) > 0 { nT = number(aTxs[1][:cnt]) }
            if len(aPeers) > 0 { nPr = number(aPeers[1][:cnt]) }

            cJson = '{"node_id":"node_' + string(nPort) + '","port":' + string(nPort) + ',"blocks":' + string(nB) + ',"posts":' + string(nP) + ',"users":' + string(nU) + ',"transactions":' + string(nT) + ',"active_peers":' + string(nPr) + ',"network":"Mejde MainNet Alpha","version":"1.0.0-headless"}'
            sendHttp(client, 200, "OK", cJson)
            return
        }

        # 2. P2P Blocks
        if cMethod = "GET" and substr(cPath, "/p2p/blocks") = 1 {
            aBlocks = oDatabase.queryAssoc("SELECT * FROM blocks ORDER BY timestamp ASC LIMIT 100")
            sendHttp(client, 200, "OK", listToJsonString(aBlocks))
            return
        }

        # 3. P2P Posts
        if cMethod = "GET" and substr(cPath, "/p2p/posts") = 1 {
            aPosts = oDatabase.queryAssoc("SELECT * FROM posts ORDER BY created_at ASC LIMIT 100")
            sendHttp(client, 200, "OK", listToJsonString(aPosts))
            return
        }

        # 4. P2P Comments
        if cMethod = "GET" and substr(cPath, "/p2p/comments") = 1 {
            aComments = oDatabase.queryAssoc("SELECT * FROM comments ORDER BY created_at ASC LIMIT 200")
            sendHttp(client, 200, "OK", listToJsonString(aComments))
            return
        }

        # 5. P2P Ratings
        if cMethod = "GET" and substr(cPath, "/p2p/ratings") = 1 {
            aRatings = oDatabase.queryAssoc("SELECT * FROM ratings ORDER BY created_at ASC LIMIT 200")
            sendHttp(client, 200, "OK", listToJsonString(aRatings))
            return
        }

        # 6. P2P Transactions
        if cMethod = "GET" and substr(cPath, "/p2p/transactions") = 1 {
            aTxs = oDatabase.queryAssoc("SELECT id, sender_id, receiver_id, amount, signature, block_id, status, created_at FROM transactions WHERE status = 'confirmed' ORDER BY created_at ASC LIMIT 200")
            sendHttp(client, 200, "OK", listToJsonString(aTxs))
            return
        }

        # 6.5 P2P Users & Profiles
        if cMethod = "GET" and substr(cPath, "/p2p/users") = 1 {
            aUsers = oDatabase.queryAssoc("SELECT id, username, bio, avatar_cid, avatar_data, created_at FROM users LIMIT 100")
            sendHttp(client, 200, "OK", listToJsonString(aUsers))
            return
        }

        # 7. P2P Peers List
        if cMethod = "GET" and substr(cPath, "/p2p/peers") = 1 {
            aPeers = oDatabase.queryAssoc("SELECT url, name, last_seen, status FROM peers LIMIT 50")
            sendHttp(client, 200, "OK", listToJsonString(aPeers))
            return
        }

        # 7.1 Register Peer Endpoint (Mutual Handshake)
        if cMethod = "POST" and cPath = "/p2p/register_peer" {
            cPeerUrl = extractParam(cBody, "url")
            cPeerName = extractParam(cBody, "name")
            if cPeerUrl != "" {
                if substr(cPeerUrl, "http://") != 1 and substr(cPeerUrl, "https://") != 1 {
                    cPeerUrl = "http://" + cPeerUrl
                }
                if oP2P.isSelfUrl(cPeerUrl) {
                    sendHttp(client, 200, "OK", '{"success":true,"registered":false,"reason":"self"}')
                    return
                }
                cNow = date() + " " + time()
                oStmt = oDatabase.prepare("INSERT OR REPLACE INTO peers (url, name, last_seen, status, blocks_count, created_at) VALUES (?, ?, ?, 'active', 0, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cPeerUrl)
                    oStmt.bindString(2, cPeerUrl)
                    oStmt.bindString(3, cNow)
                    oStmt.bindString(4, cNow)
                    oStmt.execute()
                    see "[P2P Handshake] Successfully registered active peer: " + cPeerUrl + nl
                    sendHttp(client, 200, "OK", '{"success":true,"registered":"' + cPeerUrl + '"}')
                    return
                }
            }
            sendHttp(client, 400, "Bad Request", '{"error":"invalid peer url"}')
            return
        }

        # 8. Mother Node Faucet Refill Endpoint
        if cMethod = "POST" and cPath = "/p2p/faucet_request" {
            cUserId = extractParam(cBody, "user_id")
            cAmount = extractParam(cBody, "amount")
            nAmount = number(cAmount)
            if nAmount <= 0 { nAmount = 50 }
            if cUserId != "" {
                cTxId = "grant_" + string(random(999999999)) + "_" + string(random(999999))
                cNow = date() + " " + time()
                oStmt = oDatabase.prepare("INSERT OR REPLACE INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, 'GENESIS_FAUCET', ?, ?, 'GENESIS_MOTHER_SIGNATURE', 'block_genesis', 'confirmed', ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cTxId)
                    oStmt.bindString(2, cUserId)
                    oStmt.bindFloat(3, nAmount)
                    oStmt.bindString(4, cNow)
                    oStmt.execute()
                    see "[Mother Node] Dispatched " + string(nAmount) + " WALA grant to @" + cUserId + " (TX: " + cTxId + ")" + nl
                    cResp = '{"success":true,"tx_id":"' + cTxId + '","sender_id":"GENESIS_FAUCET","receiver_id":"' + cUserId + '","amount":' + string(nAmount) + ',"created_at":"' + cNow + '"}'
                    sendHttp(client, 200, "OK", cResp)
                    return
                }
            }
            sendHttp(client, 400, "Bad Request", '{"error":"invalid refill request"}')
            return
        }

        # 8.5 P2P Decoupled Media CAS Endpoint (GET /p2p/media/{hash})
        if cMethod = "GET" and substr(cPath, "/p2p/media/") = 1 {
            cHash = substr(cPath, 12)
            nSlash = substr(cHash, "/")
            if nSlash > 0 { cHash = substr(cHash, 1, nSlash - 1) }
            nAmp = substr(cHash, "?")
            if nAmp > 0 { cHash = substr(cHash, 1, nAmp - 1) }
            cHash = trim(cHash)
            oMedia = oPosts.getMediaStorageService()
            if cHash != "" and not isNull(oMedia) and oMedia.hasMedia(cHash) {
                cBlob = oMedia.getMedia(cHash)
                cCleanBlob = substr(cBlob, '\', '\\')
                cCleanBlob = substr(cCleanBlob, '"', '\"')
                cCleanBlob = substr(cCleanBlob, char(10), '\n')
                cCleanBlob = substr(cCleanBlob, char(13), '')
                sendHttp(client, 200, "OK", '{"hash":"' + cHash + '","data":"' + cCleanBlob + '"}')
                return
            }
            sendHttp(client, 404, "Not Found", '{"error":"media not found"}')
            return
        }

        # 8.6 P2P Decoupled Media Upload Endpoint (POST /p2p/media)
        if cMethod = "POST" and cPath = "/p2p/media" {
            cData = extractParam(cBody, "data")
            if cData != "" {
                oMedia = oPosts.getMediaStorageService()
                cHash = oMedia.storeMedia(cData)
                sendHttp(client, 200, "OK", '{"success":true,"hash":"' + cHash + '"}')
                return
            }
            sendHttp(client, 400, "Bad Request", '{"error":"missing data"}')
            return
        }

        # 9. P2P Broadcast receiver
        if cMethod = "POST" and cPath = "/p2p/broadcast" {
            cSenderUrl = extractParam(cBody, "sender_url")
            if cSenderUrl != "" and not oP2P.isSelfUrl(cSenderUrl) {
                cNow = date() + " " + time()
                oStmtP = oDatabase.prepare("INSERT OR REPLACE INTO peers (url, name, last_seen, status, blocks_count, created_at) VALUES (?, ?, ?, 'active', 0, ?)")
                if not isNull(oStmtP) {
                    oStmtP.bindString(1, cSenderUrl)
                    oStmtP.bindString(2, cSenderUrl)
                    oStmtP.bindString(3, cNow)
                    oStmtP.bindString(4, cNow)
                    oStmtP.execute()
                    see "[P2P] Registered active peer from broadcast: " + cSenderUrl + nl
                }
            }
            processGossipBroadcast(cBody, oDatabase)
            sendHttp(client, 200, "OK", '{"success":true}')
            return
        }

        # 10. CLI API: Balance Check
        if cMethod = "GET" and substr(cPath, "/api/balance") = 1 {
            cUserId = ""
            nPos = substr(cPath, "user_id=")
            if nPos > 0 {
                cUserId = substr(cPath, nPos + 8)
                nAmp = substr(cUserId, "&")
                if nAmp > 0 { cUserId = substr(cUserId, 1, nAmp - 1) }
            }
            if cUserId != "" {
                nBal = oBlockchain.getBalance(cUserId)
                see "[API] Balance query for @" + cUserId + ": " + string(nBal) + " WALA" + nl
                sendHttp(client, 200, "OK", '{"user_id":"' + cUserId + '","balance":' + string(nBal) + '}')
                return
            }
            sendHttp(client, 400, "Bad Request", '{"error":"missing user_id"}')
            return
        }

        # 11. CLI API: Post Creation & Broadcast
        if cMethod = "POST" and cPath = "/api/post" {
            cUserId = extractParam(cBody, "user_id")
            cContent = extractParam(cBody, "content")
            if cUserId != "" and cContent != "" {
                oRes = oPosts.createPost(cUserId, cContent, "", "")
                see "[API] New post created by @" + cUserId + ": " + cContent + nl
                sendHttp(client, 200, "OK", '{"success":true,"user_id":"' + cUserId + '","content":"' + cContent + '"}')
                return
            }
            sendHttp(client, 400, "Bad Request", '{"error":"user_id and content required"}')
            return
        }

        # 12. CLI API: Send Transaction & Broadcast
        if cMethod = "POST" and cPath = "/api/send" {
            cSender = extractParam(cBody, "sender_id")
            cReceiver = extractParam(cBody, "receiver_id")
            nAmount = number(extractParam(cBody, "amount"))
            if cSender != "" and cReceiver != "" and nAmount > 0 {
                cNow = date() + " " + time()
                cTxId = "tx_" + string(random(999999999))
                # Insert directly or via blockchain service
                oStmt = oDatabase.prepare("INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, 'cli_signed', 'block_pending', 'confirmed', ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cTxId)
                    oStmt.bindString(2, cSender)
                    oStmt.bindString(3, cReceiver)
                    oStmt.bindFloat(4, nAmount)
                    oStmt.bindString(5, cNow)
                    oStmt.execute()

                    # Broadcast transaction (safe, non-blocking)
                    try {
                        oP2P.broadcast("transaction", [
                            [:id, cTxId],
                            [:sender_id, cSender],
                            [:receiver_id, cReceiver],
                            [:amount, nAmount],
                            [:signature, "cli_signed"],
                            [:created_at, cNow]
                        ])
                    catch
                        see "[Warning] Transaction broadcast error: " + cCatchError + nl
                    }

                    see "[API] Transaction dispatched: " + string(nAmount) + " WALA from @" + cSender + " to @" + cReceiver + nl
                    sendHttp(client, 200, "OK", '{"success":true,"tx_id":"' + cTxId + '","amount":' + string(nAmount) + '}')
                    return
                }
            }
            sendHttp(client, 400, "Bad Request", '{"error":"invalid transaction parameters"}')
            return
        }

        # 12.5 CLI API: Buy WALA with Crypto (On-Ramp)
        if cMethod = "POST" and cPath = "/api/buy" {
            cUserId = extractParam(cBody, "user_id")
            nUsdt = number(extractParam(cBody, "amount"))
            cNet = extractParam(cBody, "network")
            if cNet = "" { cNet = "TRC20" }
            if cUserId != "" and nUsdt > 0 {
                aRes = oBlockchain.buyWalaWithCrypto(cUserId, nUsdt, cNet)
                sendHttp(client, 200, "OK", '{"success":true,"user_id":"' + cUserId + '","wala_amount":' + string(nUsdt * 10) + ',"usdt_amount":' + string(nUsdt) + '}')
                return
            }
            sendHttp(client, 400, "Bad Request", '{"error":"user_id and positive amount required"}')
            return
        }

        # 13. CLI API: Trigger Sync
        if (cMethod = "POST" or cMethod = "GET") and cPath = "/api/sync" {
            see "[API] Manual P2P sync requested..." + nl
            oP2P.syncAll()
            see "[API] Manual sync completed." + nl
            sendHttp(client, 200, "OK", '{"success":true,"message":"Node synchronized successfully with peers"}')
            return
        }

        sendHttp(client, 404, "Not Found", '{"error":"unknown endpoint"}')
    catch
        see "[Error] " + cCatchError + nl
        sendHttp(client, 500, "Internal Server Error", '{"error":"' + cCatchError + '"}')
    }
}

# ----------------------------------------------------------------------
# Processing Gossip Broadcasts
# ----------------------------------------------------------------------

func processGossipBroadcast(cBody, oDatabase) {
    try {
        if substr(cBody, '"type":"post"') > 0 or substr(cBody, '"type": "post"') > 0 {
            cId = extractParam(cBody, "id")
            cUserId = extractParam(cBody, "user_id")
            cContent = extractParam(cBody, "content")
            cMedia = extractParam(cBody, "media_cid")
            cMediaData = extractParam(cBody, "media_data")
            cCreatedAt = extractParam(cBody, "created_at")
            if cId != "" and cUserId != "" {
                oStmtU = oDatabase.prepare("INSERT OR IGNORE INTO users (id, username, public_key, encrypted_private_key, created_at) VALUES (?, ?, 'gossip_key', 'none', ?)")
                if not isNull(oStmtU) {
                    oStmtU.bindString(1, cUserId)
                    oStmtU.bindString(2, cUserId)
                    oStmtU.bindString(3, cCreatedAt)
                    oStmtU.execute()
                }
                oStmt = oDatabase.prepare("INSERT OR IGNORE INTO posts (id, user_id, content, media_cid, media_data, created_at) VALUES (?, ?, ?, ?, ?, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cUserId)
                    oStmt.bindString(3, cContent)
                    oStmt.bindString(4, cMedia)
                    oStmt.bindString(5, cMediaData)
                    oStmt.bindString(6, cCreatedAt)
                    oStmt.execute()

                    # Also store in feed_cache
                    oStmt2 = oDatabase.prepare("INSERT OR IGNORE INTO feed_cache (post_id, author_pubkey, content, media_cid, media_data, likes_count, merit_score, created_at) VALUES (?, ?, ?, ?, '', 0, 10.0, ?)")
                    if not isNull(oStmt2) {
                        oStmt2.bindString(1, cId)
                        oStmt2.bindString(2, cUserId)
                        oStmt2.bindString(3, cContent)
                        oStmt2.bindString(4, cMedia)
                        oStmt2.bindString(5, cCreatedAt)
                        oStmt2.execute()
                    }

                    see "[Gossip Broadcast] Stored post: " + cId + " from @" + cUserId + nl
                }
            }
        }

        if substr(cBody, '"type":"profile"') > 0 or substr(cBody, '"type": "profile"') > 0 {
            cId = extractParam(cBody, "id")
            cUsername = extractParam(cBody, "username")
            cBio = extractParam(cBody, "bio")
            cAvatarCid = extractParam(cBody, "avatar_cid")
            cAvatarData = extractParam(cBody, "avatar_data")
            if cId != "" {
                if cAvatarData != "" and not isNull(oMediaStorage) {
                    cStored = oMediaStorage.storeMedia(cAvatarData)
                    if cAvatarCid = "" { cAvatarCid = cStored }
                }
                oStmt = oDatabase.prepare("INSERT INTO users (id, username, bio, avatar_cid, avatar_data, public_key, encrypted_private_key, created_at) VALUES (?, ?, ?, ?, '', 'auto_key', 'none', ?) ON CONFLICT(id) DO UPDATE SET username = excluded.username, bio = excluded.bio, avatar_cid = CASE WHEN excluded.avatar_cid != '' THEN excluded.avatar_cid ELSE users.avatar_cid END")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cUsername)
                    oStmt.bindString(3, cBio)
                    oStmt.bindString(4, cAvatarCid)
                    oStmt.bindString(5, date() + " " + time())
                    oStmt.execute()
                    see "[Gossip Broadcast] Updated user profile for @" + cId + " (avatar_cid=" + cAvatarCid + ")" + nl
                }
            }
        }

        if substr(cBody, '"type":"transaction"') > 0 or substr(cBody, '"type": "transaction"') > 0 {
            cId = extractParam(cBody, "id")
            cSender = extractParam(cBody, "sender_id")
            cReceiver = extractParam(cBody, "receiver_id")
            cAmount = extractParam(cBody, "amount")
            cSig = extractParam(cBody, "signature")
            cCreatedAt = extractParam(cBody, "created_at")
            if cId != "" and cReceiver != "" {
                nAmt = number(cAmount)
                oStmt = oDatabase.prepare("INSERT OR IGNORE INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, 'block_p2p', 'confirmed', ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cSender)
                    oStmt.bindString(3, cReceiver)
                    oStmt.bindFloat(4, nAmt)
                    oStmt.bindString(5, cSig)
                    oStmt.bindString(6, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip Broadcast] Confirmed transaction: " + string(nAmt) + " WALA @" + cSender + " -> @" + cReceiver + nl
                }
            }
        }
    catch
        see "[Error in processGossipBroadcast]: " + cCatchError + nl
    }
}

# ----------------------------------------------------------------------
# JSON and HTTP Helpers
# ----------------------------------------------------------------------

func extractParam(cJson, cKey) {
    cTarget = '"' + cKey + '":'
    nPos = substr(cJson, cTarget)
    if nPos = 0 {
        cTarget = '"' + cKey + '" :'
        nPos = substr(cJson, cTarget)
    }
    if nPos = 0 {
        cTarget = cKey + '":'
        nPos = substr(cJson, cTarget)
    }
    if nPos = 0 {
        cTarget = cKey + ':'
        nPos = substr(cJson, cTarget)
    }
    if nPos = 0 { return "" }
    nStart = nPos + len(cTarget)
    while nStart <= len(cJson) and (cJson[nStart] = " " or cJson[nStart] = char(9))
        nStart++
    end
    if nStart > len(cJson) { return "" }
    if cJson[nStart] = '"' {
        nStart++
        nEnd = nStart
        while nEnd <= len(cJson) and cJson[nEnd] != '"'
            if cJson[nEnd] = '\' and nEnd < len(cJson) { nEnd++ }
            nEnd++
        end
        return substr(cJson, nStart, nEnd - nStart)
    else
        nEnd = nStart
        while nEnd <= len(cJson) and cJson[nEnd] != ',' and cJson[nEnd] != '}' and cJson[nEnd] != char(13) and cJson[nEnd] != char(10)
            nEnd++
        end
        return trim(substr(cJson, nStart, nEnd - nStart))
    }
}

func listToJsonString(aList) {
    if isNull(aList) or len(aList) = 0 { return "[]" }
    cOut = "["
    for i = 1 to len(aList) {
        if i > 1 { cOut += "," }
        cOut += "{"
        aItem = aList[i]
        nFieldCount = 0
        for aPair in aItem {
            nFieldCount++
            if nFieldCount > 1 { cOut += "," }
            cKey = string(aPair[1])
            cVal = aPair[2]
            if isNull(cVal) {
                cOut += '"' + cKey + '":null'
            else
                if type(cVal) = "NUMBER" {
                    cOut += '"' + cKey + '":' + string(cVal)
                else
                    cClean = string(cVal)
                    cClean = substr(cClean, '\', '\\')
                    cClean = substr(cClean, '"', '\"')
                    cClean = substr(cClean, char(10), '\n')
                    cClean = substr(cClean, char(13), '')
                    cOut += '"' + cKey + '":"' + cClean + '"'
                }
            }
        }
        cOut += "}"
    }
    cOut += "]"
    return cOut
}

func sendHttp(client, nCode, cStatus, cBody) {
    cHeader = "HTTP/1.1 " + string(nCode) + " " + cStatus + nl +
              "Content-Type: application/json; charset=utf-8" + nl +
              "Content-Length: " + string(len(cBody)) + nl +
              "Access-Control-Allow-Origin: *" + nl +
              "Access-Control-Allow-Methods: GET, POST, OPTIONS" + nl +
              "Access-Control-Allow-Headers: Content-Type, Authorization" + nl +
              "Connection: close" + nl + nl
    send(client, cHeader + cBody)
    close(client)
}

func sendHtml(client, cHtml) {
    cHeader = "HTTP/1.1 200 OK" + nl +
              "Content-Type: text/html; charset=utf-8" + nl +
              "Content-Length: " + string(len(cHtml)) + nl +
              "Access-Control-Allow-Origin: *" + nl +
              "Access-Control-Allow-Methods: GET, POST, OPTIONS" + nl +
              "Access-Control-Allow-Headers: Content-Type, Authorization" + nl +
              "Connection: close" + nl + nl
    send(client, cHeader + cHtml)
    close(client)
}

func getMotherNodeDashboardHtml(nPort, cDbPath) {
    cContent = ""
    try {
        cContent = read("p2p/dashboard.html")
    catch
    }
    if isNull(cContent) or cContent = "" {
        try {
            cContent = read("../p2p/dashboard.html")
        catch
        }
    }
    if isNull(cContent) or cContent = "" {
        cContent = "<!DOCTYPE html><html><body style='background:#070709;color:#fff;font-family:sans-serif;padding:3rem;text-align:center;'><h1>Mejde Mother Node Active</h1><p>Port: " + string(nPort) + "</p><p><a href='/p2p/status' style='color:#6366f1;'>Telemetry JSON</a></p></body></html>"
    }
    cContent = substr(cContent, "{{PORT}}", string(nPort))
    cContent = substr(cContent, "{{DB_PATH}}", cDbPath)
    cContent = substr(cContent, "{{NETWORK}}", "Mejde MainNet Alpha")
    return cContent
}
