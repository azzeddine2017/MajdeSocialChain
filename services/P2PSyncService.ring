/* ====================================================================
 * Mejde Network - P2P Sync & Gossip Service
 * Synchronizes companion LibSQL databases between nodes via HTTP gossip.
 * ==================================================================== */

try
    load "sockets.ring"
catch
done
try
    load "internetlib.ring"
catch
done

class P2PSyncService from Service {

    func init(oDatabase) {
        oDB = oDatabase
        bSyncing = false
        cLastSync = ""
        cMyUrl = ""
        oMediaStorage = new MediaStorageService("")
        if not isNull(oDB) {
            oMediaStorage.setDB(oDB)
        }
    }

    func setMyUrl(cUrl) {
        cMyUrl = cleanPeerUrl(cUrl)
    }

    func getMyUrl() {
        return cMyUrl
    }

    func cleanPeerUrl(cUrl) {
        if isNull(cUrl) { return "" }
        cUrl = trim(cUrl)
        if cUrl = "" { return "" }
        if substr(cUrl, "http://") != 1 and substr(cUrl, "https://") != 1 {
            cUrl = "http://" + cUrl
        }
        # Strip trailing slashes
        while len(cUrl) > 0 and substr(cUrl, len(cUrl), 1) = "/"
            cUrl = left(cUrl, len(cUrl) - 1)
        end
        return cUrl
    }

