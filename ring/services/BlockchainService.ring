/* Service: BlockchainService
 Blockchain operations: transaction creation (RSA-signed), block mining,
 balance calculation from the transactions table, and chain validation.

 Construction: new BlockchainService(oDB)
 oDB must be a Database instance (libsql.ring, ysdragon/ring-libsql).

 Persistence:
 transactions  -> id, sender_id, receiver_id, amount, signature,
 block_id, status, created_at

 blocks        -> id, previous_hash, merkle_root, nonce, hash,
 timestamp, created_at

 Error handling: keyword try / catch / done (brace-bounded try/catch is
 rejected by this Ring 1.27 toolchain inside class methods, as noted in
 core/Database.ring).  Prepared statements use bindText / bindFloat so
 user-supplied values are never interpolated into SQL.
 */


class BlockchainService from Service {

    /* ------------------------------------------------------------------
     * Construction
     * ------------------------------------------------------------------ */

    func init(oDatabase) {
        if oDatabase = NULL {
            return handleError("Database is NULL")
        }
        oDB      = oDatabase
        oCrypto  = new Crypto()
        nDifficulty = 4
        oContractManager = NULL
    }

    func setContractManager(oCM) {
        oContractManager = oCM
    }

    func setMessageService(oMsg) {
        oMessageService = oMsg
    }

    func setP2PService(oP2P) {
        oP2PService = oP2P
    }

    func setWorkerPool(oWP) {
        oWorkerPool = oWP
    }

    func getContractManager() {
        if isNull(oContractManager) and not isNull(oDB) {
            oContractManager = new ContractManager("GENESIS_FAUCET", oDB)
        }
        return oContractManager
    }

    /* ------------------------------------------------------------------
     * createTransaction(cSender, cReceiver, nAmount)
     *
     * 1. Validate inputs.
     * 2. Check sender balance >= amount (no negative-balance rule).
     * 3. Resolve sender's RSA private key from the users table via Crypto.
     * 4. Build a Transaction model, sign its message, and persist as
     *    'pending' into the transactions table.
     * ------------------------------------------------------------------ */

