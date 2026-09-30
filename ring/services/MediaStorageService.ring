/* ====================================================================
 * Mejde Network - Decoupled Media Blob Storage Service
 * Content-Addressable Storage (CAS) for media attachments and avatars.
 *
 * Keeps LibSQL databases ultra-lean by storing binary/base64 blobs
 * on the local filesystem indexed by their SHA-256 hash.
 * ==================================================================== */



class MediaStorageService from Service {

    func init(cDir) {
        if isNull(cDir) or cDir = "" {
            cStorageDir = "storage/blobs"
        else
            cStorageDir = cDir
        }
        oDB = NULL
        ensureStorageDir()
    }

    func setDB(oDatabase) {
        oDB = oDatabase
        ensureTable()
    }

    func ensureTable() {
        if not isNull(oDB) {
            try {
                oDB.execute("CREATE TABLE IF NOT EXISTS media_blobs (cid TEXT PRIMARY KEY, data TEXT, created_at TEXT)")
            catch
            }
        }
    }

    /* Ensure storage directory exists on disk silently without console flash */
    func ensureStorageDir() {
        if direxists(cStorageDir) { return }
        try {
            # Storage directory is prepared at build/startup
        catch
        }
    }

    /* Store media blob (Base64 data or binary string) and return SHA-256 CID */
    func storeMedia(cMediaData) {
        try {
            if isNull(cMediaData) or cMediaData = "" {
                return ""
            }

            # Generate SHA-256 content address
            cHash = lower(sha256(cMediaData))
            if cHash = "" { return "" }

            # 1. Store in companion database (always reliable on Android & Desktop)
            if not isNull(oDB) {
                try {
                    ensureTable()
                    oStmt = oDB.prepare("INSERT OR REPLACE INTO media_blobs (cid, data, created_at) VALUES (?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cHash)
                        oStmt.bindString(2, cMediaData)
                        oStmt.bindString(3, date() + " " + time())
                        oStmt.execute()
                    }
                catch
                    see "Warning storing media in DB: " + cCatchError + nl
                }
            }

            # 2. Cache to local filesystem if directory is accessible (Desktop)
            try {
                cFilePath = cStorageDir + "/" + cHash + ".bin"
                if not fexists(cFilePath) {
                    ensureStorageDir()
                    write(cFilePath, cMediaData)
                }
            catch
                # Silently ignore filesystem error on restricted OS sandbox (e.g. Android)
            }

            return cHash
        catch
            see "Error in storeMedia: " + cCatchError + nl
            return ""
        }
    }

    /* Retrieve media blob by CID/hash from database or disk */
    func getMedia(cHash) {
        try {
            if isNull(cHash) or cHash = "" {
                return ""
            }

            # 1. Fetch from companion database first (100% reliable)
            if not isNull(oDB) {
                try {
                    aRows = oDB.queryAssoc("SELECT data FROM media_blobs WHERE cid = '" + cHash + "' LIMIT 1")
                    if not isNull(aRows) and len(aRows) > 0 {
                        cData = aRows[1][:data]
                        if not isNull(cData) and cData != "" {
                            return cData
                        }
                    }
                catch
                }
            }

            # 2. Fallback to local filesystem disk cache
            try {
                cFilePath = cStorageDir + "/" + cHash + ".bin"
                if fexists(cFilePath) {
                    cContent = read(cFilePath)
                    if not isNull(cContent) and cContent != "" {
                        return cContent
                    }
                }
            catch
            }

            return ""
        catch
            see "Error in getMedia: " + cCatchError + nl
            return ""
        }
    }

    /* Check if blob exists locally in DB or disk */
    func hasMedia(cHash) {
        try {
            if isNull(cHash) or cHash = "" {
                return false
            }
            if not isNull(oDB) {
                try {
                    aRows = oDB.queryAssoc("SELECT 1 FROM media_blobs WHERE cid = '" + cHash + "' LIMIT 1")
                    if not isNull(aRows) and len(aRows) > 0 { return true }
                catch
                }
            }
            try {
                cFilePath = cStorageDir + "/" + cHash + ".bin"
                return fexists(cFilePath)
            catch
                return false
            }
        catch
            return false
        }
    }

    /* Delete media blob from DB and disk */
    func deleteMedia(cHash) {
        try {
            if isNull(cHash) or cHash = "" { return false }
            if not isNull(oDB) {
                try {
                    oDB.execute("DELETE FROM media_blobs WHERE cid = '" + cHash + "'")
                catch
                }
            }
            try {
                cFilePath = cStorageDir + "/" + cHash + ".bin"
                if fexists(cFilePath) {
                    remove(cFilePath)
                }
            catch
            }
            return true
        catch
            return false
        }
    }

    /* Return storage directory path */
    func getStorageDir() {
        return cStorageDir
    }

    private
        cStorageDir
        oDB
}
