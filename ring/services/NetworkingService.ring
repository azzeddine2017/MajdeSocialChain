/* Service: NetworkingService
 * Blockchain synchronization between devices via LibSQL primary server.
 *
 * Construction: new NetworkingService(oDB)
 *   oDB must be a Database instance (libsql.ring replica) with
 *   cPrimaryUrl / cAuthToken configured via initReplica(...).
 *
 *   sync()       - pull new blocks from primary; periodic via Timer (60s)
 *   pullBlocks() - fetch and apply new blocks from the network
 *   pushTransaction(tx) - broadcast a signed transaction
 *
 * Sync state is persisted in the sync_state table.
 * Network errors use exponential backoff (base 2, cap 300s).
 */
 
load "libcurl.ring"
load "core/Service.ring"
load "utils/Crypto.ring"

class NetworkingService from Service {

    /* --- Construction --- */

    func init(oDatabase) {
        if oDatabase = NULL { return handleError("Database is NULL") }
        oDB = oDatabase
        oCrypto = new Crypto()
        cPrimaryUrl = ""
        cAuthToken = ""
        nRetryDelay = 1
        nMaxRetryDelay = 300
        bSyncing = false
        cPrimaryUrl = oDB.cPrimaryUrl
        cAuthToken  = oDB.cAuthToken
        startSyncTimer()
    }

    /* --- Public API --- */

    /* sync() triggers a pull from the primary server.
     * Safe to call repeatedly; guards against concurrent runs.
     */
    func sync() {
        if bSyncing { return handleError("sync already in progress") }
        bSyncing = true
        try{
            aResult = pullBlocks()
            # reset backoff on success
            nRetryDelay = 1
            return handleSuccess(aResult)
        catch
            # exponential backoff on failure
            nRetryDelay = nRetryDelay * 2
            if nRetryDelay > nMaxRetryDelay { nRetryDelay = nMaxRetryDelay }
            cMsg = "sync failed: " + cCatchError + " (next retry in " + nRetryDelay + "s)"
            oLogger.error(cMsg)
            return handleError(cMsg)
        }
        bSyncing = false
    }

    /* pullBlocks() - fetch new blocks from network and apply local.
     * Uses sync_state.last_synced_block to skip already-applied blocks.
     */
    func pullBlocks() {
        nLastSynced = getSyncState("last_synced_block")
        if nLastSynced = NULL { nLastSynced = 0 }
        cUrl = cPrimaryUrl + "/blocks?after=" + nLastSynced
        cResp = httpGet(cUrl)
        if cResp = NULL {
            return handleError("failed to fetch blocks from primary")
        }
        aBlocks = json_decode(cResp)
        if aBlocks = NULL or len(aBlocks) = 0 {
            return [ :synced = 0, :blocks = 0 ]
        }
        nNew = 0
        for aBlock in aBlocks {
            if applyBlock(aBlock) {
                nNew = nNew + 1
            }
        }
        # persist sync watermark
        setSyncState("last_synced_block", nLastSynced + nNew)
        return [ :synced = nNew, :blocks = len(aBlocks) ]
    }

    /* pushTransaction(tx) - broadcast a signed transaction to the network.
     * tx must be a map containing at least :id, :sender_id, :receiver_id,
     * :amount, :signature, :created_at (same shape as Transaction.toList()).
     */
    func pushTransaction(aTx) {
        if aTx = NULL or aTx[:id] = NULL {
            return handleError("invalid transaction")
        }
        # sign the transaction payload with Crypto
        cPayload = json_encode(aTx)
        cPrivateKey = getLocalPrivateKey()
        if cPrivateKey = NULL {
            return handleError("no local private key available for signing")
        }
        cSignature = oCrypto.sign(cPayload, cPrivateKey)
        if cSignature = NULL {
            return handleError("transaction signing failed")
        }
        aTx[:signature] = cSignature
        cUrl = cPrimaryUrl + "/transactions"
        cBody = json_encode(aTx)
        cResp = httpPost(cUrl, cBody)
        if cResp = NULL {
            return handleError("failed to broadcast transaction")
        }
        aResult = json_decode(cResp)
        if aResult = NULL {
            return handleError("invalid response from network")
        }
        return handleSuccess(aResult)
    }

    /* --- Private helpers --- */

