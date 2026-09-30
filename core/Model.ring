/* Class: Model
   Base class for all models in the application.
   Contains common properties and methods used by all models.

   Key features:
   - Automatic ID generation
   - Created date tracking
   - Error message handling
   - Conversion to list for database storage
   - Loading from list

   Usage:
   // Create a new model
   oModel = new Model()

   // Get ID and created date
   id = oModel.getId()  // Returns random ID
   created = oModel.getCreatedAt()  // Returns current date/time

   // Convert to list
   data = oModel.toList()

   // Create from list
   oModel.fromList(data)
 */

# الفئة الأساسية للنماذج في التطبيق
# تحتوي على الخصائص والدوال المشتركة بين جميع النماذج
class Model {
    
    # دالة التهيئة: تقوم بتوليد معرف فريد وتعيين تاريخ الإنشاء
    func init() {
        cId = random(999999999)
        dCreatedAt = date() + " " + time()
    }
    
    # دوال الوصول للخصائص الأساسية
    func getId() { return cId }                    # استرجاع المعرف
    func getCreatedAt() { return dCreatedAt }      # استرجاع تاريخ الإنشاء
    func getError() { return cError }              # استرجاع رسالة الخطأ
    func setError(error) { cError = error }        # تعيين رسالة الخطأ
    
    # تحويل النموذج إلى قائمة من البيانات
    func toList() {
        return [
            :id = cId,
            :createdAt = dCreatedAt
        ]
    }
    
    # تعبئة بيانات النموذج من قائمة
    func fromList(aData) {
        cId = aData[:id]
        dCreatedAt = aData[:createdAt]
    }
    private
        # معرف فريد للنموذج
        cId
        # تاريخ ووقت إنشاء النموذج
        dCreatedAt
        # رسالة الخطأ إن وجدت
        cError
}
