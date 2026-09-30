/* Class: Transaction
   Represents a financial transaction in the system.
   Each transaction has a sender, receiver, amount, signature, and status.

   Key features:
   - Supports both system users and blockchain addresses
   - Linked to blocks in the blockchain
   - Tracks transaction status (pending, completed, failed, confirmed)
   - Verifies transaction validity
   - Converts to list for database storage
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create a transaction
   oTransaction = new Transaction("user-123", "receiver-456", 100.50)

   // Set signature and block ID
   oTransaction.setSignature("abc-123")
   oTransaction.setBlockId("block-789")

   // Check if valid
   if oTransaction.isValid() { ... }

   // Convert to list
   data = oTransaction.toList()

   // Create from list
   oTransaction.fromList(data)
 */


# تعريف صنف المعاملة المالية
class Transaction from Model {
    # دالة التهيئة: إنشاء معاملة جديدة
    func init(cSender, cReceiver, nValue) {
        super.init()
        cSenderId = cSender
        cReceiverId = cReceiver
        nAmount = nValue
        cTimestamp = date() + " " + time()
        cStatus = "pending"  # حالة المعاملة الافتراضية هي معلقة
    }
    
    # دوال الحصول على البيانات
    func getSenderId() { return cSenderId }      # إرجاع معرف المرسل
    func getReceiverId() { return cReceiverId }  # إرجاع معرف المستلم
    func getAmount() { return nAmount }          # إرجاع المبلغ
    func getSignature() { return cSignature }    # إرجاع التوقيع
    func getBlockId() { return cBlockId }        # إرجاع معرف الكتلة
    func getTimestamp() { return cTimestamp }    # إرجاع الطابع الزمني
    func getStatus() { return cStatus }          # إرجاع حالة المعاملة
    
    # دوال تعيين البيانات
    func setSignature(cSign) { cSignature = cSign }      # تعيين التوقيع
    func setBlockId(cBlock) { cBlockId = cBlock }        # تعيين معرف الكتلة
    func setStatus(cNewStatus) { cStatus = cNewStatus }  # تعيين حالة المعاملة
    
    # دالة إنشاء رسالة المعاملة للتوقيع
    func getMessage() {
        return cSenderId + cReceiverId + string(nAmount) + cTimestamp
    }
    
    # تحويل المعاملة إلى قائمة للتخزين
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:sender_id] = cSenderId
        aData[:receiver_id] = cReceiverId
        aData[:amount] = nAmount
        aData[:signature] = cSignature
        aData[:block_id] = cBlockId
        aData[:timestamp] = cTimestamp
        aData[:status] = cStatus
        return aData
    }
    
    # تحميل المعاملة من قائمة
    func fromList(aData) {
        cId = aData[:id]
        cSenderId = aData[:sender_id]
        cReceiverId = aData[:receiver_id]
        nAmount = aData[:amount]
        cSignature = aData[:signature]
        cBlockId = aData[:block_id]
        cTimestamp = aData[:timestamp]
        cStatus = aData[:status]
    }
    
    # التحقق من صحة المعاملة
    func isValid() {
        # التحقق من وجود جميع البيانات المطلوبة
        if cSenderId = NULL or cReceiverId = NULL or nAmount <= 0 {
            return false
        }
        
        # التحقق من التوقيع
        if cSignature = NULL {
            return false
        }
        
        # يمكن إضافة المزيد من عمليات التحقق هنا
        # مثل التحقق من رصيد المرسل وصلاحية التوقيع
        
        return true
    }
    
    # المتغيرات الخاصة بالمعاملة
    private
        cSenderId       # معرف المرسل
        cReceiverId     # معرف المستلم
        nAmount         # المبلغ المالي
        cSignature      # التوقيع الرقمي
        cBlockId        # معرف الكتلة في سلسلة الكتل
        cTimestamp      # الطابع الزمني للمعاملة
        cStatus         # حالة المعاملة (معلقة، مكتملة، مرفوضة)
}