    func getUrlHostPort(cUrl) {
        cClean = cleanPeerUrl(cUrl)
        if cClean = "" { return ["", ""] }
        cWork = cClean
        if substr(cWork, "http://") = 1 {
            cWork = substr(cWork, 8)
        elseif substr(cWork, "https://") = 1
            cWork = substr(cWork, 9)
        ok
        nSlash = substr(cWork, "/")
        if nSlash > 0 {
            cWork = substr(cWork, 1, nSlash - 1)
        }
        nColon = substr(cWork, ":")
        if nColon > 0 {
            cHost = substr(cWork, 1, nColon - 1)
            cPort = substr(cWork, nColon + 1)
            return [cHost, cPort]
        }
        return [cWork, "80"]
    }

    func isSelfUrl(cUrl) {
        if isNull(cUrl) or cUrl = "" { return false }
        cTargetClean = cleanPeerUrl(cUrl)
        cSelfClean   = cleanPeerUrl(cMyUrl)
        if cSelfClean = "" { return false }
        if cTargetClean = cSelfClean { return true }

        aTarget = getUrlHostPort(cTargetClean)
        aSelf   = getUrlHostPort(cSelfClean)

        cTargetHost = lower(aTarget[1])
        cSelfHost   = lower(aSelf[1])
        cTargetPort = aTarget[2]
        cSelfPort   = aSelf[2]

        # Different ports mean completely different nodes!
        if cTargetPort != cSelfPort { return false }

        bTargetLocal = (cTargetHost = "127.0.0.1" or cTargetHost = "localhost" or cTargetHost = "0.0.0.0")
        bSelfLocal   = (cSelfHost = "127.0.0.1" or cSelfHost = "localhost" or cSelfHost = "0.0.0.0")

        if bTargetLocal and bSelfLocal { return true }
        if cTargetHost = cSelfHost { return true }

        return false
    }

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    func getPeers() {
        try {
            aRows = oDB.queryAssoc("SELECT url, name, last_seen, status, blocks_count FROM peers ORDER BY last_seen DESC")
            if isNull(aRows) { return [] }
            return aRows
        catch
            return []
        }
    }

    func addPeer(cUrl) {
        try {
            cUrl = cleanPeerUrl(cUrl)
            if cUrl = "" { return handleError("عنوان النظير غير صالح") }
            if isSelfUrl(cUrl) {
                return handleError("لا يمكن إضافة النود لنفسها كنظير")
            }
            cNow = date() + " " + time()

            # Test connection first
            cStatusResp = httpGet(cUrl + "/p2p/status")
            cStatus = "inactive"
            nBlocks = 0
            if not isNull(cStatusResp) and cStatusResp != "" {
                cStatus = "active"
                see "[P2P] Peer connected successfully: " + cUrl + nl
            } else {
                see "[P2P] Peer probe failed for " + cUrl + nl
            }

            oStmt = oDB.prepare("INSERT OR REPLACE INTO peers (url, name, last_seen, status, blocks_count, created_at) VALUES (?, ?, ?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cUrl)
                oStmt.bindString(2, cUrl)
                oStmt.bindString(3, cNow)
                oStmt.bindString(4, cStatus)
                oStmt.bindInt(5, nBlocks)
                oStmt.bindString(6, cNow)
                oStmt.execute()

                # If active, trigger mutual handshake and immediate sync
                if cStatus = "active" {
                    if cMyUrl != "" and cMyUrl != cUrl {
                        cHandshakeBody = '{"url":"' + cMyUrl + '","name":"' + cMyUrl + '"}'
                        httpPost(cUrl + "/p2p/register_peer", cHandshakeBody)
                        see "[P2P Handshake] Dispatched mutual registration to " + cUrl + nl
                    }
                    syncWithPeer(cUrl)
                }

                return handleSuccess([
                    :url = cUrl,
                    :status = cStatus,
                    :last_seen = cNow
                ])
            }
            return handleError("فشل في حفظ النظير")
        catch
            return handleError(cCatchError)
        }
    }

    func removePeer(cUrl) {
        try {
            cUrl = cleanPeerUrl(cUrl)
            oDB.execute("DELETE FROM peers WHERE url = '" + cUrl + "' OR url = '" + cUrl + "/'")
            return handleSuccess(true)
        catch
            return handleError(cCatchError)
        }
    }

    /* Sync with all active peers */
    func syncAll() {
        if bSyncing {
            return [ :status = "already_syncing", :synced_posts = 0, :synced_blocks = 0, :peers_count = 0 ]
        }
        bSyncing = true
        nTotalPosts = 0
        nTotalBlocks = 0
        nTotalMsgs = 0
        nPeersReached = 0

        try {
            # Auto-ensure default Mother node is discovered if we are a peer node
            if cMyUrl != "" and not isSelfUrl("http://127.0.0.1:8545") {
                aCheckMother = oDB.queryAssoc("SELECT url FROM peers WHERE url LIKE '%:8545' OR url LIKE '%:8545/' LIMIT 1")
                if isNull(aCheckMother) or len(aCheckMother) = 0 {
                    addPeer("http://127.0.0.1:8545")
                }
            }

            aPeers = getPeers()
            for aP in aPeers {
                cPeerUrl = aP[:url]
                aRes = syncWithPeer(cPeerUrl)
                if aRes[:connected] {
                    nPeersReached++
                    nTotalPosts += aRes[:posts]
                    nTotalBlocks += aRes[:blocks]
                    nTotalMsgs += aRes[:messages]
                }
            }
            cLastSync = date() + " " + time()
            bSyncing = false
            return [
                :status = "success",
                :connected = nPeersReached,
                :synced_posts = nTotalPosts,
                :synced_blocks = nTotalBlocks,
                :synced_messages = nTotalMsgs,
                :last_sync = cLastSync
            ]
        catch
            bSyncing = false
            see "Error in syncAll: " + cCatchError + nl
            return [ :status = "error", :error = cCatchError, :last_sync = cLastSync ]
        }
    }

    /* Sync with a single peer */
    func syncWithPeer(cPeerUrl) {
        nSyncedPosts = 0
        nSyncedBlocks = 0
        nSyncedMsgs = 0
        bConnected = false
        cNow = date() + " " + time()

        try {
            # 1. Ping status
            cStatus = httpGet(cPeerUrl + "/p2p/status")
            if isNull(cStatus) or cStatus = "" {
                oDB.execute("UPDATE peers SET status = 'offline' WHERE url = '" + cPeerUrl + "'")
                return [:connected = false, :posts = 0, :blocks = 0, :messages = 0]
            }
            bConnected = true
            oDB.execute("UPDATE peers SET status = 'active', last_seen = '" + cNow + "' WHERE url = '" + cPeerUrl + "'")

            # Mutual handshake: ensure peer registers us so we appear in its active peers table
            if cMyUrl != "" and cMyUrl != cPeerUrl {
                cHandshakeBody = '{"url":"' + cMyUrl + '","name":"' + cMyUrl + '"}'
                httpPost(cPeerUrl + "/p2p/register_peer", cHandshakeBody)
            }

            # 2. Pull missing posts
            cPostsJson = httpGet(cPeerUrl + "/p2p/posts")
            if not isNull(cPostsJson) and cPostsJson != "" and cPostsJson != "[]" {
                nSyncedPosts = importPosts(cPostsJson)
            }

            # 3. Pull missing comments
            cCommentsJson = httpGet(cPeerUrl + "/p2p/comments")
            if not isNull(cCommentsJson) and cCommentsJson != "" and cCommentsJson != "[]" {
                importComments(cCommentsJson)
            }

            # 4. Pull missing ratings
            cRatingsJson = httpGet(cPeerUrl + "/p2p/ratings")
            if not isNull(cRatingsJson) and cRatingsJson != "" and cRatingsJson != "[]" {
                importRatings(cRatingsJson)
            }

            # 5. Pull missing blocks
            cBlocksJson = httpGet(cPeerUrl + "/p2p/blocks")
            if not isNull(cBlocksJson) and cBlocksJson != "" and cBlocksJson != "[]" {
                nSyncedBlocks = importBlocks(cBlocksJson)
            }

            # 6. Pull messages
            cMsgsJson = httpGet(cPeerUrl + "/p2p/messages")
            if not isNull(cMsgsJson) and cMsgsJson != "" and cMsgsJson != "[]" {
                nSyncedMsgs = importMessages(cMsgsJson)
            }

            # 7. Pull transactions
            cTxsJson = httpGet(cPeerUrl + "/p2p/transactions")
            if not isNull(cTxsJson) and cTxsJson != "" and cTxsJson != "[]" {
                importTransactions(cTxsJson)
            }

            # 7.5 Pull users & avatars
            cUsersJson = httpGet(cPeerUrl + "/p2p/users")
            if not isNull(cUsersJson) and cUsersJson != "" and cUsersJson != "[]" {
                importUsers(cUsersJson, cPeerUrl)
            }

            # 8. Discover new gossip peers
            cPeersJson = httpGet(cPeerUrl + "/p2p/peers")
            if not isNull(cPeersJson) and cPeersJson != "" and cPeersJson != "[]" {
                discoverPeers(cPeersJson, cPeerUrl)
            }

            see "[P2P Sync] Successfully synced with " + cPeerUrl + " (+ " + string(nSyncedPosts) + " posts, " + string(nSyncedBlocks) + " blocks)" + nl
            return [:connected = true, :posts = nSyncedPosts, :blocks = nSyncedBlocks, :messages = nSyncedMsgs]
        catch
            see "Error syncing with peer " + cPeerUrl + ": " + cCatchError + nl
            return [:connected = false, :posts = 0, :blocks = 0, :messages = 0]
        }
    }

    /* Request direct refill / faucet grant from Mother Node */
    func requestMotherRefill(cMotherUrl, cUserId, nAmount) {
        try {
            cMotherUrl = trim(cMotherUrl)
            if cMotherUrl = "" { cMotherUrl = "http://127.0.0.1:8545" }
            if substr(cMotherUrl, "http://") != 1 and substr(cMotherUrl, "https://") != 1 {
                cMotherUrl = "http://" + cMotherUrl
            }
            if nAmount <= 0 { nAmount = 50 }

            cReqBody = '{"user_id":"' + cUserId + '","amount":' + string(nAmount) + '}'
            cResp = httpPost(cMotherUrl + "/p2p/faucet_request", cReqBody)
            if isNull(cResp) or cResp = "" {
                return handleError("تعذر الاتصال بالنود الأم على " + cMotherUrl)
            }

            cSuccess = extractVal(cResp, "success")
            if cSuccess = "true" {
                cTxId = extractVal(cResp, "tx_id")
                cSender = extractVal(cResp, "sender_id")
                if cSender = "" { cSender = "GENESIS_FAUCET" }
                cRecv = extractVal(cResp, "receiver_id")
                if cRecv = "" { cRecv = cUserId }
                cNow = date() + " " + time()

                # Record locally
                oStmt = oDB.prepare("INSERT OR REPLACE INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, 'GENESIS_MOTHER_SIGNATURE', 'block_genesis', 'confirmed', ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cTxId)
                    oStmt.bindString(2, cSender)
                    oStmt.bindString(3, cRecv)
                    oStmt.bindFloat(4, nAmount)
                    oStmt.bindString(5, cNow)
                    oStmt.execute()
                    see "[P2P] Successfully received refill of " + string(nAmount) + " WALA from Mother Node (" + cMotherUrl + ") tx=" + cTxId + nl
                    return handleSuccess([
                        :success = true,
                        :tx_id = cTxId,
                        :amount = nAmount,
                        :status = "confirmed"
                    ])
                }
            }
            cErr = extractVal(cResp, "error")
            if cErr != "" { return handleError(cErr) }
            return handleError("فشلت عملية التعبئة من النود الأم")
        catch
            return handleError(cCatchError)
        }
    }

    /* Broadcast a local entity to all known active peers (fire-and-forget) */
    func broadcast(cType, aData) {
        try {
            aPeers = getPeers()
            if len(aPeers) = 0 { return }

            cSender = cMyUrl
            if cSender = "" { cSender = "http://127.0.0.1:8546" }
            cJsonBody = '{"type":"' + cType + '","sender_url":"' + cSender + '"'
            for aPair in aData {
                cKey = string(aPair[1])
                cVal = aPair[2]
                if not isNull(cVal) {
                    if type(cVal) = "NUMBER" {
                        cJsonBody += ',"' + cKey + '":' + string(cVal)
                    else
                        cClean = string(cVal)
                        cClean = substr(cClean, '\', '\\')
                        cClean = substr(cClean, '"', '\"')
                        cClean = substr(cClean, char(10), '\n')
                        cClean = substr(cClean, char(13), '')
                        cJsonBody += ',"' + cKey + '":"' + cClean + '"'
                    ok
                }
            }
            cJsonBody += '}'

            for aP in aPeers {
                cPeerUrl = trim(aP[:url])
                if cPeerUrl = "" { loop }
                if isSelfUrl(cPeerUrl) { loop }
                if aP[:status] = "active" or aP[:status] = "unknown" or substr(cPeerUrl, ":8545") > 0 {
                    sendBroadcast(cPeerUrl + "/p2p/broadcast", cJsonBody)
                }
            }
        catch
            see "Error in broadcast: " + cCatchError + nl
        }
    }

    # ------------------------------------------------------------------
    # Importers
    # ------------------------------------------------------------------

    func importUsers(cJson, cPeerUrl) {
        nCount = 0
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cUsername = extractVal(cObj, "username")
                cBio = extractVal(cObj, "bio")
                cAvatarCid = extractVal(cObj, "avatar_cid")
                cAvatarData = extractVal(cObj, "avatar_data")
                cCreated = extractVal(cObj, "created_at")

                if cId != "" {
                    if cAvatarData != "" {
                        cStored = oMediaStorage.storeMedia(cAvatarData)
                        if cAvatarCid = "" { cAvatarCid = cStored }
                    }
                    if cAvatarCid != "" and not oMediaStorage.hasMedia(cAvatarCid) {
                        fetchMediaBlob(cPeerUrl, cAvatarCid)
                    }
                    # Non-destructive upsert: preserves local private_key_iv, private_key_salt, and encrypted keys!
                    oStmt = oDB.prepare("INSERT INTO users (id, username, bio, avatar_cid, avatar_data, public_key, encrypted_private_key, created_at) VALUES (?, ?, ?, ?, '', 'auto_key', 'none', ?) ON CONFLICT(id) DO UPDATE SET username = excluded.username, bio = excluded.bio, avatar_cid = CASE WHEN excluded.avatar_cid != '' THEN excluded.avatar_cid ELSE users.avatar_cid END")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cUsername)
                        oStmt.bindString(3, cBio)
                        oStmt.bindString(4, cAvatarCid)
                        oStmt.bindString(5, cCreated)
                        oStmt.execute()
                        nCount++
                    }
                }
            end
            see "[P2P Sync] Synced " + string(nCount) + " users and avatars from " + cPeerUrl + nl
            return nCount
        catch
            see "Error in importUsers: " + cCatchError + nl
            return nCount
        }
    }

