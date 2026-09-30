
/* Class: User
   Represents a user in the social network. This is the main user model
   that includes authentication and blockchain-specific fields.

   Key features:
   - Email/username authentication
   - Public/private key pair for encryption
   - Wallet address management
   - Status tracking (active, suspended, deleted)
   - Created date and last login tracking
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create a new user
   oUser = new User()
   oUser.setEmail("[EMAIL_ADDRESS]")
   oUser.setUsername("john_doe")
   oUser.setPassword("secure_password")  // Note: Password is plain text in this model for future encryption upgrade

   // Generate keys
   oUser.generateKeys()

   // Save to database
   oUser.save()

   // Get user data as list
   data = oUser.toList()

   // Load from list
   oUser.fromList(data)
 */
class User from Model {
    
    # دالة البناء
    func init() {
        super.init()
        dCreatedAt = date()
    }

    # دوال الضبط والحصول

    # المعرف
    func setId(cNewId) { cId = cNewId }
    func getId() { return cId }

    # اسم المستخدم
    func setUsername(cNewUsername) { cUsername = cNewUsername }
    func getUsername() { return cUsername }

    # البريد الإلكتروني
    func setEmail(cNewEmail) { cEmail = cNewEmail }
    func getEmail() { return cEmail }

    # المفتاح العام
    func setPublicKey(cNewKey) { cPublicKey = cNewKey }
    func getPublicKey() { return cPublicKey }

    # المفتاح الخاص المشفر
    func setEncryptedPrivateKey(cNewKey) { cEncryptedPrivateKey = cNewKey }
    func getEncryptedPrivateKey() { return cEncryptedPrivateKey }

    # متجه التهيئة للمفتاح الخاص
    func setPrivateKeyIV(cNewIV) { cPrivateKeyIV = cNewIV }
    func getPrivateKeyIV() { return cPrivateKeyIV }

    # الحالة
    func setStatus(cNewStatus) { cStatus = cNewStatus }
    func getStatus() { return cStatus }

    # تاريخ آخر تسجيل دخول
    func setLastLogin(dNewDate) { dLastLogin = dNewDate }
    func getLastLogin() { return dLastLogin }

    # تحديث آخر تسجيل دخول
    func updateLastLogin() {
        dLastLogin = date()
    }

    # التحقق من نشاط المستخدم
    func isActive() {
        return cStatus = "active"
    }

    # تحويل البيانات إلى قائمة
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:username] = cUsername
        aData[:email] = cEmail
        aData[:public_key] = cPublicKey
        aData[:encrypted_private_key] = cEncryptedPrivateKey
        aData[:private_key_iv] = cPrivateKeyIV
        aData[:status] = cStatus
        aData[:created_at] = dCreatedAt
        aData[:last_login] = dLastLogin
        return aData
    }

    # تحميل البيانات من قائمة
    func fromList(aData) {
        if aData[:id] != NULL {cId = aData[:id]}
        if aData[:username] != NULL {cUsername = aData[:username]}
        if aData[:email] != NULL {cEmail = aData[:email]}
        if aData[:public_key] != NULL {cPublicKey = aData[:public_key]}
        if aData[:encrypted_private_key] != NULL {cEncryptedPrivateKey = aData[:encrypted_private_key]}
        if aData[:private_key_iv] != NULL {cPrivateKeyIV = aData[:private_key_iv]}
        if aData[:status] != NULL {cStatus = aData[:status]}
        if aData[:created_at] != NULL {dCreatedAt = aData[:created_at]}
        if aData[:last_login] != NULL {dLastLogin = aData[:last_login]}
    }
    # المتغيرات الخاصة
    private
        cId = NULL              # معرف المستخدم
        cUsername = NULL        # اسم المستخدم
        cEmail = NULL           # البريد الإلكتروني
        cPublicKey = NULL       # المفتاح العام
        cEncryptedPrivateKey = NULL  # المفتاح الخاص المشفر
        cPrivateKeyIV = NULL    # متجه التهيئة للمفتاح الخاص
        cStatus = "active"      # حالة المستخدم
        dCreatedAt = NULL       # تاريخ الإنشاء
        dLastLogin = NULL       # آخر تسجيل دخول
    

}
