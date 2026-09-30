/* ====================================================================
 * Mejde Network - P2P Gossip Server Daemon
 * Listens for incoming P2P connections and synchronizes with peer nodes.
 *
 * Usage:
 *   ring p2p/P2PServer.ring [port] [db_file]
 * Example:
 *   ring p2p/P2PServer.ring 8545 social.db
 *   ring p2p/P2PServer.ring 8546 social_2.db
 * ==================================================================== */



nPort = 8545
cDbPath = "social.db"

# sysargv[1] = ring executable
# sysargv[2] = P2PServer.ring
# sysargv[3] = port
# sysargv[4] = db_path
if len(sysargv) >= 3 and sysargv[3] != "" {
    try {
        nPort = number(sysargv[3])
    catch
        nPort = 8545
    }
}

if len(sysargv) >= 4 and sysargv[4] != "" {
    cDbPath = sysargv[4]
}

see "==================================================" + nl
see "  Mejde P2P Gossip Node Server Starting...       " + nl
see "  Listening Port: " + string(nPort) + nl
see "  Companion DB:   " + cDbPath + nl
see "==================================================" + nl

oDatabase = new Database(cDbPath)
oMediaStorage = new MediaStorageService("")
oMediaStorage.setDB(oDatabase)

# Purge any self-peer rows from database
try {
    oDatabase.execute("DELETE FROM peers WHERE url LIKE '%:" + string(nPort) + "' OR url LIKE '%:" + string(nPort) + "/%'")
catch
}

# Initialize TCP Server Socket
sock = socket(AF_INET, SOCK_STREAM, 0)
if isNull(sock) {
    see "Failed to create socket!" + nl
    return
}

# Bind to all interfaces
bind(sock, "0.0.0.0", nPort)

# Listen for connections
listen(sock, 20)

see "P2P Gossip Node listening on port " + string(nPort) + "... Ready for peer sync." + nl

while true
    client = accept(sock)
    if not isNull(client) {
        handlePeerRequest(client, oDatabase, nPort)
    }
end

# ----------------------------------------------------------------------
# Request Handler
# ----------------------------------------------------------------------