    /* httpGet / httpPost thin wrappers around cURL */
    func httpGet(cUrl) {
        try{
            oCurl = new cURL()
            oCurl.setURL(cUrl)
            oCurl.setHeaders([
                "Authorization: Bearer " + cAuthToken,
                "Content-Type: application/json"
            ])
            cResp = oCurl.toMemory()
            oCurl.close()
            return cResp
        catch
            cError = cCatchError
            oCurl.close()
            return NULL
        }
    }

    func httpPost(cUrl, cBody) {
        try{
            oCurl = new cURL()
            oCurl.setURL(cUrl)
            oCurl.setHeaders([
                "Authorization: Bearer " + cAuthToken,
                "Content-Type: application/json"
            ])
            oCurl.setBody(cBody)
            cResp = oCurl.toMemory()
            oCurl.close()
            return cResp
        catch
            cError = cCatchError
            oCurl.close()
            return NULL
        }
    }

    /* applyBlock(aBlock) - insert/update a block in local DB.
     * Returns true on success.
     */
    func applyBlock(aBlock) {
        try{
            cId = aBlock[:id]
            cPrev = aBlock[:previous_hash]
            cMerkle = aBlock[:merkle_root]
            nNonce = aBlock[:nonce]
            cHash = aBlock[:hash]
            cTs = aBlock[:timestamp]
            cNow = date() + " " + time()
            oStmt = oDB.prepare(
                "INSERT OR REPLACE INTO blocks " +
                "(id, previous_hash, merkle_root, nonce, hash, timestamp, created_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)"
            )
            oStmt.bindString(1, cId)
            oStmt.bindString(2, cPrev)
            oStmt.bindString(3, cMerkle)
            oStmt.bindInt(4, nNonce)
            oStmt.bindString(5, cHash)
            oStmt.bindString(6, cTs)
            oStmt.bindString(7, cNow)
            oStmt.execute()
            return true
        catch
            cErr = cCatchError
            oLogger.error("applyBlock failed: " + cErr)
            return false
        }
    }

    /* sync_state helpers */
    func getSyncState(cKey) {
        try{
            oStmt = oDB.prepare("SELECT value FROM sync_state WHERE key = ?")
            oStmt.bindString(1, cKey)
            oRows = oStmt.query()
            oRow = oRows.fetchRow()
            if oRow = NULL { return NULL }
            return oRow.getValue(1)
        catch
            return NULL
        }
    }

    func setSyncState(cKey, cValue) {
        try{
            oStmt = oDB.prepare(
                "INSERT OR REPLACE INTO sync_state (key, value) VALUES (?, ?)"
            )
            oStmt.bindString(1, cKey)
            oStmt.bindString(2, cValue)
            oStmt.execute()
        catch
            oLogger.error("setSyncState failed: " + cCatchError)
        }
    }

    /* Resolve the local node's private key from the users table.
     * This mirrors the pattern used by BlockchainService / Crypto.
     */
    func getLocalPrivateKey() {
        try{
            aRows = oDB.query(
                "SELECT encrypted_private_key, private_key_iv, private_key_salt " +
                "FROM users LIMIT 1"
            )
            if aRows = NULL or len(aRows) = 0 { return NULL }
            cEncKey = aRows[1]
            cIv     = aRows[2]
            cSalt   = aRows[3]
            # In a real app the password would come from the session / wallet.
            # Here we fall back to a placeholder so the code path is wired.
            cPassword = getWalletPassword()
            if cPassword = NULL { return NULL }
            cPrivKey = oCrypto.retrievePrivateKey(cEncKey, cIv, cSalt, cPassword)
            return cPrivKey
        catch
            oLogger.error("getLocalPrivateKey failed: " + cCatchError)
            return NULL
        }
    }

    /* Placeholder: real apps resolve the wallet passphrase from the
     * unlocked session, not from disk. Override in the app layer as needed.
     */
    func getWalletPassword() {
        # TODO: integrate with the wallet/accounts UI.
        # Returning NULL here forces callers to handle the unconfigured case.
        return NULL
    }

    /* Periodic sync via Timer (60s interval). */
    func startSyncTimer() {
        try{
            # Ring Timer fires a function periodically.
            # 60000 ms = 60 s.
            oTimer = new Timer(60000)
            oTimer.start(:sync, self)
        catch
            oLogger.error("startSyncTimer failed: " + cCatchError)
        }
    }

    /* --- Private fields --- */
    private
        oDB
        oCrypto
        oLogger
        cPrimaryUrl
        cAuthToken
        nRetryDelay
        nMaxRetryDelay
        bSyncing
}
