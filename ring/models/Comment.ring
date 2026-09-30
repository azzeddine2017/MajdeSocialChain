/* Class: Comment
   Represents a comment on a post.
   Each comment has content, author, timestamp, and can have likes and replies.

   Key features:
   - Linked to a post and user
   - Supports likes and replies
   - Status tracking (active, deleted, flagged)
   - Safe with prepared statements
   - Converts easily to list for database storage

   Usage:
   // Create a comment
   oComment = new Comment("post-123", "user-456", "Great post!")

   // Add a like
   oComment.addLike("user-789")

   // Convert to list for database
   data = oComment.toList()

   // Create from list
   oComment.fromList(data)
 */


class Comment from Model {
    
    # دالة التهيئة - تقوم بإنشاء تعليق جديد
    func init(cPost, cUser, cCommentContent) {
        super.init()
        cPostId = cPost
        cUserId = cUser
        cContent = cCommentContent
        cTimestamp = date() + " " + time()
        aLikes = []
        aReplies = []
        cStatus = "active"
    }
    
    # دوال الحصول على قيم المتغيرات
    func getPostId() { return cPostId }       # إرجاع معرف المنشور
    func getUserId() { return cUserId }       # إرجاع معرف المستخدم
    func getContent() { return cContent }     # إرجاع محتوى التعليق
    func getTimestamp() { return cTimestamp } # إرجاع الطابع الزمني
    func getLikes() { return aLikes }        # إرجاع قائمة الإعجابات
    func getReplies() { return aReplies }    # إرجاع قائمة الردود
    func getStatus() { return cStatus }      # إرجاع حالة التعليق
    
    # دوال تعديل قيم المتغيرات
    func setContent(cNewContent) { cContent = cNewContent }  # تعديل محتوى التعليق
    func setStatus(cNewStatus) { cStatus = cNewStatus }      # تعديل حالة التعليق
    
    # دوال إدارة التفاعلات
    func addLike(cLikeUserId) {
        if not find(aLikes, cLikeUserId) {
            add(aLikes, cLikeUserId)
        }
    }
    
    func removeLike(cLikeUserId) {
        nIndex = find(aLikes, cLikeUserId)
        if nIndex > 0 {
            del(aLikes, nIndex)
        }
    }
    
    func addReply(oReply) {
        add(aReplies, oReply)
    }
    
    func removeReply(cReplyId) {
        for i = 1 to len(aReplies) {
            if aReplies[i].getId() = cReplyId {
                del(aReplies, i)
                exit
            }
        }
    }
    
    # تحويل التعليق إلى قائمة من البيانات
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:post_id] = cPostId
        aData[:user_id] = cUserId
        aData[:content] = cContent
        aData[:timestamp] = cTimestamp
        aData[:likes] = aLikes
        
        # تحويل الردود إلى قوائم
        aRepliesList = []
        for oReply in aReplies {
            add(aRepliesList, oReply.toList())
        }
        aData[:replies] = aRepliesList
        
        aData[:status] = cStatus
        return aData
    }
    
    # إنشاء تعليق من قائمة بيانات
    func fromList(aData) {
        cId = aData[:id]
        cPostId = aData[:post_id]
        cUserId = aData[:user_id]
        cContent = aData[:content]
        cTimestamp = aData[:timestamp]
        aLikes = aData[:likes]
        
        # تحميل الردود
        aReplies = []
        if aData[:replies] != NULL {
            for aReplyData in aData[:replies] {
                oReply = new Comment(cPostId, null, null)
                oReply.fromList(aReplyData)
                add(aReplies, oReply)
            }
        }
        
        cStatus = aData[:status]
    }
    
    # التحقق من صحة التعليق
    func isValid() {
        if cPostId = NULL or cUserId = NULL or cContent = NULL {
            return false
        }
        
        if len(cContent) < 1 or len(cContent) > 500 {
            return false
        }
        
        return true
    }
     # المتغيرات الخاصة بالتعليق
    private
        cPostId      # معرف المنشور المرتبط بالتعليق
        cUserId      # معرف المستخدم الذي كتب التعليق
        cContent     # محتوى التعليق
        cTimestamp   # الطابع الزمني للتعليق
        aLikes       # قائمة الإعجابات على التعليق
        aReplies     # قائمة الردود على التعليق
        cStatus      # حالة التعليق (نشط، محذوف، معلق)
    
}