    func importPosts(cJson) {
        nCount = 0
        try {
            # Extract each post block {...}
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cUser = extractVal(cObj, "user_id")
                cContent = extractVal(cObj, "content")
                cMediaCid = extractVal(cObj, "media_cid")
                cMediaData = extractVal(cObj, "media_data")
                cCreated = extractVal(cObj, "created_at")

                if cId != "" and cUser != "" {
                    if cMediaData != "" {
                        cStoredCid = oMediaStorage.storeMedia(cMediaData)
                        if cMediaCid = "" { cMediaCid = cStoredCid }
                    }
                    oStmt = oDB.prepare("INSERT OR IGNORE INTO posts (id, user_id, content, media_cid, media_data, created_at) VALUES (?, ?, ?, ?, '', ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cUser)
                        oStmt.bindString(3, cContent)
                        oStmt.bindString(4, cMediaCid)
                        oStmt.bindString(5, cCreated)
                        oStmt.execute()

                        # Also populate feed_cache so feed shows post immediately
                        oStmt2 = oDB.prepare("INSERT OR IGNORE INTO feed_cache (post_id, author_pubkey, content, media_cid, media_data, likes_count, merit_score, created_at) VALUES (?, ?, ?, ?, '', 0, 10.0, ?)")
                        if not isNull(oStmt2) {
                            oStmt2.bindString(1, cId)
                            oStmt2.bindString(2, cUser)
                            oStmt2.bindString(3, cContent)
                            oStmt2.bindString(4, cMediaCid)
                            oStmt2.bindString(5, cCreated)
                            oStmt2.execute()
                        }

                        nCount++
                    }
                }
            end
            return nCount
        catch
            return nCount
        }
    }

