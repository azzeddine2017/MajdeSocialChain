


/* ------------------------------------------------------------------
 * Service for managing posts
 *------------------------------------------------------------------*/
class PostService from Service {
    
    func init(oDatabase) { 
        oDB = oDatabase 
        oContractManager = NULL
        oMessageService = NULL
        oP2PService = NULL
        oWorkerPool = NULL
        oMediaStorage = new MediaStorageService("")
        if not isNull(oDB) {
            oMediaStorage.setDB(oDB)
        }
    }

    func setMediaStorageService(oMS) {
        oMediaStorage = oMS
    }

    func getMediaStorageService() {
        return oMediaStorage
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

    func createPost(cUserId, cContent, cMediaCid, cMediaData) {
        try {
            if isNull(cUserId) or cUserId = "" { cUserId = "anonymous" }
            if isNull(cContent) { cContent = "" }
            if isNull(cMediaCid) { cMediaCid = "" }
            if isNull(cMediaData) { cMediaData = "" }
            
            # Anti-bot: dynamic daily post quota based on StakingContract
            nDailyLimit = 25
            if not isNull(oContractManager) {
                nDailyLimit = oContractManager.getDailyQuota(cUserId)
            }
            cToday = date()
            aCountRows = oDB.queryAssoc("SELECT count(*) as cnt FROM posts WHERE user_id = '" + cUserId + "' AND created_at LIKE '" + cToday + "%'")
            if not isNull(aCountRows) and len(aCountRows) > 0 {
                if number(aCountRows[1][:cnt]) >= nDailyLimit {
                    return handleError("تجاوزت الحد اليومي للنشر (" + string(nDailyLimit) + " منشور/يوم). يمكنك رهن المزيد من عملات WALA لزيادة حصتك.")
                }
            }

            cPostId = "post_" + string(random(999999999))
            cNow = date() + " " + time()
            
            # Store media blob to disk (CAS) to prevent LibSQL database bloat
            if cMediaData != "" and (isNull(cMediaCid) or cMediaCid = "") {
                cMediaCid = oMediaStorage.storeMedia(cMediaData)
            }

            # Ensure author exists in users table (satisfies foreign key constraint)
            oUserStmt = oDB.prepare("INSERT OR IGNORE INTO users (id, username, public_key, encrypted_private_key, created_at) VALUES (?, ?, 'auto_key', 'none', ?)")
            if not isNull(oUserStmt) {
                oUserStmt.bindString(1, cUserId)
                oUserStmt.bindString(2, cUserId)
                oUserStmt.bindString(3, cNow)
                oUserStmt.execute()
            }

            # 1. Insert into posts table (leave media_data empty to keep db file lean; CAS file holds media)
            oStmt = oDB.prepare("INSERT INTO posts (id, user_id, content, media_cid, media_data, created_at) VALUES (?, ?, ?, ?, '', ?)")
            if isNull(oStmt) {
                see "Failed to prepare insert post statement!" + nl
                return handleError("Failed to prepare statement")
            }
            oStmt.bindString(1, cPostId)
            oStmt.bindString(2, cUserId)
            oStmt.bindString(3, cContent)
            oStmt.bindString(4, cMediaCid)
            oStmt.bindString(5, cNow)
            oStmt.execute()
            
            # 2. Update feed_cache
            oStmt2 = oDB.prepare("INSERT INTO feed_cache (post_id, author_pubkey, content, media_cid, media_data, likes_count, merit_score, created_at) VALUES (?, ?, ?, ?, '', ?, ?, ?)")
            if not isNull(oStmt2) {
                oStmt2.bindString(1, cPostId)
                oStmt2.bindString(2, cUserId)
                oStmt2.bindString(3, cContent)
                oStmt2.bindString(4, cMediaCid)
                oStmt2.bindInt(5, 0)
                oStmt2.bindFloat(6, 10.0) # Initial merit score for new fresh posts
                oStmt2.bindString(7, cNow)
                oStmt2.execute()
            }
            
            # 3. Broadcast to P2P network (Asynchronous background worker or safe fallback)
            if not isNull(oWorkerPool) {
                try {
                    oWorkerPool.queueBroadcast("post", [
                        :id = cPostId,
                        :user_id = cUserId,
                        :content = cContent,
                        :media_cid = cMediaCid,
                        :media_data = "",
                        :created_at = cNow
                    ])
                catch
                    see "Warning in queueBroadcast: " + cCatchError + nl
                }
            elseif not isNull(oP2PService)
                try {
                    oP2PService.broadcast("post", [
                        :id = cPostId,
                        :user_id = cUserId,
                        :content = cContent,
                        :media_cid = cMediaCid,
                        :media_data = "",
                        :created_at = cNow
                    ])
                catch
                    see "Warning in post broadcast: " + cCatchError + nl
                }
            ok
            
            see "Post created successfully: " + cPostId + " (media_cid=" + cMediaCid + ")" + nl
            return handleSuccess([
                :id = cPostId,
                :user_id = cUserId,
                :content = cContent,
                :media_cid = cMediaCid,
                :created_at = cNow
            ])
        catch 
            see "Error in createPost: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getFeed(cUserId, cFilter) {
        try {
            if isNull(cFilter) or cFilter = "" { cFilter = "latest" }
            cAvatarExpr = "CASE WHEN u.avatar_data IS NOT NULL AND u.avatar_data != '' THEN u.avatar_data WHEN u.avatar_cid IS NOT NULL AND u.avatar_cid != '' THEN u.avatar_cid ELSE '' END AS author_avatar"
            if cFilter = "merit" {
                cSQL = "SELECT fc.post_id AS id, fc.author_pubkey AS author, fc.content, fc.media_cid, fc.media_data, fc.likes_count, fc.merit_score, fc.created_at AS time, " + cAvatarExpr + " FROM feed_cache fc LEFT JOIN users u ON fc.author_pubkey = u.id ORDER BY fc.merit_score DESC, fc.rowid DESC LIMIT 50"
            elseif cFilter = "following"
                cSQL = "SELECT fc.post_id AS id, fc.author_pubkey AS author, fc.content, fc.media_cid, fc.media_data, fc.likes_count, fc.merit_score, fc.created_at AS time, " + cAvatarExpr + " FROM feed_cache fc INNER JOIN follows f ON fc.author_pubkey = f.followed_id LEFT JOIN users u ON fc.author_pubkey = u.id WHERE f.follower_id = '" + cUserId + "' ORDER BY fc.rowid DESC LIMIT 50"
            else
                cSQL = "SELECT fc.post_id AS id, fc.author_pubkey AS author, fc.content, fc.media_cid, fc.media_data, fc.likes_count, fc.merit_score, fc.created_at AS time, " + cAvatarExpr + " FROM feed_cache fc LEFT JOIN users u ON fc.author_pubkey = u.id ORDER BY fc.rowid DESC LIMIT 50"
            }
            
            aRows = oDB.queryAssoc(cSQL)
            if isNull(aRows) { return [] }

            # Hydrate media and avatar from CAS disk storage
            for i = 1 to len(aRows) {
                if aRows[i][:media_cid] != "" and (isNull(aRows[i][:media_data]) or aRows[i][:media_data] = "") {
                    aRows[i][:media_data] = oMediaStorage.getMedia(aRows[i][:media_cid])
                }
                if aRows[i][:author_avatar] != "" and substr(aRows[i][:author_avatar], "data:") != 1 {
                    cAv = oMediaStorage.getMedia(aRows[i][:author_avatar])
                    if cAv != "" {
                        aRows[i][:author_avatar] = cAv
                    }
                }
            }

            return aRows
        catch
            see "Error in getFeed: " + cCatchError + nl
            return []
        }
    }

    func likePost(cUserId, cPostId) {
        try {
            oStmt = oDB.prepare("INSERT OR IGNORE INTO likes (user_id, post_id, created_at) VALUES (?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cUserId)
                oStmt.bindString(2, cPostId)
                oStmt.bindString(3, date() + " " + time())
                oStmt.execute()
            }
            oStmt2 = oDB.prepare("UPDATE feed_cache SET likes_count = likes_count + 1, merit_score = merit_score + 1.5 WHERE post_id = ?")
            if not isNull(oStmt2) {
                oStmt2.bindString(1, cPostId)
                oStmt2.execute()
            }
        catch
            see "Error in likePost: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func ratePost(cUserId, cPostId, nStars) {
        try {
            if isNull(cUserId) or cUserId = "" { cUserId = "anonymous" }
            if isNull(nStars) or nStars < 1 { nStars = 1 }
            if nStars > 5 { nStars = 5 }
            
            cNow = date() + " " + time()
            oStmt = oDB.prepare("INSERT OR REPLACE INTO ratings (user_id, post_id, stars, created_at) VALUES (?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cUserId)
                oStmt.bindString(2, cPostId)
                oStmt.bindInt(3, nStars)
                oStmt.bindString(4, cNow)
                oStmt.execute()
                
                # Recalculate merit score
                aStats = oDB.queryAssoc("SELECT sum(stars) as s_sum, count(*) as s_cnt FROM ratings WHERE post_id = '" + cPostId + "'")
                nScore = 5.0
                if not isNull(aStats) and len(aStats) > 0 {
                    nScore = number(aStats[1][:s_sum]) * 2.0
                }
                oDB.execute("UPDATE feed_cache SET merit_score = " + string(nScore) + " WHERE post_id = '" + cPostId + "'")

                # Reward creator via MeritRewardContract
                if not isNull(oContractManager) and nStars >= 3 {
                    aAuthorRows = oDB.queryAssoc("SELECT user_id FROM posts WHERE id = '" + cPostId + "' LIMIT 1")
                    if not isNull(aAuthorRows) and len(aAuthorRows) > 0 {
                        cAuthor = aAuthorRows[1][:user_id]
                        if cAuthor != "" and cAuthor != cUserId {
                            oContractManager.rewardCreator(cAuthor, nStars)
                            see "Rewarded author " + cAuthor + " for high rating (" + string(nStars) + " stars)" + nl
                        }
                    }
                }

                # Emit on-chain notification to post author
                if not isNull(oMessageService) {
                    aAuthorRows = oDB.queryAssoc("SELECT user_id FROM posts WHERE id = '" + cPostId + "' LIMIT 1")
                    if not isNull(aAuthorRows) and len(aAuthorRows) > 0 {
                        cAuthor = aAuthorRows[1][:user_id]
                        if cAuthor != "" and cAuthor != cUserId {
                            oMessageService.createNotification(cAuthor, cUserId, "rating", cPostId, "تقييم جديد", "قام @" + cUserId + " بتقييم منشورك بـ " + string(nStars) + " نجوم ⭐")
                        }
                    }
                }
                
                # Broadcast rating to P2P network (Worker pool or safe fallback)
                if not isNull(oWorkerPool) {
                    try {
                        oWorkerPool.queueBroadcast("rating", [
                            :user_id = cUserId,
                            :post_id = cPostId,
                            :stars = nStars,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in rating queueBroadcast: " + cCatchError + nl
                    }
                elseif not isNull(oP2PService)
                    try {
                        oP2PService.broadcast("rating", [
                            :user_id = cUserId,
                            :post_id = cPostId,
                            :stars = nStars,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in rating broadcast: " + cCatchError + nl
                    }
                ok

                see "Post rated: " + cPostId + " with " + string(nStars) + " stars. New merit: " + string(nScore) + nl
                return handleSuccess([:rated = true, :stars = nStars, :score = nScore])
            }
            return handleError("Failed to prepare rate statement")
        catch
            see "Error in ratePost: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func followUser(cFollowerId, cFollowedId) {
        try {
            if cFollowerId = cFollowedId or isNull(cFollowerId) or isNull(cFollowedId) { return handleError("Invalid follow") }
            oStmt = oDB.prepare("INSERT OR IGNORE INTO follows (follower_id, followed_id, created_at) VALUES (?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cFollowerId)
                oStmt.bindString(2, cFollowedId)
                oStmt.bindString(3, date() + " " + time())
                oStmt.execute()

                # Emit notification
                if not isNull(oMessageService) {
                    oMessageService.createNotification(cFollowedId, cFollowerId, "follow", cFollowerId, "متابع جديد", "بدأ @" + cFollowerId + " بمتابعتك 👥")
                }

                see "User " + cFollowerId + " followed " + cFollowedId + nl
                return handleSuccess([:followed = true])
            }
            return handleError("Failed to prepare follow statement")
        catch
            see "Error in followUser: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func unfollowUser(cFollowerId, cFollowedId) {
        try {
            oDB.execute("DELETE FROM follows WHERE follower_id = '" + cFollowerId + "' AND followed_id = '" + cFollowedId + "'")
            see "User " + cFollowerId + " unfollowed " + cFollowedId + nl
            return handleSuccess([:followed = false])
        catch
            see "Error in unfollowUser: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getFollowStats(cUserId) {
        try {
            aFollowers = oDB.queryAssoc("SELECT count(*) as cnt FROM follows WHERE followed_id = '" + cUserId + "'")
            aFollowing = oDB.queryAssoc("SELECT count(*) as cnt FROM follows WHERE follower_id = '" + cUserId + "'")
            nFollowers = 0
            nFollowing = 0
            if not isNull(aFollowers) and len(aFollowers) > 0 { nFollowers = number(aFollowers[1][:cnt]) }
            if not isNull(aFollowing) and len(aFollowing) > 0 { nFollowing = number(aFollowing[1][:cnt]) }
            return [
                :followers = nFollowers,
                :following = nFollowing
            ]
        catch
            return [:followers = 0, :following = 0]
        }
    }

    func addComment(cUserId, cPostId, cContent) {
        try {
            if isNull(cUserId) or cUserId = "" { cUserId = "anonymous" }
            if isNull(cContent) or cContent = "" { return handleError("محتوى التعليق فارغ") }
            
            cCommentId = "comm_" + string(random(999999999))
            cNow = date() + " " + time()
            
            oStmt = oDB.prepare("INSERT INTO comments (id, post_id, user_id, content, created_at) VALUES (?, ?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cCommentId)
                oStmt.bindString(2, cPostId)
                oStmt.bindString(3, cUserId)
                oStmt.bindString(4, cContent)
                oStmt.bindString(5, cNow)
                oStmt.execute()

                # Emit notification to post author
                if not isNull(oMessageService) {
                    aAuthorRows = oDB.queryAssoc("SELECT user_id FROM posts WHERE id = '" + cPostId + "' LIMIT 1")
                    if not isNull(aAuthorRows) and len(aAuthorRows) > 0 {
                        cAuthor = aAuthorRows[1][:user_id]
                        if cAuthor != "" and cAuthor != cUserId {
                            cSnip = cContent
                            if len(cSnip) > 30 { cSnip = left(cSnip, 30) + "..." }
                            oMessageService.createNotification(cAuthor, cUserId, "comment", cPostId, "تعليق جديد", "علّق @" + cUserId + " على منشورك: " + cSnip)
                        }
                    }
                }

                # Broadcast comment to P2P network (Worker pool or safe fallback)
                if not isNull(oWorkerPool) {
                    try {
                        oWorkerPool.queueBroadcast("comment", [
                            :id = cCommentId,
                            :post_id = cPostId,
                            :user_id = cUserId,
                            :content = cContent,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in comment queueBroadcast: " + cCatchError + nl
                    }
                elseif not isNull(oP2PService)
                    try {
                        oP2PService.broadcast("comment", [
                            :id = cCommentId,
                            :post_id = cPostId,
                            :user_id = cUserId,
                            :content = cContent,
                            :created_at = cNow
                        ])
                    catch
                        see "Warning in comment broadcast: " + cCatchError + nl
                    }
                }

                see "Comment added: " + cCommentId + " on " + cPostId + nl
                return handleSuccess([
                    :id = cCommentId,
                    :post_id = cPostId,
                    :user_id = cUserId,
                    :content = cContent,
                    :created_at = cNow
                ])
            }
            return handleError("Failed to prepare comment statement")
        catch
            see "Error in addComment: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getComments(cPostId) {
        try {
            aRows = oDB.queryAssoc("SELECT id, user_id, content, created_at FROM comments WHERE post_id = '" + cPostId + "' ORDER BY created_at ASC")
            if isNull(aRows) { return [] }
            return aRows
        catch
            see "Error in getComments: " + cCatchError + nl
            return []
        }
    }

    func getProfile(cUserId) {
        try {
            aRows = oDB.queryAssoc("SELECT id, username, bio, avatar_cid, avatar_data, public_key, created_at FROM users WHERE id = '" + cUserId + "' LIMIT 1")
            if isNull(aRows) or len(aRows) = 0 {
                return [
                    :id = cUserId,
                    :username = cUserId,
                    :bio = "مرحباً بكم في حسابي على SocialChain!",
                    :avatar_cid = "",
                    :avatar_data = ""
                ]
            }
            aProfile = aRows[1]
            if aProfile[:avatar_cid] != "" and (isNull(aProfile[:avatar_data]) or aProfile[:avatar_data] = "") {
                aProfile[:avatar_data] = oMediaStorage.getMedia(aProfile[:avatar_cid])
            }
            return aProfile
        catch
            see "Error in getProfile: " + cCatchError + nl
            return []
        }
    }

    func updateProfile(cUserId, cUsername, cBio, cAvatarData) {
        try {
            if isNull(cAvatarData) { cAvatarData = "" }
            cAvatarCid = ""
            if cAvatarData != "" {
                cAvatarCid = oMediaStorage.storeMedia(cAvatarData)
            }
            oStmt = oDB.prepare("UPDATE users SET username = ?, bio = ?, avatar_cid = ?, avatar_data = ? WHERE id = ?")
            if not isNull(oStmt) {
                oStmt.bindString(1, cUsername)
                oStmt.bindString(2, cBio)
                oStmt.bindString(3, cAvatarCid)
                oStmt.bindString(4, cAvatarData)
                oStmt.bindString(5, cUserId)
                oStmt.execute()
                see "Profile updated for: " + cUserId + " (avatar_cid=" + cAvatarCid + ")" + nl

                # Broadcast updated profile and avatar to P2P network
                if not isNull(oWorkerPool) {
                    try {
                        oWorkerPool.queueBroadcast("profile", [
                            :id = cUserId,
                            :username = cUsername,
                            :bio = cBio,
                            :avatar_cid = cAvatarCid,
                            :avatar_data = cAvatarData
                        ])
                    catch
                    }
                elseif not isNull(oP2PService)
                    try {
                        oP2PService.broadcast("profile", [
                            :id = cUserId,
                            :username = cUsername,
                            :bio = cBio,
                            :avatar_cid = cAvatarCid,
                            :avatar_data = cAvatarData
                        ])
                    catch
                    }
                ok

                return handleSuccess(true)
            }
            return handleError("Failed to prepare update profile")
        catch
            see "Error in updateProfile: " + cCatchError + nl
            return handleError(cCatchError)
        }
    }

    func getUserPosts(cUserId) {
        try {
            cAvatarExpr = "CASE WHEN u.avatar_data IS NOT NULL AND u.avatar_data != '' THEN u.avatar_data WHEN u.avatar_cid IS NOT NULL AND u.avatar_cid != '' THEN u.avatar_cid ELSE '' END AS author_avatar"
            cSQL = "SELECT fc.post_id AS id, fc.author_pubkey AS author, fc.content, fc.media_cid, fc.media_data, fc.likes_count, fc.merit_score, fc.created_at AS time, " + cAvatarExpr + " FROM feed_cache fc LEFT JOIN users u ON fc.author_pubkey = u.id WHERE fc.author_pubkey = '" + cUserId + "' OR fc.author_pubkey = 'me' ORDER BY fc.rowid DESC LIMIT 50"
            aRows = oDB.queryAssoc(cSQL)
            if isNull(aRows) { return [] }

            # Hydrate media and avatar from CAS disk storage
            for i = 1 to len(aRows) {
                if aRows[i][:media_cid] != "" and (isNull(aRows[i][:media_data]) or aRows[i][:media_data] = "") {
                    aRows[i][:media_data] = oMediaStorage.getMedia(aRows[i][:media_cid])
                }
                if aRows[i][:author_avatar] != "" and substr(aRows[i][:author_avatar], "data:") != 1 {
                    cAv = oMediaStorage.getMedia(aRows[i][:author_avatar])
                    if cAv != "" {
                        aRows[i][:author_avatar] = cAv
                    }
                }
            }

            return aRows
        catch
            see "Error in getUserPosts: " + cCatchError + nl
            return []
        }
    }

    private 
        oDB
        oContractManager
        oMessageService
        oP2PService
        oWorkerPool
        oMediaStorage
}
