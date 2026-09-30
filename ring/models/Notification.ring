/* Class: Notification
   Represents a notification for a user.
   Each notification has a type, content, source, and timestamp.

   Key features:
   - Supports different notification types (follow, like, comment, transaction, system)
   - Tracks notification status (new, read, deleted)
   - Can have associated metadata
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create a notification
   oNotification = new Notification("user-123", "like", "John liked your post")

   // Set the source
   oNotification.setSource("post-456", "post")

   // Mark as read
   oNotification.markAsRead()

   // Convert to list for database
   data = oNotification.toList()

   // Create from list
   oNotification.fromList(data)
 */

class Notification from Model {
    
    
    # دالة التهيئة - إنشاء إشعار جديد
    func init(cUser, cNotificationType, cNotificationContent) {
        super.init()
        cUserId = cUser
        cType = cNotificationType
        cContent = cNotificationContent
        cTimestamp = date() + " " + time()
        cStatus = "new"
        aMetadata = []
    }
    
    # دوال الحصول على قيم المتغيرات
    func getUserId() { return cUserId }          # إرجاع معرف المستخدم
    func getType() { return cType }              # إرجاع نوع الإشعار
    func getContent() { return cContent }        # إرجاع محتوى الإشعار
    func getSourceId() { return cSourceId }      # إرجاع معرف المصدر
    func getSourceType() { return cSourceType }  # إرجاع نوع المصدر
    func getTimestamp() { return cTimestamp }    # إرجاع الطابع الزمني
    func getStatus() { return cStatus }          # إرجاع حالة الإشعار
    func getMetadata() { return aMetadata }      # إرجاع البيانات الإضافية
    
    # دوال تعيين قيم المتغيرات
    func setContent(cNewContent) { cContent = cNewContent }    # تعيين محتوى الإشعار
    func setStatus(cNewStatus) { cStatus = cNewStatus }        # تعيين حالة الإشعار
    func setSource(cId, cType) {                              # تعيين مصدر الإشعار
        cSourceId = cId
        cSourceType = cType
    }
    
    # دوال إدارة البيانات الإضافية
    func addMetadata(cKey, xValue) {
        aMetadata[cKey] = xValue
    }
    
    func getMetadataValue(cKey) {
        return aMetadata[cKey]
    }
    
    # تعيين الإشعار كمقروء
    func markAsRead() {
        cStatus = "read"
    }
    
    # تعيين الإشعار كمحذوف
    func markAsDeleted() {
        cStatus = "deleted"
    }
    
    # تحويل الإشعار إلى قائمة
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:user_id] = cUserId
        aData[:type] = cType
        aData[:content] = cContent
        aData[:source_id] = cSourceId
        aData[:source_type] = cSourceType
        aData[:timestamp] = cTimestamp
        aData[:status] = cStatus
        aData[:metadata] = aMetadata
        return aData
    }
    
    # تحميل الإشعار من قائمة
    func fromList(aData) {
        cId = aData[:id]
        cUserId = aData[:user_id]
        cType = aData[:type]
        cContent = aData[:content]
        cSourceId = aData[:source_id]
        cSourceType = aData[:source_type]
        cTimestamp = aData[:timestamp]
        cStatus = aData[:status]
        aMetadata = aData[:metadata]
    }
    
    # التحقق من صحة الإشعار
    func isValid() {
        if cUserId = NULL or cType = NULL or cContent = NULL {
            return false
        }
        
        # التحقق من نوع الإشعار
        aValidTypes = ["follow", "like", "comment", "transaction", "system"]
        if not find(aValidTypes, cType) {
            return false
        }
        
        # التحقق من حالة الإشعار
        aValidStatuses = ["new", "read", "deleted"]
        if not find(aValidStatuses, cStatus) {
            return false
        }
        
        return true
    }
    # المتغيرات الخاصة بالإشعار
    private 
        cUserId         # معرف المستخدم المستلم للإشعار
        cType           # نوع الإشعار (متابعة، إعجاب، تعليق، معاملة، إلخ)
        cContent        # محتوى الإشعار
        cSourceId       # معرف المصدر (مستخدم، منشور، تعليق، معاملة)
        cSourceType     # نوع المصدر (مستخدم، منشور، تعليق، معاملة)
        cTimestamp      # الطابع الزمني للإشعار
        cStatus         # حالة الإشعار (جديد، مقروء، محذوف)
        aMetadata      # بيانات إضافية للإشعار
    
}
