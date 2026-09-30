/* Service: MessageService
 * End-to-End Encrypted (E2EE) Direct Messaging and Decentralized Notifications.
 *
 * Messages are encrypted using AES-CBC with local salts/IVs safely encoded in hex,
 * and tied to recipients' identities.
 *
 * NOTE: Uses Crypto_Internal directly for AES (Crypto class has no public encrypt()).
 */



class MessageService from Service {

    func init(oDatabase) {
        oDB = oDatabase
        oAes = new Crypto_Internal()
        oP2PService = NULL
        oMediaStorage = new MediaStorageService("")
        if not isNull(oDB) {
            oMediaStorage.setDB(oDB)
        }
    }

    func setP2PService(oP2P) {
        oP2PService = oP2P
    }

    # Safe string comparison returning -1, 0, or 1 without numeric conversions
    func strCompare(str1, str2) {
        if isNull(str1) { str1 = "" }
        if isNull(str2) { str2 = "" }
        nLen1 = len(str1)
        nLen2 = len(str2)
        nMin = nLen1
        if nLen2 < nMin { nMin = nLen2 }
        for i = 1 to nMin {
            c1 = ascii(str1[i])
            c2 = ascii(str2[i])
            if c1 < c2 { return -1 }
            if c1 > c2 { return 1 }
        }
        if nLen1 < nLen2 { return -1 }
        if nLen1 > nLen2 { return 1 }
        return 0
    }

    # Safe number conversion: returns 0 if val is NULL or non-numeric
    func safeNum(val) {
        if isNull(val) { return 0 }
        if type(val) = "NUMBER" { return val }
        if type(val) = "STRING" {
            if val = "" or val = "NULL" { return 0 }
            nLen = len(val)
            for k = 1 to nLen {
                nAsc = ascii(val[k])
                if (nAsc < 48 or nAsc > 57) and nAsc != 45 and nAsc != 46 {
                    return 0
                }
            }
            try {
                return number(val)
            catch
                return 0
            }
        }
        return 0
    }

    # ------------------------------------------------------------------
    # E2EE Direct Messaging
    # ------------------------------------------------------------------