func handlePeerRequest(client, oDatabase, nPort) {
    try {
        cData = recv(client, 65536)
        if isNull(cData) or cData = "" {
            close(client)
            return
        }

        # Parse HTTP method and path
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

        # Handle CORS Preflight
        if cMethod = "OPTIONS" {
            sendResponse(client, 200, "OK", '{"status":"ok"}')
            return
        }

        # Route endpoints
        if cMethod = "GET" and cPath = "/p2p/status" {
            # Gather node status
            aBlocks = oDB.queryAssoc("SELECT count(*) as cnt FROM blocks")
            aPosts  = oDB.queryAssoc("SELECT count(*) as cnt FROM posts")
            aUsers  = oDB.queryAssoc("SELECT count(*) as cnt FROM users")
            aTxs    = oDB.queryAssoc("SELECT count(*) as cnt FROM transactions")

            nB = 0
            nP = 0
            nU = 0
            nT = 0
            if len(aBlocks) > 0 { nB = number(aBlocks[1][:cnt]) }
            if len(aPosts) > 0 { nP = number(aPosts[1][:cnt]) }
            if len(aUsers) > 0 { nU = number(aUsers[1][:cnt]) }
            if len(aTxs) > 0 { nT = number(aTxs[1][:cnt]) }

            cJson = '{"node_id":"node_' + string(nPort) + '","port":' + string(nPort) + ',"blocks":' + string(nB) + ',"posts":' + string(nP) + ',"users":' + string(nU) + ',"transactions":' + string(nT) + ',"network":"Mejde MainNet Alpha","version":"1.0.0-mejde"}'
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/blocks") = 1 {
            aBlocks = oDB.queryAssoc("SELECT * FROM blocks ORDER BY timestamp ASC LIMIT 100")
            cJson = listToJson(aBlocks)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/posts") = 1 {
            aPosts = oDB.queryAssoc("SELECT * FROM posts ORDER BY created_at ASC LIMIT 100")
            cJson = listToJson(aPosts)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/comments") = 1 {
            aComments = oDB.queryAssoc("SELECT * FROM comments ORDER BY created_at ASC LIMIT 200")
            cJson = listToJson(aComments)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/ratings") = 1 {
            aRatings = oDB.queryAssoc("SELECT * FROM ratings ORDER BY created_at ASC LIMIT 200")
            cJson = listToJson(aRatings)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/users") = 1 {
            aUsers = oDB.queryAssoc("SELECT id, username, public_key, bio, avatar_cid, avatar_data, created_at FROM users LIMIT 100")
            cJson = listToJson(aUsers)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/peers") = 1 {
            aPeers = oDatabase.queryAssoc("SELECT url, name, last_seen, status FROM peers LIMIT 50")
            cJson = listToJson(aPeers)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "POST" and cPath = "/p2p/register_peer" {
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
            if cBody != "" {
                cPeerUrl = extractJsonVal(cBody, "url")
                if cPeerUrl != "" {
                    if substr(cPeerUrl, "http://") != 1 and substr(cPeerUrl, "https://") != 1 {
                        cPeerUrl = "http://" + cPeerUrl
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
                        sendResponse(client, 200, "OK", '{"success":true,"registered":"' + cPeerUrl + '"}')
                        return
                    }
                }
            }
            sendResponse(client, 400, "Bad Request", '{"error":"invalid peer url"}')
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/messages") = 1 {
            # Extract user_id parameter if any
            cUserId = ""
            nPos = substr(cPath, "user_id=")
            if nPos > 0 {
                cUserId = substr(cPath, nPos + 8)
            }
            if cUserId != "" {
                aMsgs = oDB.queryAssoc("SELECT * FROM messages WHERE receiver_id = '" + cUserId + "' ORDER BY created_at ASC LIMIT 100")
            else 
                aMsgs = oDB.queryAssoc("SELECT * FROM messages ORDER BY created_at ASC LIMIT 100")
            }
            cJson = listToJson(aMsgs)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        if cMethod = "GET" and substr(cPath, "/p2p/transactions") = 1 {
            aTxs = oDB.queryAssoc("SELECT id, sender_id, receiver_id, amount, signature, block_id, status, created_at FROM transactions WHERE status = 'confirmed' ORDER BY created_at ASC LIMIT 200")
            cJson = listToJson(aTxs)
            sendResponse(client, 200, "OK", cJson)
            return
        }

        # Mother Node Genesis Faucet Refill Endpoint
        if cMethod = "POST" and cPath = "/p2p/faucet_request" {
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
            if cBody != "" {
                cUserId = extractJsonVal(cBody, "user_id")
                cAmount = extractJsonVal(cBody, "amount")
                nAmount = number(cAmount)
                if nAmount <= 0 { nAmount = 50 }
                if cUserId != "" {
                    cNow = date() + " " + time()
                    cTxId = "grant_" + string(random(999999999)) + "_" + substr(cNow, 12, 2) + substr(cNow, 15, 2) + substr(cNow, 18, 2)
                    oStmt = oDatabase.prepare("INSERT OR REPLACE INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, 'GENESIS_FAUCET', ?, ?, 'GENESIS_MOTHER_SIGNATURE', 'block_genesis', 'confirmed', ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cTxId)
                        oStmt.bindString(2, cUserId)
                        oStmt.bindFloat(3, nAmount)
                        oStmt.bindString(4, cNow)
                        oStmt.execute()
                        see "[Mother Node Faucet] Direct grant of " + string(nAmount) + " WALA dispatched to @" + cUserId + nl
                        cResp = '{"success":true,"tx_id":"' + cTxId + '","sender_id":"GENESIS_FAUCET","receiver_id":"' + cUserId + '","amount":' + string(nAmount) + ',"created_at":"' + cNow + '"}'
                        sendResponse(client, 200, "OK", cResp)
                        return
                    }
                }
            }
            sendResponse(client, 400, "Bad Request", '{"error":"invalid faucet request"}')
            return
        }

        # 7.05 Media CAS Blob Retrieval (GET /p2p/media/{hash})
        if cMethod = "GET" and substr(cPath, "/p2p/media/") = 1 {
            cHash = substr(cPath, 12)
            nSlash = substr(cHash, "/")
            if nSlash > 0 { cHash = substr(cHash, 1, nSlash - 1) }
            nAmp = substr(cHash, "?")
            if nAmp > 0 { cHash = substr(cHash, 1, nAmp - 1) }
            cHash = trim(cHash)
            if cHash != "" and oMediaStorage.hasMedia(cHash) {
                cBlob = oMediaStorage.getMedia(cHash)
                cCleanBlob = substr(cBlob, '\', '\\')
                cCleanBlob = substr(cCleanBlob, '"', '\"')
                cCleanBlob = substr(cCleanBlob, char(10), '\n')
                cCleanBlob = substr(cCleanBlob, char(13), '')
                sendResponse(client, 200, "OK", '{"hash":"' + cHash + '","data":"' + cCleanBlob + '"}')
                return
            }
            sendResponse(client, 404, "Not Found", '{"error":"media not found"}')
            return
        }

        # 7.06 Media CAS Blob Upload (POST /p2p/media)
        if cMethod = "POST" and cPath = "/p2p/media" {
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
            cDataVal = extractJsonVal(cBody, "data")
            if cDataVal != "" {
                cHash = oMediaStorage.storeMedia(cDataVal)
                sendResponse(client, 200, "OK", '{"success":true,"hash":"' + cHash + '"}')
                return
            }
            sendResponse(client, 400, "Bad Request", '{"error":"missing data"}')
            return
        }

        # 7.1 Register Peer Endpoint (Mutual Handshake)
        if cMethod = "POST" and cPath = "/p2p/register_peer" {
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
            cPeerUrl = extractJsonVal(cBody, "url")
            if cPeerUrl != "" {
                if substr(cPeerUrl, "http://") != 1 and substr(cPeerUrl, "https://") != 1 {
                    cPeerUrl = "http://" + cPeerUrl
                }
                # Do not register ourselves
                if substr(cPeerUrl, ":" + string(nPort)) = 0 {
                    cNow = date() + " " + time()
                    oStmt = oDatabase.prepare("INSERT OR REPLACE INTO peers (url, name, last_seen, status, blocks_count, created_at) VALUES (?, ?, ?, 'active', 0, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cPeerUrl)
                        oStmt.bindString(2, cPeerUrl)
                        oStmt.bindString(3, cNow)
                        oStmt.bindString(4, cNow)
                        oStmt.execute()
                        see "[P2P Handshake] Registered peer: " + cPeerUrl + nl
                    }
                }
                sendResponse(client, 200, "OK", '{"success":true,"registered":true}')
                return
            }
            sendResponse(client, 400, "Bad Request", '{"error":"missing peer url"}')
            return
        }

        # Handling POST Broadcasts
        if cMethod = "POST" and cPath = "/p2p/broadcast" {
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
            if cBody != "" {
                handleBroadcast(cBody, oDatabase)
                sendResponse(client, 200, "OK", '{"success":true}')
                return
            }
            sendResponse(client, 400, "Bad Request", '{"error":"missing body"}')
            return
        }

        sendResponse(client, 404, "Not Found", '{"error":"unknown endpoint"}')
    catch
        sendResponse(client, 500, "Internal Server Error", '{"error":"' + cCatchError + '"}')
    }
}

func handleBroadcast(cBody, oDB) {
    try {
        # Simple extraction of type and fields from JSON
        if substr(cBody, '"type":"post"') > 0 or substr(cBody, '"type": "post"') > 0 {
            cId = extractJsonVal(cBody, "id")
            cUserId = extractJsonVal(cBody, "user_id")
            cContent = extractJsonVal(cBody, "content")
            cMedia = extractJsonVal(cBody, "media_cid")
            cMediaData = extractJsonVal(cBody, "media_data")
            cCreatedAt = extractJsonVal(cBody, "created_at")
            if cId != "" and cUserId != "" {
                oStmt = oDB.prepare("INSERT OR IGNORE INTO posts (id, user_id, content, media_cid, media_data, created_at) VALUES (?, ?, ?, ?, ?, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cUserId)
                    oStmt.bindString(3, cContent)
                    oStmt.bindString(4, cMedia)
                    oStmt.bindString(5, cMediaData)
                    oStmt.bindString(6, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip] Received and stored new post: " + cId + " from @" + cUserId + nl
                }
            }
        }

        if substr(cBody, '"type":"rating"') > 0 or substr(cBody, '"type": "rating"') > 0 {
            cUserId = extractJsonVal(cBody, "user_id")
            cPostId = extractJsonVal(cBody, "post_id")
            cStars = extractJsonVal(cBody, "stars")
            cCreatedAt = extractJsonVal(cBody, "created_at")
            if cUserId != "" and cPostId != "" {
                nStars = number(cStars)
                if nStars < 1 { nStars = 5 }
                oStmt = oDB.prepare("INSERT OR REPLACE INTO ratings (user_id, post_id, stars, created_at) VALUES (?, ?, ?, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cUserId)
                    oStmt.bindString(2, cPostId)
                    oStmt.bindInt(3, nStars)
                    oStmt.bindString(4, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip] Received rating for " + cPostId + nl
                }
            }
        }

        if substr(cBody, '"type":"comment"') > 0 or substr(cBody, '"type": "comment"') > 0 {
            cId = extractJsonVal(cBody, "id")
            cPostId = extractJsonVal(cBody, "post_id")
            cUserId = extractJsonVal(cBody, "user_id")
            cContent = extractJsonVal(cBody, "content")
            cCreatedAt = extractJsonVal(cBody, "created_at")
            if cId != "" and cPostId != "" {
                oStmt = oDB.prepare("INSERT OR IGNORE INTO comments (id, post_id, user_id, content, created_at) VALUES (?, ?, ?, ?, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cPostId)
                    oStmt.bindString(3, cUserId)
                    oStmt.bindString(4, cContent)
                    oStmt.bindString(5, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip] Received comment for " + cPostId + nl
                }
            }
        }

        if substr(cBody, '"type":"message"') > 0 or substr(cBody, '"type": "message"') > 0 {
            cId = extractJsonVal(cBody, "id")
            cSender = extractJsonVal(cBody, "sender_id")
            cReceiver = extractJsonVal(cBody, "receiver_id")
            cEnc = extractJsonVal(cBody, "encrypted_content")
            cIv = extractJsonVal(cBody, "iv")
            cCreatedAt = extractJsonVal(cBody, "created_at")
            if cId != "" and cReceiver != "" {
                oStmt = oDB.prepare("INSERT OR IGNORE INTO messages (id, sender_id, receiver_id, encrypted_content, encrypted_key, iv, salt, is_read, created_at) VALUES (?, ?, ?, ?, 'e2ee', ?, '', 0, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cSender)
                    oStmt.bindString(3, cReceiver)
                    oStmt.bindString(4, cEnc)
                    oStmt.bindString(5, cIv)
                    oStmt.bindString(6, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip] Received E2EE message for @" + cReceiver + nl
                }
            }
        }

        if substr(cBody, '"type":"transaction"') > 0 or substr(cBody, '"type": "transaction"') > 0 {
            cId = extractJsonVal(cBody, "id")
            cSender = extractJsonVal(cBody, "sender_id")
            cReceiver = extractJsonVal(cBody, "receiver_id")
            cAmount = extractJsonVal(cBody, "amount")
            cSig = extractJsonVal(cBody, "signature")
            cCreatedAt = extractJsonVal(cBody, "created_at")
            if cId != "" and cReceiver != "" {
                nAmt = number(cAmount)
                oStmt = oDB.prepare("INSERT OR IGNORE INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, 'block_p2p', 'confirmed', ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cSender)
                    oStmt.bindString(3, cReceiver)
                    oStmt.bindFloat(4, nAmt)
                    oStmt.bindString(5, cSig)
                    oStmt.bindString(6, cCreatedAt)
                    oStmt.execute()
                    see "[Gossip] Received and confirmed P2P transaction: " + cId + " (" + string(nAmt) + " WALA @" + cSender + " -> @" + cReceiver + ")" + nl
                }
            }
        }

        if substr(cBody, '"type":"profile"') > 0 or substr(cBody, '"type": "profile"') > 0 {
            cId = extractJsonVal(cBody, "id")
            cUsername = extractJsonVal(cBody, "username")
            cBio = extractJsonVal(cBody, "bio")
            cAvatarCid = extractJsonVal(cBody, "avatar_cid")
            cAvatarData = extractJsonVal(cBody, "avatar_data")
            if cId != "" {
                if cAvatarData != "" and not isNull(oMediaStorage) {
                    cStored = oMediaStorage.storeMedia(cAvatarData)
                    if cAvatarCid = "" { cAvatarCid = cStored }
                }
                oStmt = oDB.prepare("INSERT OR REPLACE INTO users (id, username, bio, avatar_cid, avatar_data, public_key, encrypted_private_key, created_at) VALUES (?, ?, ?, ?, '', COALESCE((SELECT public_key FROM users WHERE id = ?), 'auto_key'), COALESCE((SELECT encrypted_private_key FROM users WHERE id = ?), 'none'), ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cId)
                    oStmt.bindString(2, cUsername)
                    oStmt.bindString(3, cBio)
                    oStmt.bindString(4, cAvatarCid)
                    oStmt.bindString(5, cId)
                    oStmt.bindString(6, cId)
                    oStmt.bindString(7, date() + " " + time())
                    oStmt.execute()
                    see "[Gossip] Updated user profile for @" + cId + " (avatar_cid=" + cAvatarCid + ")" + nl
                }
            }
        }
    catch
        see "Error in handleBroadcast: " + cCatchError + nl
    }
}

func extractJsonVal(cJson, cKey) {
    cTarget = '"' + cKey + '":'
    nPos = substr(cJson, cTarget)
    if nPos = 0 {
        cTarget = '"' + cKey + '" :'
        nPos = substr(cJson, cTarget)
    }
    if nPos = 0 { return "" }
    nStart = nPos + len(cTarget)
    # Skip spaces
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

func listToJson(aList) {
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

func sendResponse(client, nCode, cStatus, cBody) {
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
