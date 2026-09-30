load "libsql.ring"

/* Class: Database
  
    This is the main database class for the application. It handles all database operations,
    including creating tables, inserting data, querying data, and managing database connections.

    Key features:
    - Supports both local encrypted files and offline-first replicas with sync
    - Uses LibSQL for embedded database operations
    - Safe schema upgrades with ALTER TABLE commands
    - Prepared statements to prevent SQL injection
    - Automatic error handling and logging
    - Supports social media tables: users, posts, likes, comments, follows, shares, etc.

    Usage:
    // Create a local encrypted database
    oDB = new Database("my_database.db")

    // Open a replica with sync
    oDB = new Database.initReplica(
        "my_database.db",
        "https://my-replica.com",
        "auth-token-123"
    )

    // Insert data
    oDB.execute("INSERT INTO users (id, username) VALUES (?, ?)", ["1", "test"])

    // Query data
    results = oDB.query("SELECT * FROM users WHERE id = ?", ["1"])

    // Prepare statement for safe queries
    stmt = oDB.prepare("INSERT INTO posts (user_id, content) VALUES (?, ?)")
    stmt.bindString(1, "1")
    stmt.bindString(2, "My first post!")
    stmt.execute()
 */

class Database

    /* --- Construction (matches AGENTS.md: c=string, o=object,
       {} for if/for/while, keyword try/catch/done for error handling,
       prepare + bind* for queries) --- */

    func init(cPath)
        cDbPath = cPath
        try{
            oLibSQL = new LibSQL 
            oLibSQL.openFile(cDbPath)
            oConn = oLibSQL.connect()
            createTables()
        catch
            cError = cCatchError
            see "Database init error 1: " + cCatchError + nl
            try{
                cTarget = cDbPath
                oLibSQL = new LibSQL 
                oLibSQL.openFile(cTarget)
                oConn = oLibSQL.connect()
                createTables()
                cError = ""
                see "Database opened successfully via pattern 2!" + nl
            catch
                cError = cCatchError
                see "Database init error 2: " + cCatchError + nl
            }
        }

    /* Embedded Replica (offline-first + sync) */
    func initReplica(cPath, cUrl, cToken)
        try{
            cDbPath = cPath
            cPrimaryUrl = cUrl
            cAuthToken = cToken
            oLibSQL = new LibSQL 
            oLibSQL.openSyncWithConfig([
                    :db_path = cDbPath,
                    :primary_url = cPrimaryUrl,
                    :auth_token = cAuthToken,
                    :read_your_writes = 1,
                    :sync_interval = 60
                ])
           
            oConn = oLibSQL.connect()
            createTables()
        catch
            cError = cCatchError
        }

    /* --- Schema --- */

    func createTables()
        try {
            oConn.execute('PRAGMA journal_mode = WAL')
            oConn.execute('PRAGMA busy_timeout = 5000')
            oConn.execute('PRAGMA synchronous = NORMAL')
        catch
        }
        oConn.execute('CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            email TEXT,
            public_key TEXT NOT NULL,
            encrypted_private_key TEXT NOT NULL,
            private_key_iv TEXT,
            private_key_salt TEXT,
            bio TEXT,
            avatar_cid TEXT,
            avatar_data TEXT,
            mnemonic_hash TEXT,
            encrypted_mnemonic TEXT,
            nonce INTEGER DEFAULT 0,
            status TEXT DEFAULT "active",
            created_at TEXT,
            last_login TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS posts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            content TEXT,
            media_cid TEXT,
            media_url TEXT,
            media_data TEXT,
            created_at TEXT,
            FOREIGN KEY(user_id) REFERENCES users(id)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS likes (
            user_id TEXT,
            post_id TEXT,
            created_at TEXT,
            PRIMARY KEY(user_id, post_id)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS comments (
            id TEXT PRIMARY KEY,
            post_id TEXT,
            user_id TEXT,
            content TEXT,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS follows (
            follower_id TEXT,
            followed_id TEXT,
            created_at TEXT,
            PRIMARY KEY(follower_id, followed_id)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS shares (
            user_id TEXT,
            post_id TEXT,
            created_at TEXT,
            PRIMARY KEY(user_id, post_id)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            sender_id TEXT,
            receiver_id TEXT,
            amount REAL,
            nonce INTEGER DEFAULT 0,
            signature TEXT,
            block_id TEXT,
            status TEXT,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS blocks (
            id TEXT PRIMARY KEY,
            previous_hash TEXT,
            merkle_root TEXT,
            nonce INTEGER,
            hash TEXT,
            timestamp TEXT,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS feed_cache (
            post_id TEXT PRIMARY KEY,
            author_pubkey TEXT,
            content TEXT,
            media_cid TEXT,
            media_data TEXT,
            likes_count INTEGER DEFAULT 0,
            merit_score REAL DEFAULT 0.0,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS ratings (
            user_id TEXT,
            post_id TEXT,
            stars INTEGER DEFAULT 5,
            created_at TEXT,
            PRIMARY KEY(user_id, post_id)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS sync_state (
            key TEXT PRIMARY KEY,
            value TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS contracts (
            address TEXT PRIMARY KEY,
            name TEXT,
            owner TEXT,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS contract_state (
            contract_address TEXT,
            key TEXT,
            value TEXT,
            updated_at TEXT,
            PRIMARY KEY(contract_address, key)
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            sender_id TEXT NOT NULL,
            receiver_id TEXT NOT NULL,
            encrypted_content TEXT NOT NULL,
            encrypted_key TEXT,
            iv TEXT,
            salt TEXT,
            is_read INTEGER DEFAULT 0,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS notifications (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            actor_id TEXT,
            type TEXT,
            target_id TEXT,
            title TEXT,
            message TEXT,
            is_read INTEGER DEFAULT 0,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS peers (
            url TEXT PRIMARY KEY,
            name TEXT,
            last_seen TEXT,
            status TEXT DEFAULT "active",
            blocks_count INTEGER DEFAULT 0,
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS p2p_offers (
            id TEXT PRIMARY KEY,
            seller_id TEXT NOT NULL,
            wala_amount REAL NOT NULL,
            fiat_price REAL NOT NULL,
            currency TEXT NOT NULL,
            payment_method TEXT NOT NULL,
            status TEXT DEFAULT "active",
            created_at TEXT
        )')
        oConn.execute('CREATE TABLE IF NOT EXISTS media_blobs (
            cid TEXT PRIMARY KEY,
            data TEXT,
            created_at TEXT
        )')

        # Safe schema upgrades for existing local databases
        try{
            oConn.execute('ALTER TABLE posts ADD COLUMN media_data TEXT')
        catch
        }

        try{
            oConn.execute('ALTER TABLE feed_cache ADD COLUMN media_data TEXT')
        catch
        }

        try{
            oConn.execute('ALTER TABLE feed_cache ADD COLUMN merit_score REAL DEFAULT 0.0')
        catch
        }

        try{
            oConn.execute('ALTER TABLE users ADD COLUMN mnemonic_hash TEXT')
        catch
        }
        
        try{
            oConn.execute('ALTER TABLE users ADD COLUMN encrypted_mnemonic TEXT')
        catch
        }

        try{
            oConn.execute('ALTER TABLE users ADD COLUMN avatar_data TEXT')
        catch
        }

        try{
            oConn.execute('ALTER TABLE users ADD COLUMN nonce INTEGER DEFAULT 0')
        catch
        }

        try{
            oConn.execute('ALTER TABLE transactions ADD COLUMN nonce INTEGER DEFAULT 0')
        catch
        }

    /* --- Nonce Helpers (Replay Protection) --- */

    func getUserNonce(cUserId)
        try {
            aRows = queryAssoc("SELECT nonce FROM users WHERE id = '" + cUserId + "' LIMIT 1")
            if not isNull(aRows) and len(aRows) > 0 {
                return number(aRows[1][:nonce])
            }
            return 0
        catch
            return 0
        }

    func incrementUserNonce(cUserId)
        try {
            execute("UPDATE users SET nonce = nonce + 1 WHERE id = '" + cUserId + "'")
            return true
        catch
            return false
        }

    /* --- Query helpers (no raw string interpolation) --- */

    func execute(cSQL)
        try{
            if isNull(oConn) {
                see "Database execute error: oConn is NULL!" + nl
                return NULL
            }
            return oConn.execute(cSQL)
        catch
            cError = cCatchError
            see "Database execute error: " + cCatchError + nl
            return NULL
        }

    func query(cSQL)
        try{
            if isNull(oConn) { return [] }
            return oConn.query(cSQL).fetchAll()
        catch
            cError = cCatchError
            see "Database query error: " + cCatchError + nl
            return []
        }

    func queryAssoc(cSQL)
        try{
            if isNull(oConn) { return [] }
            return oConn.query(cSQL).fetchAllAssoc()
        catch
            cError = cCatchError
            see "Database queryAssoc error: " + cCatchError + nl
            return []
        }

    /* Returns a prepared statement; callers use bindString / bindInt / bindFloat */
    func prepare(cSQL)
        try{
            if isNull(oConn) {
                see "Database prepare error: oConn is NULL!" + nl
                return NULL
            }
            return oConn.prepare(cSQL)
        catch
            cError = cCatchError
            see "Database prepare error: " + cCatchError + nl
            return NULL
        }
    /* -    -- Sync --- */

    func sync()
        try{
            if cPrimaryUrl != "" {
                oLibSQL.sync()
            }
        catch
            cError = cCatchError
        }

    /* --- Lifecycle --- */

    func close()
        try{
            oConn.disconnect()
        catch
            /* ignore */
        }

    /* --- Accessors --- */

    func getError()
        return cError

    func getConnection()
        return oConn

    /* --- Private fields (prefix conventions: c=string, o=object, b=bool) --- */
    private
        oLibSQL
        oConn
        cError
        cDbPath = "social.db"
        cPrimaryUrl = ""
        cAuthToken = ""