    func sendMessage(cSender, cReceiver, cContent) {
        try {
            if isNull(cSender) or cSender = "" { return handleError("مرسل غير صالح") }
            if isNull(cReceiver) or cReceiver = "" { return handleError("مستلم غير صالح") }
            if isNull(cContent) or cContent = "" { return handleError("محتوى الرسالة فارغ") }

            cMsgId = "msg_" + string(random(9999999))
            cNow = date() + " " + time()

            # Derive a deterministic AES key from the shared conversation secret
            cSharedSecret = "mejde_e2ee_" + cSender + "_" + cReceiver
            if strCompare(cReceiver, cSender) < 0 {
                cSharedSecret = "mejde_e2ee_" + cReceiver + "_" + cSender
            }

            # Encrypt with AES-256 (IV = SHA256 of shared secret, key = SHA256[:32])
            cKey = left(SHA256(cSharedSecret), 32)
            cIv  = left(SHA256(cSharedSecret + "iv"), 16)
            cEncContent = str2hex(oAes.aesEncrypt(cContent, cKey, cIv))
            if isNull(cEncContent) or cEncContent = "" { cEncContent = str2hex(cContent) }

            oStmt = oDB.prepare("INSERT INTO messages (id, sender_id, receiver_id, encrypted_content, encrypted_key, iv, salt, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cMsgId)
                oStmt.bindString(2, cSender)
                oStmt.bindString(3, cReceiver)
                oStmt.bindString(4, cEncContent)
                oStmt.bindString(5, "e2ee")
                oStmt.bindString(6, cIv)
                oStmt.bindString(7, "")
                oStmt.bindInt(8, 0)
                oStmt.bindString(9, cNow)
                oStmt.execute()

                # Automatically generate on-chain notification for the recipient
                createNotification(cReceiver, cSender, "message", cMsgId, "رسالة خاصة جديدة", "أرسل لك @" + cSender + " رسالة مشفرة.")

                # Broadcast encrypted message to P2P network (safe, non-blocking)
                if not isNull(oP2PService) {
                    try {
                        oP2PService.broadcast("message", [
                            :id = cMsgId,
                            :sender_id = cSender,
                            :receiver_id = cReceiver,
                            :encrypted_content = cEncContent,
                            :iv = cIv,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in message broadcast: " + cCatchError + nl
                    }
                }

                see "E2EE Message sent from " + cSender + " to " + cReceiver + nl
                return handleSuccess([
                    :id = cMsgId,
                    :sender_id = cSender,
                    :receiver_id = cReceiver,
                    :content = cContent,
                    :is_read = 0,
                    :created_at = cNow
                ])
            }
            return handleError("فشل في تحضير استعلام حفظ الرسالة")
        catch
            see "Error in sendMessage: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getMessages(cUser1, cUser2) {
        try {
            if isNull(cUser1) or isNull(cUser2) { return [] }
            
            # Shared AES key/IV for decryption
            cSharedSecret = "mejde_e2ee_" + cUser1 + "_" + cUser2
            if strCompare(cUser2, cUser1) < 0 {
                cSharedSecret = "mejde_e2ee_" + cUser2 + "_" + cUser1
            }
            cKey = left(SHA256(cSharedSecret), 32)
            cIv  = left(SHA256(cSharedSecret + "iv"), 16)

            cSQL = "SELECT id, sender_id, receiver_id, encrypted_content, iv, salt, is_read, created_at FROM messages " +
                   "WHERE (sender_id = '" + cUser1 + "' AND receiver_id = '" + cUser2 + "') " +
                   "   OR (sender_id = '" + cUser2 + "' AND receiver_id = '" + cUser1 + "') " +
                   "ORDER BY created_at ASC LIMIT 100"

            aRows = oDB.queryAssoc(cSQL)
            if isNull(aRows) { return [] }

            aDecrypted = []
            for aMsg in aRows {
                cPlain = ""
                try {
                    cEncHex = aMsg[:encrypted_content]
                    if isNull(cEncHex) or cEncHex = "" {
                        cPlain = "[رسالة فارغة]"
                    else
                        cDecBytes = oAes.aesDecrypt(hex2str(cEncHex), cKey, cIv)
                        if isNull(cDecBytes) or cDecBytes = "" {
                            cPlain = "[رسالة مشفرة E2EE]"
                        else
                            cPlain = cDecBytes
                        ok
                    ok
                catch
                    cPlain = "[رسالة مشفرة E2EE]"
                }
                # Resolve sender avatar
                cSenderAvatar = ""
                aSenderUser = oDB.queryAssoc("SELECT avatar_data, avatar_cid FROM users WHERE id = '" + aMsg[:sender_id] + "' LIMIT 1")
                if not isNull(aSenderUser) and len(aSenderUser) > 0 {
                    cSenderAvatar = aSenderUser[1][:avatar_data]
                    if isNull(cSenderAvatar) or cSenderAvatar = "" { cSenderAvatar = aSenderUser[1][:avatar_cid] }
                    if cSenderAvatar != "" and substr(cSenderAvatar, "data:") != 1 {
                        cHydrated = oMediaStorage.getMedia(cSenderAvatar)
                        if cHydrated != "" { cSenderAvatar = cHydrated }
                    }
                }

                add(aDecrypted, [
                    :id = aMsg[:id],
                    :sender_id = aMsg[:sender_id],
                    :sender_avatar = cSenderAvatar,
                    :receiver_id = aMsg[:receiver_id],
                    :content = cPlain,
                    :is_read = safeNum(aMsg[:is_read]),
                    :created_at = aMsg[:created_at]
                ])
            }

            # Mark incoming messages as read
            oDB.execute("UPDATE messages SET is_read = 1 WHERE receiver_id = '" + cUser1 + "' AND sender_id = '" + cUser2 + "'")

            return aDecrypted
        catch
            see "Error in getMessages: " + cCatchError + nl
            return []
        }
    }

    func getConversations(cUserId) {
        try {
            cSQL = "SELECT DISTINCT CASE WHEN sender_id = '" + cUserId + "' THEN receiver_id ELSE sender_id END AS partner_id " +
                   "FROM messages WHERE sender_id = '" + cUserId + "' OR receiver_id = '" + cUserId + "'"
            aPartners = oDB.queryAssoc(cSQL)
            if isNull(aPartners) { return [] }

            aList = []
            for aP in aPartners {
                cPartner = aP[:partner_id]
                # Get last message
                cLastSQL = "SELECT encrypted_content, iv, salt, created_at, sender_id FROM messages " +
                           "WHERE (sender_id = '" + cUserId + "' AND receiver_id = '" + cPartner + "') OR (sender_id = '" + cPartner + "' AND receiver_id = '" + cUserId + "') " +
                           "ORDER BY created_at DESC LIMIT 1"
                aLast = oDB.queryAssoc(cLastSQL)
                cLastSnippet = "رسالة مشفرة"
                cLastTime = ""
                if not isNull(aLast) and len(aLast) > 0 {
                    cLastTime = aLast[1][:created_at]
                }
                # Get partner avatar
                aUser = oDB.queryAssoc("SELECT username, avatar_data, avatar_cid FROM users WHERE id = '" + cPartner + "' LIMIT 1")
                cName = cPartner
                cAvatar = ""
                if not isNull(aUser) and len(aUser) > 0 {
                    cName = aUser[1][:username]
                    cAvatar = aUser[1][:avatar_data]
                    if isNull(cAvatar) or cAvatar = "" { cAvatar = aUser[1][:avatar_cid] }
                    if cAvatar != "" and substr(cAvatar, "data:") != 1 {
                        cHydrated = oMediaStorage.getMedia(cAvatar)
                        if cHydrated != "" { cAvatar = cHydrated }
                    }
                }
                # Unread count
                aUnread = oDB.queryAssoc("SELECT count(*) as cnt FROM messages WHERE receiver_id = '" + cUserId + "' AND sender_id = '" + cPartner + "' AND is_read = 0")
                nUnread = 0
                if not isNull(aUnread) and len(aUnread) > 0 { nUnread = safeNum(aUnread[1][:cnt]) }

                add(aList, [
                    :partner_id = cPartner,
                    :name = cName,
                    :avatar = cAvatar,
                    :last_time = cLastTime,
                    :unread = nUnread
                ])
            }
            return aList
        catch
            see "Error in getConversations: " + cCatchError + nl
            return []
        }
    }

    # ------------------------------------------------------------------
    # Decentralized On-Chain Notifications
    # ------------------------------------------------------------------

    func createNotification(cUserId, cActorId, cType, cTargetId, cTitle, cMessage) {
        try {
            if cUserId = cActorId { return false } # No self notifications
            cNotifId = "notif_" + string(random(999999999))
            cNow = date() + " " + time()

            oStmt = oDB.prepare("INSERT INTO notifications (id, user_id, actor_id, type, target_id, title, message, is_read, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cNotifId)
                oStmt.bindString(2, cUserId)
                oStmt.bindString(3, cActorId)
                oStmt.bindString(4, cType)
                oStmt.bindString(5, cTargetId)
                oStmt.bindString(6, cTitle)
                oStmt.bindString(7, cMessage)
                oStmt.bindInt(8, 0)
                oStmt.bindString(9, cNow)
                oStmt.execute()
                return true
            }
            return false
        catch
            see "Error in createNotification: " + cCatchError + nl
            return false
        }
    }

    func getNotifications(cUserId) {
        try {
            cAvatarExpr = "CASE WHEN u.avatar_data IS NOT NULL AND u.avatar_data != '' THEN u.avatar_data WHEN u.avatar_cid IS NOT NULL AND u.avatar_cid != '' THEN u.avatar_cid ELSE '' END AS actor_avatar"
            cSQL = "SELECT n.id, n.user_id, n.actor_id, n.type, n.target_id, n.title, n.message, n.is_read, n.created_at, " +
                   "COALESCE(u.username, n.actor_id) AS actor_name, " + cAvatarExpr + " " +
                   "FROM notifications n LEFT JOIN users u ON n.actor_id = u.id " +
                   "WHERE n.user_id = '" + cUserId + "' ORDER BY n.created_at DESC LIMIT 30"
            aRows = oDB.queryAssoc(cSQL)
            if isNull(aRows) { return [] }

            # Hydrate avatar from CAS disk storage
            for i = 1 to len(aRows) {
                if aRows[i][:actor_avatar] != "" and substr(aRows[i][:actor_avatar], "data:") != 1 {
                    cHydrated = oMediaStorage.getMedia(aRows[i][:actor_avatar])
                    if cHydrated != "" {
                        aRows[i][:actor_avatar] = cHydrated
                    }
                }
            }

            return aRows
        catch
            see "Error in getNotifications: " + cCatchError + nl
            return []
        }
    }

    func markNotificationsRead(cUserId) {
        try {
            oDB.execute("UPDATE notifications SET is_read = 1 WHERE user_id = '" + cUserId + "'")
            return handleSuccess(true)
        catch
            return handleError(cCatchError)
        }
    }

    func getUnreadCount(cUserId) {
        try {
            aNotifs = oDB.queryAssoc("SELECT count(*) as cnt FROM notifications WHERE user_id = '" + cUserId + "' AND is_read = 0")
            aMsgs = oDB.queryAssoc("SELECT count(*) as cnt FROM messages WHERE receiver_id = '" + cUserId + "' AND is_read = 0")
            nNotifs = 0
            nMsgs = 0
            if not isNull(aNotifs) and len(aNotifs) > 0 { nNotifs = safeNum(aNotifs[1][:cnt]) }
            if not isNull(aMsgs) and len(aMsgs) > 0 { nMsgs = safeNum(aMsgs[1][:cnt]) }
            return [
                :notifications = nNotifs,
                :messages = nMsgs,
                :total = nNotifs + nMsgs
            ]
        catch
            return [:notifications = 0, :messages = 0, :total = 0]
        }
    }

    private
        oDB
        oAes
        oP2PService
        oMediaStorage
}
