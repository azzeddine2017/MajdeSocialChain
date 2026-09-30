/* Class: Service
   Base class for all services in the application.
   Provides common methods for handling success and error responses.

   Key features:
   - Success response formatting
   - Error response formatting
   - Error message storage and retrieval

   Usage:
   // Handle a successful operation
   result = oService.handleSuccess(data)

   // Handle an error
   result = oService.handleError("An error occurred")

   // Get error message
   errorMessage = oService.getError()
 */

# الفئة الأساسية للخدمات في التطبيق
# توفر الدوال المشتركة لمعالجة النجاح والأخطاء في العمليات
class Service {
    
    # دالة معالجة النجاح: تقوم بتغليف البيانات في نسق موحد للاستجابة
    func handleSuccess(data) {
        return [
            :success = true,
            :data = data
        ]
    }
    
    # دالة معالجة الخطأ: تقوم بتغليف رسالة الخطأ في نسق موحد للاستجابة
    func handleError(cMessage) {
        return [
            :success = false,
            :error = cMessage
        ]
    }
    
    # دوال الوصول لمتغير الخطأ
    func getError() { return cError }              # استرجاع رسالة الخطأ
    func setError(error) { cError = error }        # تعيين رسالة الخطأ

    private
        # متغير لتخزين رسائل الخطأ
        cError
}