    func importComments(cJson) {
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cPostId = extractVal(cObj, "post_id")
                cUser = extractVal(cObj, "user_id")
                cContent = extractVal(cObj, "content")
                cCreated = extractVal(cObj, "created_at")

                if cId != "" and cPostId != "" {
                    oStmt = oDB.prepare("INSERT OR IGNORE INTO comments (id, post_id, user_id, content, created_at) VALUES (?, ?, ?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cPostId)
                        oStmt.bindString(3, cUser)
                        oStmt.bindString(4, cContent)
                        oStmt.bindString(5, cCreated)
                        oStmt.execute()
                    }
                }
            end
        catch
        }
    }

    func importRatings(cJson) {
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cUser = extractVal(cObj, "user_id")
                cPostId = extractVal(cObj, "post_id")
                cStars = extractVal(cObj, "stars")
                cCreated = extractVal(cObj, "created_at")

                if cUser != "" and cPostId != "" {
                    nStars = number(cStars)
                    if nStars < 1 { nStars = 5 }
                    oStmt = oDB.prepare("INSERT OR REPLACE INTO ratings (user_id, post_id, stars, created_at) VALUES (?, ?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cUser)
                        oStmt.bindString(2, cPostId)
                        oStmt.bindInt(3, nStars)
                        oStmt.bindString(4, cCreated)
                        oStmt.execute()
                    }
                }
            end
        catch
        }
    }

    func importBlocks(cJson) {
        nCount = 0
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cPrev = extractVal(cObj, "previous_hash")
                cMerkle = extractVal(cObj, "merkle_root")
                cNonce = extractVal(cObj, "nonce")
                cHash = extractVal(cObj, "hash")
                cTs = extractVal(cObj, "timestamp")
                cCreated = extractVal(cObj, "created_at")

                if cId != "" and cHash != "" {
                    nNonce = number(cNonce)
                    oStmt = oDB.prepare("INSERT OR REPLACE INTO blocks (id, previous_hash, merkle_root, nonce, hash, timestamp, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cPrev)
                        oStmt.bindString(3, cMerkle)
                        oStmt.bindInt(4, nNonce)
                        oStmt.bindString(5, cHash)
                        oStmt.bindString(6, cTs)
                        oStmt.bindString(7, cCreated)
                        oStmt.execute()
                        nCount++
                    }
                }
            end
            return nCount
        catch
            return nCount
        }
    }

    func importMessages(cJson) {
        nCount = 0
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cSender = extractVal(cObj, "sender_id")
                cReceiver = extractVal(cObj, "receiver_id")
                cEnc = extractVal(cObj, "encrypted_content")
                cIv = extractVal(cObj, "iv")
                cCreated = extractVal(cObj, "created_at")

                if cId != "" and cReceiver != "" {
                    oStmt = oDB.prepare("INSERT OR IGNORE INTO messages (id, sender_id, receiver_id, encrypted_content, encrypted_key, iv, salt, is_read, created_at) VALUES (?, ?, ?, ?, 'e2ee', ?, '', 0, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cSender)
                        oStmt.bindString(3, cReceiver)
                        oStmt.bindString(4, cEnc)
                        oStmt.bindString(5, cIv)
                        oStmt.bindString(6, cCreated)
                        oStmt.execute()
                        nCount++
                    }
                }
            end
            return nCount
        catch
            return nCount
        }
    }
    func importTransactions(cJson) {
        nCount = 0
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cId = extractVal(cObj, "id")
                cSender = extractVal(cObj, "sender_id")
                cReceiver = extractVal(cObj, "receiver_id")
                cAmount = extractVal(cObj, "amount")
                cSig = extractVal(cObj, "signature")
                cCreated = extractVal(cObj, "created_at")

                cNonce = extractVal(cObj, "nonce")
                nTxNonce = number(cNonce)

                if cId != "" and cReceiver != "" {
                    nAmt = number(cAmount)
                    # Anti-replay defense: Verify nonce if sender is known user and not genesis faucet
                    if cSender != "GENESIS_FAUCET" and cSender != "" and nTxNonce > 0 {
                        nKnownNonce = oDB.getUserNonce(cSender)
                        if nTxNonce <= nKnownNonce {
                            # Replayed transaction detected! Ignore
                            loop
                        }
                        oDB.execute("UPDATE users SET nonce = " + string(nTxNonce) + " WHERE id = '" + cSender + "'")
                    }

                    oStmt = oDB.prepare("INSERT OR IGNORE INTO transactions (id, sender_id, receiver_id, amount, nonce, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, ?, 'block_p2p', 'confirmed', ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cId)
                        oStmt.bindString(2, cSender)
                        oStmt.bindString(3, cReceiver)
                        oStmt.bindFloat(4, nAmt)
                        oStmt.bindInt(5, nTxNonce)
                        oStmt.bindString(6, cSig)
                        oStmt.bindString(7, cCreated)
                        oStmt.execute()
                        nCount++
                    }
                }
            end
            return nCount
        catch
            return nCount
        }
    }

    func discoverPeers(cJson, cOriginPeer) {
        try {
            nStart = 1
            while true
                nObjStart = substr(cJson, "{", nStart)
                if nObjStart = 0 { exit }
                nObjEnd = substr(cJson, "}", nObjStart)
                if nObjEnd = 0 { exit }
                cObj = substr(cJson, nObjStart, nObjEnd - nObjStart + 1)
                nStart = nObjEnd + 1

                cPeerUrl = extractVal(cObj, "url")
                if cPeerUrl != "" and cPeerUrl != cOriginPeer and not isSelfUrl(cPeerUrl) {
                    # Add discovered peer if not existing
                    aExist = oDB.queryAssoc("SELECT url FROM peers WHERE url = '" + cPeerUrl + "' LIMIT 1")
                    if isNull(aExist) or len(aExist) = 0 {
                        cNow = date() + " " + time()
                        oStmt = oDB.prepare("INSERT INTO peers (url, name, last_seen, status, blocks_count, created_at) VALUES (?, ?, ?, 'unknown', 0, ?)")
                        if not isNull(oStmt) {
                            oStmt.bindString(1, cPeerUrl)
                            oStmt.bindString(2, cPeerUrl)
                            oStmt.bindString(3, cNow)
                            oStmt.bindString(4, cNow)
                            oStmt.execute()
                            see "[Gossip] Discovered new peer from network: " + cPeerUrl + nl
                        }
                    }
                }
            end
        catch
        }
    }

    # ------------------------------------------------------------------
    # HTTP Client Helpers
    # ------------------------------------------------------------------

    func httpGet(cUrl) {
        cUrl = trim(cUrl)
        if cUrl = "" { return NULL }

        # 1. Try download() first (Universal on Android and Desktop via internetlib)
        try {
            cDownloadResp = download(cUrl)
            if not isNull(cDownloadResp) and cDownloadResp != "" {
                return cDownloadResp
            }
        catch
        }

        # 2. Try libcurl easy perform if download failed or not defined
        try {
            curl = curl_easy_init()
            if not isNull(curl) {
                curl_easy_setopt_2(curl, get_curlopt_url(), cUrl)
                curl_easy_setopt_1(curl, get_curlopt_timeout(), 5)
                cResp = curl_easy_perform_silent(curl)
                curl_easy_cleanup(curl)
                if not isNull(cResp) and cResp != "" { return cResp }
            }
        catch
        }

        # 3. Fallback to raw socket if socket extension is loaded (Desktop)
        try {
            return httpGetSocket(cUrl)
        catch
            return NULL
        }
    }

    func httpGetSocket(cUrl) {
        cWork = cUrl
        if substr(cWork, "http://") = 1 { cWork = substr(cWork, 8) }
        if substr(cWork, "https://") = 1 { cWork = substr(cWork, 9) }
        cHost = "127.0.0.1"
        nPort = 8545
        cPath = "/"
        
        nSlash = substr(cWork, "/")
        if nSlash > 0 {
            cHostPort = substr(cWork, 1, nSlash - 1)
            cPath = substr(cWork, nSlash)
        else
            cHostPort = cWork
        }
        
        while substr(cPath, "//") = 1
            cPath = substr(cPath, 2)
        end
        if cPath = "" { cPath = "/" }

        nColon = substr(cHostPort, ":")
        if nColon > 0 {
            cHost = substr(cHostPort, 1, nColon - 1)
            nPort = number(substr(cHostPort, nColon + 1))
        else
            cHost = cHostPort
        }
        if lower(cHost) = "localhost" { cHost = "127.0.0.1" }
        
        sock = socket(AF_INET, SOCK_STREAM, 0)
        if isNull(sock) { return NULL }
        connect(sock, cHost, nPort)
        
        cCRLF = char(13) + char(10)
        cReq = "GET " + cPath + " HTTP/1.1" + cCRLF +
               "Host: " + cHost + ":" + string(nPort) + cCRLF +
               "User-Agent: Mejde-Node/1.0" + cCRLF +
               "Accept: application/json, */*" + cCRLF +
               "Connection: close" + cCRLF + cCRLF
        send(sock, cReq)
        cResp = ""
        while true
            cChunk = recv(sock, 16384)
            if isNull(cChunk) or cChunk = "" { exit }
            cResp += cChunk
        end
        close(sock)
        
        nBody = substr(cResp, char(13) + char(10) + char(13) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 4) }
        nBody = substr(cResp, char(10) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 2) }
        return cResp
    }

    func httpPost(cUrl, cBody) {
        cUrl = trim(cUrl)
        if cUrl = "" { return NULL }

        # 1. Try libcurl (Universal on Android + Desktop)
        try {
            curl = curl_easy_init()
            if not isNull(curl) {
                curl_easy_setopt_2(curl, get_curlopt_url(), cUrl)
                curl_easy_setopt_1(curl, get_curlopt_post(), 1)
                curl_easy_setopt_2(curl, get_curlopt_copypostfields(), cBody)
                curl_easy_setopt_1(curl, get_curlopt_timeout(), 5)
                hList = curl_slist_append(NULL, "Content-Type: application/json")
                curl_easy_setopt_3(curl, get_curlopt_httpheader(), hList)
                cResp = curl_easy_perform_silent(curl)
                curl_slist_free_all(hList)
                curl_easy_cleanup(curl)
                if not isNull(cResp) and cResp != "" { return cResp }
            }
        catch
        }

        # 2. Fallback to raw socket (Desktop)
        try {
            return httpPostSocket(cUrl, cBody)
        catch
            return NULL
        }
    }

    func httpPostSocket(cUrl, cBody) {
        cWork = cUrl
        if substr(cWork, "http://") = 1 { cWork = substr(cWork, 8) }
        if substr(cWork, "https://") = 1 { cWork = substr(cWork, 9) }
        cHost = "127.0.0.1"
        nPort = 8545
        cPath = "/"
        
        nSlash = substr(cWork, "/")
        if nSlash > 0 {
            cHostPort = substr(cWork, 1, nSlash - 1)
            cPath = substr(cWork, nSlash)
        else
            cHostPort = cWork
        }
        
        while substr(cPath, "//") = 1
            cPath = substr(cPath, 2)
        end
        if cPath = "" { cPath = "/" }

        nColon = substr(cHostPort, ":")
        if nColon > 0 {
            cHost = substr(cHostPort, 1, nColon - 1)
            nPort = number(substr(cHostPort, nColon + 1))
        else
            cHost = cHostPort
        }
        if lower(cHost) = "localhost" { cHost = "127.0.0.1" }
        
        sock = socket(AF_INET, SOCK_STREAM, 0)
        if isNull(sock) { return NULL }
        connect(sock, cHost, nPort)
        
        cCRLF = char(13) + char(10)
        cReq = "POST " + cPath + " HTTP/1.1" + cCRLF +
               "Host: " + cHost + ":" + string(nPort) + cCRLF +
               "Content-Type: application/json" + cCRLF +
               "Content-Length: " + string(len(cBody)) + cCRLF +
               "User-Agent: Mejde-Node/1.0" + cCRLF +
               "Connection: close" + cCRLF + cCRLF +
               cBody
        send(sock, cReq)
        cResp = ""
        while true
            cChunk = recv(sock, 16384)
            if isNull(cChunk) or cChunk = "" { exit }
            cResp += cChunk
        end
        close(sock)
        
        nBody = substr(cResp, char(13) + char(10) + char(13) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 4) }
        nBody = substr(cResp, char(10) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 2) }
        return cResp
    }

    func sendBroadcast(cUrl, cBody) {
        cUrl = trim(cUrl)
        if cUrl = "" { return }
        if isSelfUrl(cUrl) { return }

        # 1. Try libcurl (Universal on Android + Desktop)
        try {
            curl = curl_easy_init()
            if not isNull(curl) {
                curl_easy_setopt_2(curl, get_curlopt_url(), cUrl)
                curl_easy_setopt_1(curl, get_curlopt_post(), 1)
                curl_easy_setopt_2(curl, get_curlopt_copypostfields(), cBody)
                curl_easy_setopt_1(curl, get_curlopt_timeout(), 3)
                hList = curl_slist_append(NULL, "Content-Type: application/json")
                curl_easy_setopt_3(curl, get_curlopt_httpheader(), hList)
                curl_easy_perform_silent(curl)
                curl_slist_free_all(hList)
                curl_easy_cleanup(curl)
                return
            }
        catch
        }

        # 2. Fallback to raw socket
        try {
            sendBroadcastSocket(cUrl, cBody)
        catch
        }
    }

    func sendBroadcastSocket(cUrl, cBody) {
        try {
            cWork = cUrl
            if substr(cWork, "http://") = 1 { cWork = substr(cWork, 8) }
            if substr(cWork, "https://") = 1 { cWork = substr(cWork, 9) }
            cHost = "127.0.0.1"
            nPort = 8545
            cPath = "/p2p/broadcast"
            
            nSlash = substr(cWork, "/")
            if nSlash > 0 {
                cHostPort = substr(cWork, 1, nSlash - 1)
                cPath = substr(cWork, nSlash)
            else
                cHostPort = cWork
            }
            
            while substr(cPath, "//") = 1
                cPath = substr(cPath, 2)
            end
            if cPath = "" { cPath = "/p2p/broadcast" }

            nColon = substr(cHostPort, ":")
            if nColon > 0 {
                cHost = substr(cHostPort, 1, nColon - 1)
                nPort = number(substr(cHostPort, nColon + 1))
            else
                cHost = cHostPort
            }
            if lower(cHost) = "localhost" { cHost = "127.0.0.1" }
            
            sock = socket(AF_INET, SOCK_STREAM, 0)
            if isNull(sock) { return }
            connect(sock, cHost, nPort)
            
            cCRLF = char(13) + char(10)
            cReq = "POST " + cPath + " HTTP/1.1" + cCRLF +
                   "Host: " + cHost + ":" + string(nPort) + cCRLF +
                   "Content-Type: application/json" + cCRLF +
                   "Content-Length: " + string(len(cBody)) + cCRLF +
                   "Connection: close" + cCRLF + cCRLF +
                   cBody
            send(sock, cReq)
            # Fire-and-forget: do not block UI thread on recv
            close(sock)
        catch
        }
    }

    func extractVal(cJson, cKey) {
        cTarget = '"' + cKey + '":'
        nPos = substr(cJson, cTarget)
        if nPos = 0 {
            cTarget = '"' + cKey + '" :'
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
        } else {
            nEnd = nStart
            while nEnd <= len(cJson) and cJson[nEnd] != ',' and cJson[nEnd] != '}' and cJson[nEnd] != char(13) and cJson[nEnd] != char(10)
                nEnd++
            end
            return trim(substr(cJson, nStart, nEnd - nStart))
        }
    }

    func getLastSync() {
        return cLastSync
    }

    /* Fetch missing media blob from a peer by hash and cache locally */
    func fetchMediaBlob(cPeerUrl, cHash) {
        try {
            if isNull(cHash) or cHash = "" { return "" }
            if oMediaStorage.hasMedia(cHash) {
                return oMediaStorage.getMedia(cHash)
            }
            cResp = httpGet(cPeerUrl + "/p2p/media/" + cHash)
            if not isNull(cResp) and cResp != "" {
                cBlob = extractVal(cResp, "data")
                if cBlob != "" {
                    oMediaStorage.storeMedia(cBlob)
                    return cBlob
                }
            }
            return ""
        catch
            return ""
        }
    }

    private
        oDB
        bSyncing
        cLastSync = ""
        cMyUrl = ""
        oMediaStorage
}