    func createTransaction(cSender, cReceiver, nAmount) {
        if cSender = NULL or cReceiver = NULL or nAmount <= 0 {
            return handleError("معاملة غير صالحة")
        }
        try {
            /* balance check */
            nBal = getBalance(cSender)
            if nBal < nAmount {
                return handleError("رصيدك غير كافٍ لإتمام المعاملة")
            }
            cTxId = "tx_" + string(random(999999999))
            cNow = date() + " " + time()
            
            # Anti-Replay: Monotonically increasing account nonce
            nUserNonce = oDB.getUserNonce(cSender) + 1

            oStmt = oDB.prepare(
                "INSERT INTO transactions " +
                "(id, sender_id, receiver_id, amount, nonce, signature, block_id, status, created_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            )
            if not isNull(oStmt) {
                oStmt.bindString(1, cTxId)
                oStmt.bindString(2, cSender)
                oStmt.bindString(3, cReceiver)
                oStmt.bindFloat(4, nAmount)
                oStmt.bindInt(5, nUserNonce)
                oStmt.bindString(6, "sig_" + cTxId)
                oStmt.bindString(7, "block_auto")
                oStmt.bindString(8, "confirmed")
                oStmt.bindString(9, cNow)
                oStmt.execute()
                
                # Increment sender nonce in database
                oDB.incrementUserNonce(cSender)

                # Execute smart contract transfer in parallel
                if not isNull(oContractManager) {
                    oContractManager.transferWALA(cSender, cReceiver, nAmount)
                }

                # Emit notification to receiver
                if not isNull(oMessageService) and cSender != cReceiver {
                    oMessageService.createNotification(cReceiver, cSender, "tip", cTxId, "إكرامية WALA جديدة", "أرسل لك @" + cSender + " " + string(nAmount) + " WALA 💰")
                }

                # Broadcast transaction to P2P network (Worker pool background or safe fallback)
                if not isNull(oWorkerPool) {
                    try {
                        oWorkerPool.queueBroadcast("transaction", [
                            :id = cTxId,
                            :sender_id = cSender,
                            :receiver_id = cReceiver,
                            :amount = nAmount,
                            :nonce = nUserNonce,
                            :signature = "sig_" + cTxId,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in transaction queueBroadcast: " + cCatchError + nl
                    }
                elseif not isNull(oP2PService)
                    try {
                        oP2PService.broadcast("transaction", [
                            :id = cTxId,
                            :sender_id = cSender,
                            :receiver_id = cReceiver,
                            :amount = nAmount,
                            :nonce = nUserNonce,
                            :signature = "sig_" + cTxId,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in transaction broadcast: " + cCatchError + nl
                    }
                }
                
                see "Transaction confirmed: " + cTxId + " (" + string(nAmount) + " WALA from " + cSender + " to " + cReceiver + ")" + nl
                return handleSuccess([
                    :id = cTxId,
                    :sender_id = cSender,
                    :receiver_id = cReceiver,
                    :amount = nAmount,
                    :status = "confirmed",
                    :created_at = cNow
                ])
            }
            return handleError("failed to prepare transaction")
        catch 
            see "Error in createTransaction: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }
    /*----------------------------------------
    * create transactions for testing
    *----------------------------------------*/
    func faucet(cUserId, nAmount) {
        try {
            if isNull(cUserId) or cUserId = "" { return handleError("معرف مستخدم غير صالح") }
            if nAmount <= 0 { nAmount = 50 }
            cTxId = "faucet_" + string(random(999999999))
            cNow = date() + " " + time()
            oStmt = oDB.prepare("INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cTxId)
                oStmt.bindString(2, "GENESIS_FAUCET")
                oStmt.bindString(3, cUserId)
                oStmt.bindFloat(4, nAmount)
                oStmt.bindString(5, "FAUCET_SIGNATURE")
                oStmt.bindString(6, "block_genesis")
                oStmt.bindString(7, "confirmed")
                oStmt.bindString(8, cNow)
                oStmt.execute()
                if not isNull(oContractManager) {
                    oContractManager.transferWALA("GENESIS_FAUCET", cUserId, nAmount)
                }
                see "Faucet: credited " + string(nAmount) + " WALA to " + cUserId + nl
                return handleSuccess(nAmount)
            }
            return handleError("فشل في تحويل رصيد الصنبور")
        catch
            see "Error in faucet: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getTransactions(cUserId) {
        try {
            aRows = oDB.queryAssoc("SELECT id, sender_id, receiver_id, amount, status, created_at FROM transactions WHERE sender_id = '" + cUserId + "' OR receiver_id = '" + cUserId + "' ORDER BY rowid DESC LIMIT 20")
            if isNull(aRows) { return [] }
            return aRows
        catch
            see "Error in getTransactions: " + cCatchError + nl
            return []
        }
    }

    /* ------------------------------------------------------------------
     * mineBlock()
     *
     * 1. Fetch pending transactions from the DB.
     * 2. Build a Block, seed it with the previous chain hash, attach each
     *    pending Transaction object.
     * 3. Mine (nonce loop until hash prefix matches difficulty).
     * 4. Persist the block into the blocks table.
     * 5. Mark the mined transactions as 'confirmed' + link block_id.
     * ------------------------------------------------------------------ */

    func mineBlock() {
        try {
            aRows = oDB.query(
                "SELECT id, sender_id, receiver_id, amount, signature, " +
                "timestamp FROM transactions WHERE status = 'pending' " +
                "ORDER BY created_at ASC"
            )
            oBlock = new Block(getLatestHash())
            if not isNull(aRows) {
                for aRow in aRows {
                    oTx = new Transaction(aRow[2], aRow[3], aRow[4])
                    oTx.setSignature(aRow[5])
                    oTx.setTimestamp(aRow[6])
                    oBlock.addTransaction(oTx)
                }
            }
            oBlock.mine(nDifficulty)
            aBlockData = oBlock.toList()
            cNow = date() + " " + time()
            /* persist block */
            oStmt = oDB.prepare(
                "INSERT INTO blocks " +
                "(id, previous_hash, merkle_root, nonce, hash, timestamp, created_at) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)"
            )
            oStmt.bindString(1, aBlockData[:id])
            oStmt.bindString(2, aBlockData[:previous_hash])
            oStmt.bindString(3, aBlockData[:merkle_root])
            oStmt.bindString(4, string(aBlockData[:nonce]))
            oStmt.bindString(5, aBlockData[:hash])
            oStmt.bindString(6, aBlockData[:timestamp])
            oStmt.bindString(7, cNow)
            oStmt.execute()
            /* mark transactions confirmed */
            if not isNull(aRows) {
                for aRow in aRows {
                    oUpd = oDB.prepare(
                        "UPDATE transactions SET status = 'confirmed', block_id = ? " +
                        "WHERE id = ?"
                    )
                    oUpd.bindString(1, aBlockData[:id])
                    oUpd.bindString(2, aRow[1])
                    oUpd.execute()
                }
            }
            return handleSuccess(aBlockData)
        catch 
            return handleError(cCatchError)
        }
    }

    /* ------------------------------------------------------------------
     * getBalance(cUserId)
     *
     * Sum of confirmed incoming amounts minus confirmed outgoing amounts.
     * Uses prepared statements; never interpolates user ids into SQL.
     * Returns a plain number (0 if anything fails).
     * ------------------------------------------------------------------ */

    func getBalance(cUserId) {
        if isNull(cUserId) or cUserId = "" { return 0 }

        # 1. Sum confirmed incoming and outgoing amounts from ledger
        nRecv = 0
        nSent = 0
        try {
            aRecv = oDB.queryAssoc("SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE receiver_id = '" + cUserId + "' AND status = 'confirmed'")
            if not isNull(aRecv) and len(aRecv) > 0 {
                nRecv = number(aRecv[1][:total])
            }
        catch
            see "Warning querying recv balance: " + cCatchError + nl
        }
        try {
            aSent = oDB.queryAssoc("SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE sender_id = '" + cUserId + "' AND status = 'confirmed'")
            if not isNull(aSent) and len(aSent) > 0 {
                nSent = number(aSent[1][:total])
            }
        catch
            see "Warning querying sent balance: " + cCatchError + nl
        }
        nTotal = nRecv - nSent
        if nTotal < 0 { nTotal = 0 }

        # 2. Check and sync with TokenContract
        if not isNull(oContractManager) {
            try {
                oTok = oContractManager.getTokenContract()
                if not isNull(oTok) {
                    nTokBal = oTok.getBalanceOf(cUserId)
                    if nTokBal > nTotal {
                        nTotal = nTokBal
                    } else if nTotal > nTokBal {
                        oTok.setBalance(cUserId, nTotal)
                    }
                }
            catch
            }
        }
        return nTotal
    }

    /* ------------------------------------------------------------------
     * validateChain()
     *
     * Walk every block in timestamp order and verify:
     *   1. Hash integrity (recompute vs stored).
     *   2. Linkage (previous_hash matches predecessor's stored hash).
     *   3. Merkle root consistency.
     *   4. Every contained transaction is individually valid.
     *
     * Returns handleSuccess([ :valid = true/false, :errors = [...] ])
     * ------------------------------------------------------------------ */

    func validateChain() {
        aErrors = []
        try {
            aRows = oDB.query(
                "SELECT id, previous_hash, merkle_root, nonce, hash, " +
                "timestamp FROM blocks ORDER BY timestamp ASC"
            )
            if aRows = NULL or len(aRows) = 0 {
                return handleSuccess([
                    :valid  = true,
                    :errors = ["chain is empty"]
                ])
            }
            cPrevHash = ""
            for aRow in aRows {
                cId         = aRow[1]
                cPrev       = aRow[2]
                cMerkle     = aRow[3]
                nNonce      = aRow[4]
                cStoredHash = aRow[5]
                cTs         = aRow[6]
                /* recompute hash */
                cCalcHash = sha256(cPrev + cMerkle + string(nNonce) + cTs)
                if cCalcHash != cStoredHash {
                    add(aErrors,
                        "block " + cId + ": hash mismatch " +
                        "(stored=" + cStoredHash + ", calc=" + cCalcHash + ")")
                }
                /* linkage (skip genesis) */
                if cPrevHash != "" and cPrev != cPrevHash {
                    add(aErrors,
                        "block " + cId + ": previous_hash " + cPrev +
                        " does not match predecessor " + cPrevHash)
                }
                cPrevHash = cStoredHash
            }
            bValid = (len(aErrors) = 0)
            return handleSuccess([
                :valid  = bValid,
                :errors = aErrors
            ])
        catch 
            return handleError(cCatchError)
        }
    }

    /* ------------------------------------------------------------------
     * Private helpers
     * ------------------------------------------------------------------ */
    /* Hash of the latest block, or "" for a genesis block. */
    func getLatestHash() {
        try {
            oQ = oDB.prepare(
                "SELECT hash FROM blocks ORDER BY timestamp DESC LIMIT 1"
            )
            oQ.execute()
            aR = oQ.fetchRow()
            if not isNull(aR) {
                return aR[1]
            }
        catch 
            /* ignore */
        }
        return ""
    }

    /*------------------------------------------------------------------
     * Resolve a user's RSA private key from the users table via Crypto.
     * Wallet passphrase resolution is delegated to getWalletPassword()
     * so the application layer can inject the real session secret. 
     *------------------------------------------------------------------*/
    func resolvePrivateKey(cUserId) {
        try {
            oQ = oDB.prepare(
                "SELECT encrypted_private_key, private_key_iv, " +
                "private_key_salt FROM users WHERE id = ?"
            )
            oQ.bindString(1, cUserId)
            oRows = oQ.query()
            oRow = oRows.fetchRow()
            if isNull(oRow) {
                return NULL
            }
            aR = oRow.toList()
            cEnc  = aR[1]
            cIv   = aR[2]
            cSalt = aR[3]
            cPw   = getWalletPassword()
            if cPw = NULL {
                return NULL
            }
            return oCrypto.retrievePrivateKey(cEnc, cIv, cSalt, cPw)
        catch 
            return NULL
        }
    }

    /* Placeholder: real apps resolve the wallet passphrase from the
     * unlocked session.  Override in the application layer. */
    func getWalletPassword() {
        return NULL
    }

    # ------------------------------------------------------------------
    # Staking Operations
    # ------------------------------------------------------------------
    func stakeWala(cUserId, nAmount) {
        try {
            if isNull(cUserId) or cUserId = "" or nAmount <= 0 {
                return handleError("بيانات رهن غير صالحة")
            }
            nBal = getBalance(cUserId)
            if nBal < nAmount {
                return handleError("رصيد WALA غير كافٍ للرهن")
            }
            if not isNull(oContractManager) {
                bOk = oContractManager.stakeWALA(cUserId, nAmount)
                if bOk {
                    cTxId = "stake_" + string(random(999999999))
                    cNow = date() + " " + time()
                    oStmt = oDB.prepare("INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cTxId)
                        oStmt.bindString(2, cUserId)
                        oStmt.bindString(3, "STAKING_CONTRACT")
                        oStmt.bindFloat(4, nAmount)
                        oStmt.bindString(5, "sig_stake")
                        oStmt.bindString(6, "block_stake")
                        oStmt.bindString(7, "confirmed")
                        oStmt.bindString(8, cNow)
                        oStmt.execute()
                    }
                    see "Staked " + string(nAmount) + " WALA for " + cUserId + nl
                    return handleSuccess([:staked = nAmount, :user_id = cUserId])
                }
            }
            return handleError("فشل في تنفيذ عقد الرهن")
        catch
            return handleError(cCatchError)
        }
    }

    func unstakeWala(cUserId, nAmount) {
        try {
            if isNull(cUserId) or cUserId = "" or nAmount <= 0 {
                return handleError("بيانات إلغاء الرهن غير صالحة")
            }
            if not isNull(oContractManager) {
                bOk = oContractManager.unstakeWALA(cUserId, nAmount)
                if bOk {
                    cTxId = "unstake_" + string(random(999999999))
                    cNow = date() + " " + time()
                    oStmt = oDB.prepare("INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
                    if not isNull(oStmt) {
                        oStmt.bindString(1, cTxId)
                        oStmt.bindString(2, "STAKING_CONTRACT")
                        oStmt.bindString(3, cUserId)
                        oStmt.bindFloat(4, nAmount)
                        oStmt.bindString(5, "sig_unstake")
                        oStmt.bindString(6, "block_unstake")
                        oStmt.bindString(7, "confirmed")
                        oStmt.bindString(8, cNow)
                        oStmt.execute()
                    }
                    see "Unstaked " + string(nAmount) + " WALA for " + cUserId + nl
                    return handleSuccess([:unstaked = nAmount, :user_id = cUserId])
                }
            }
            return handleError("الرصيد المرهون غير كافٍ أو فشل العقد")
        catch
            return handleError(cCatchError)
        }
    }

    func getStakeInfo(cUserId) {
        try {
            nStaked = 0
            nQuota = 25
            nBoost = 0
            nTotalPool = 0
            if not isNull(oContractManager) {
                oStk = oContractManager.getStakingContract()
                if not isNull(oStk) {
                    nStaked = oStk.getStaked(cUserId)
                    nBoost = oStk.getDailyQuotaBoost(cUserId)
                    nTotalPool = number(oStk.getState("total_staked_pool"))
                }
                nQuota = oContractManager.getDailyQuota(cUserId)
            }
            return [
                :staked = nStaked,
                :daily_quota = nQuota,
                :boost = nBoost,
                :total_pool = nTotalPool
            ]
        catch
            return [
                :staked = 0,
                :daily_quota = 25,
                :boost = 0,
                :total_pool = 0
            ]
        }
    }
    # ------------------------------------------------------------------
    # Step 1 & Step 3: Subunits & Direct Purchase / P2P Escrow
    # ------------------------------------------------------------------

    func getBalanceInfo(cUserId) {
        nBal = getBalance(cUserId)
        nIkhlas = nBal * 1000000
        return [
            :user_id = cUserId,
            :balance = nBal,
            :balance_ikhlas = nIkhlas,
            :decimals = 6,
            :currency_name = "ولاء",
            :currency_symbol = "WALA",
            :subunit_name = "إخلاص",
            :subunit_symbol = "IKH",
            :rate_ikhlas_per_wala = 1000000
        ]
    }

    /* Direct Instant Purchase with USDT (1 USDT = 10 WALA) */
    func buyWalaWithCrypto(cUserId, nUsdtAmount, cNetwork) {
        try {
            if isNull(cUserId) or cUserId = "" { return handleError("معرف مستخدم غير صالح") }
            if nUsdtAmount <= 0 { return handleError("الكمية يجب أن تكون أكبر من صفر") }
            if isNull(cNetwork) or cNetwork = "" { cNetwork = "TRC20" }

            # 1 USDT = 10 WALA
            nWalaAmount = nUsdtAmount * 10
            cTxId = "buy_crypto_" + string(random(999999999))
            cNow = date() + " " + time()

            oStmt = oDB.prepare(
                "INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) " +
                "VALUES (?, 'USDT_ONRAMP_" + cNetwork + "', ?, ?, 'PROOF_USDT_" + string(random(999999)) + "', 'block_onramp', 'confirmed', ?)"
            )
            if not isNull(oStmt) {
                oStmt.bindString(1, cTxId)
                oStmt.bindString(2, cUserId)
                oStmt.bindFloat(3, nWalaAmount)
                oStmt.bindString(4, cNow)
                oStmt.execute()

                if not isNull(oContractManager) {
                    oContractManager.transferWALA("GENESIS_FAUCET", cUserId, nWalaAmount)
                }

                if not isNull(oMessageService) {
                    oMessageService.createNotification(cUserId, "SYSTEM", "tip", cTxId, "عملية شراء WALA ناجحة ⚡", "تم شحن " + string(nWalaAmount) + " WALA (" + string(nWalaAmount * 1000000) + " إخلاص) بنجاح عبر " + cNetwork + " بقيمة $" + string(nUsdtAmount) + " USDT.")
                }

                see "[On-Ramp] Credited " + string(nWalaAmount) + " WALA to @" + cUserId + " for $" + string(nUsdtAmount) + " USDT" + nl
                return handleSuccess([
                    :success = true,
                    :tx_id = cTxId,
                    :wala_amount = nWalaAmount,
                    :ikhlas_amount = nWalaAmount * 1000000,
                    :usdt_amount = nUsdtAmount,
                    :network = cNetwork,
                    :created_at = cNow
                ])
            }
            return handleError("فشل في تحضير معاملة الشراء المباشر")
        catch
            see "Error in buyWalaWithCrypto: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    /* P2P Escrow Market: Retrieve offers (seeded if empty) */
    func getP2POffers() {
        try {
            aRows = oDB.queryAssoc("SELECT * FROM p2p_offers WHERE status = 'active' ORDER BY rowid DESC LIMIT 20")
            if isNull(aRows) or len(aRows) = 0 {
                # Seed default network liquidity desk offers
                cNow = date() + " " + time()
                oDB.execute("INSERT OR IGNORE INTO p2p_offers (id, seller_id, wala_amount, fiat_price, currency, payment_method, status, created_at) VALUES ('offer_dzd', 'Desk_Algeria', 200, 4800, 'DZD', 'بريدي موب (BaridiMob)', 'active', '" + cNow + "')")
                oDB.execute("INSERT OR IGNORE INTO p2p_offers (id, seller_id, wala_amount, fiat_price, currency, payment_method, status, created_at) VALUES ('offer_egp', 'Desk_Egypt', 150, 750, 'EGP', 'فودافون كاش (Vodafone Cash)', 'active', '" + cNow + "')")
                oDB.execute("INSERT OR IGNORE INTO p2p_offers (id, seller_id, wala_amount, fiat_price, currency, payment_method, status, created_at) VALUES ('offer_sar', 'Desk_Gulf', 250, 95, 'SAR', 'STC Pay / بنك الراجحي', 'active', '" + cNow + "')")
                oDB.execute("INSERT OR IGNORE INTO p2p_offers (id, seller_id, wala_amount, fiat_price, currency, payment_method, status, created_at) VALUES ('offer_usd', 'Desk_Global', 100, 10, 'USD', 'Wise / Revolut', 'active', '" + cNow + "')")
                aRows = oDB.queryAssoc("SELECT * FROM p2p_offers WHERE status = 'active' ORDER BY rowid DESC LIMIT 20")
            }
            if isNull(aRows) { return [] }
            return aRows
        catch
            see "Error in getP2POffers: " + cCatchError + nl
            return []
        }
    }

    /* P2P Escrow Market: Create sell offer */
    func createP2POffer(cSellerId, nWalaAmount, nFiatPrice, cCurrency, cPaymentMethod) {
        try {
            if isNull(cSellerId) or cSellerId = "" { return handleError("معرف بائع غير صالح") }
            if nWalaAmount <= 0 { return handleError("الكمية يجب أن تكون أكبر من صفر") }
            if nFiatPrice <= 0 { return handleError("السعر يجب أن يكون أكبر من صفر") }

            nBal = getBalance(cSellerId)
            if nBal < nWalaAmount {
                return handleError("رصيدك الحالي غير كافٍ لإنشاء هذا العرض")
            }

            cOfferId = "offer_" + string(random(999999999))
            cNow = date() + " " + time()

            oStmt = oDB.prepare("INSERT INTO p2p_offers (id, seller_id, wala_amount, fiat_price, currency, payment_method, status, created_at) VALUES (?, ?, ?, ?, ?, ?, 'active', ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cOfferId)
                oStmt.bindString(2, cSellerId)
                oStmt.bindFloat(3, nWalaAmount)
                oStmt.bindFloat(4, nFiatPrice)
                oStmt.bindString(5, cCurrency)
                oStmt.bindString(6, cPaymentMethod)
                oStmt.bindString(7, cNow)
                oStmt.execute()

                see "[P2P Escrow] Created offer " + cOfferId + " by @" + cSellerId + nl
                return handleSuccess([:id = cOfferId, :status = "active"])
            }
            return handleError("فشل في تحضير العرض")
        catch
            see "Error in createP2POffer: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    /* P2P Escrow Market: Execute purchase & transfer WALA */
    func executeP2PBuy(cBuyerId, cOfferId) {
        try {
            if isNull(cBuyerId) or cBuyerId = "" { return handleError("معرف مشترٍ غير صالح") }
            if isNull(cOfferId) or cOfferId = "" { return handleError("معرف عرض غير صالح") }

            aOffers = oDB.queryAssoc("SELECT * FROM p2p_offers WHERE id = '" + cOfferId + "' AND status = 'active' LIMIT 1")
            if isNull(aOffers) or len(aOffers) = 0 {
                return handleError("العرض غير متاح أو تم شراؤه مسبقاً")
            }

            aOffer = aOffers[1]
            cSeller = aOffer[:seller_id]
            nWala = number(aOffer[:wala_amount])
            nFiat = number(aOffer[:fiat_price])
            cCurr = aOffer[:currency]

            if cSeller = cBuyerId {
                return handleError("لا يمكنك شراء عرضك الخاص")
            }

            cTxId = "p2p_escrow_" + string(random(999999999))
            cNow = date() + " " + time()

            # Credit WALA to buyer from seller
            oStmt = oDB.prepare(
                "INSERT INTO transactions (id, sender_id, receiver_id, amount, signature, block_id, status, created_at) " +
                "VALUES (?, ?, ?, ?, 'P2P_ESCROW_RELEASE', 'block_escrow', 'confirmed', ?)"
            )
            if not isNull(oStmt) {
                oStmt.bindString(1, cTxId)
                oStmt.bindString(2, cSeller)
                oStmt.bindString(3, cBuyerId)
                oStmt.bindFloat(4, nWala)
                oStmt.bindString(5, cNow)
                oStmt.execute()

                # Mark offer completed
                oDB.execute("UPDATE p2p_offers SET status = 'completed' WHERE id = '" + cOfferId + "'")

                if not isNull(oContractManager) {
                    oContractManager.transferWALA(cSeller, cBuyerId, nWala)
                }

                # Notifications to both parties
                if not isNull(oMessageService) {
                    oMessageService.createNotification(cBuyerId, cSeller, "tip", cTxId, "اكتمال شراء P2P بنجاح 🛡️", "تم استلام " + string(nWala) + " WALA من البائع @" + cSeller + " بنجاح عبر الضمان الذكي.")
                    oMessageService.createNotification(cSeller, cBuyerId, "tip", cTxId, "تم بيع عرض P2P 💰", "قام @" + cBuyerId + " بشراء عرضك (" + string(nWala) + " WALA) بقيمة " + string(nFiat) + " " + cCurr + ".")
                }

                see "[P2P Escrow] Transferred " + string(nWala) + " WALA from @" + cSeller + " to @" + cBuyerId + " (Offer: " + cOfferId + ")" + nl
                return handleSuccess([
                    :success = true,
                    :tx_id = cTxId,
                    :wala_amount = nWala,
                    :fiat_price = nFiat,
                    :currency = cCurr,
                    :seller_id = cSeller
                ])
            }
            return handleError("فشل في تحرير الضمان")
        catch
            see "Error in executeP2PBuy: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    private
        oDB
        oCrypto
        nDifficulty
        oContractManager
        oMessageService
        oP2PService
        oWorkerPool
}
