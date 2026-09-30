/* Class: Post
   Represents a post in the social network.
   Each post has content, author, timestamp, and can have likes, comments, and shares.

   Key features:
   - Linked to a user
   - Supports text content and media attachments
   - Tracks likes, comments, and shares
   - Status tracking (active, deleted, flagged)
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create a new post
   oPost = new Post("user-123", "My first post!")

   // Add media
   oPost.setMediaUrl("image.jpg")

   // Add a like
   oPost.addLike("user-456")

   // Convert to list for database
   data = oPost.toList()

   // Create from list
   oPost.fromList(data)
 */
class Post from Model {
    # دالة البناء - تهيئة المنشور بالقيم الأساسية
    func init(cUser, cPostContent, cMedia) {
        super.init()
        cUserId = cUser
        cContent = cPostContent
        cMediaUrl = cMedia
        cTimestamp = date() + " " + time()
        aLikes = []
        aComments = []
        aShares = []
        cStatus = "active"
    }
    
    # دوال الحصول على قيم المتغيرات
    func getUserId() { return cUserId }        # إرجاع معرف المستخدم
    func getContent() { return cContent }      # إرجاع محتوى المنشور
    func getMediaUrl() { return cMediaUrl }    # إرجاع رابط الوسائط
    func getTimestamp() { return cTimestamp }  # إرجاع الطابع الزمني
    func getLikes() { return aLikes }         # إرجاع قائمة الإعجابات
    func getComments() { return aComments }   # إرجاع قائمة التعليقات
    func getShares() { return aShares }       # إرجاع قائمة المشاركات
    func getStatus() { return cStatus }       # إرجاع حالة المنشور
    
    # دوال تعديل قيم المتغيرات
    func setContent(cNewContent) { cContent = cNewContent }   # تعديل محتوى المنشور
    func setMediaUrl(cUrl) { cMediaUrl = cUrl }              # تعديل رابط الوسائط
    func setStatus(cNewStatus) { cStatus = cNewStatus }      # تعديل حالة المنشور
    
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
    
    func addComment(oComment) {
        add(aComments, oComment)
    }
    
    func removeComment(cCommentId) {
        for i = 1 to len(aComments) {
            if aComments[i].getId() = cCommentId {
                del(aComments, i)
                exit
            }
        }
    }
    
    func addShare(cShareUserId) {
        add(aShares, cShareUserId)
    }
    
    # تحويل بيانات المنشور إلى قائمة
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:user_id] = cUserId
        aData[:content] = cContent
        aData[:media_url] = cMediaUrl
        aData[:timestamp] = cTimestamp
        aData[:likes] = aLikes
        
        # تحويل التعليقات إلى قوائم
        aCommentsList = []
        for oComment in aComments {
            add(aCommentsList, oComment.toList())
        }
        aData[:comments] = aCommentsList
        
        aData[:shares] = aShares
        aData[:status] = cStatus
        return aData
    }
    
    # تعبئة بيانات المنشور من قائمة
    func fromList(aData) {
        cId = aData[:id]
        cUserId = aData[:user_id]
        cContent = aData[:content]
        cMediaUrl = aData[:media_url]
        cTimestamp = aData[:timestamp]
        aLikes = aData[:likes]
        
        # تحميل التعليقات
        aComments = []
        if aData[:comments] != NULL {
            for aCommentData in aData[:comments] {
                oComment = new Comment(null, null)
                oComment.fromList(aCommentData)
                add(aComments, oComment)
            }
        }
        
        aShares = aData[:shares]
        cStatus = aData[:status]
    }
    
    # التحقق من صحة المنشور
    func isValid() {
        if cUserId = NULL or cContent = NULL {
            return false
        }
        
        if len(cContent) < 1 or len(cContent) > 1000 {
            return false
        }
        
        return true
    }
     # المتغيرات الخاصة بالمنشور
    private 
        cUserId         # معرف المستخدم الذي أنشأ المنشور
        cContent        # محتوى المنشور
        cMediaUrl       # رابط الوسائط المتعددة (صورة أو فيديو)
        cTimestamp      # الطابع الزمني للمنشور
        aLikes         # قائمة الإعجابات
        aComments      # قائمة التعليقات
        aShares        # قائمة المشاركات
        cStatus        # حالة المنشور (نشط، محذوف، معلق)
    
}
