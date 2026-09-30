# أداة التحقق - للتحقق من صحة البيانات المدخلة
# تتضمن دوال للتحقق من صحة اسم المستخدم وكلمة المرور والبريد الإلكتروني

class Validator {
    

    # التحقق من صحة اسم المستخدم
    func isValidUsername(cUsername) {
        if cUsername = NULL {
            return false
        }

        # التحقق من الطول
        nLength = len(cUsername)
        if nLength < nMinUsernameLength or nLength > nMaxUsernameLength {
            return false
        }

        # التحقق من الأحرف المسموح بها
        return regex(cUsername, cUsernamePattern)
    }

    # التحقق من صحة كلمة المرور
    func isValidPassword(cPassword) {
        if cPassword = NULL {
            return false
        }

        # التحقق من الطول
        nLength = len(cPassword)
        if nLength < nMinPasswordLength or nLength > nMaxPasswordLength {
            return false
        }

        # التحقق من تعقيد كلمة المرور
        return regex(cPassword, cPasswordPattern)
    }

    # التحقق من صحة البريد الإلكتروني
    func isValidEmail(cEmail) {
        if cEmail = NULL {
            return false
        }

        return regex(cEmail, cEmailPattern)
    }

    # التحقق من صحة المفتاح العام
    func isValidPublicKey(cKey) {
        if cKey = NULL {
            return false
        }

        try {
            # محاولة تحميل المفتاح للتحقق من صحته
            oRsa = ssl_rsa_new()
            bValid = ssl_rsa_set_public_key(oRsa, cKey)
            ssl_rsa_free(oRsa)
            return bValid
        catch
            return false
        }
    }

    # التحقق من صحة المفتاح الخاص
    func isValidPrivateKey(cKey) {
        if cKey = NULL {
            return false
        }

        try {
            # محاولة تحميل المفتاح للتحقق من صحته
            oRsa = ssl_rsa_new()
            bValid = ssl_rsa_set_private_key(oRsa, cKey)
            ssl_rsa_free(oRsa)
            return bValid
        catch
            return false
        }
    }

    # تعيين الحد الأدنى لطول اسم المستخدم
    func setMinUsernameLength(nLength) {
        if nLength > 0 {
            nMinUsernameLength = nLength
        }
    }

    # تعيين الحد الأقصى لطول اسم المستخدم
    func setMaxUsernameLength(nLength) {
        if nLength >= nMinUsernameLength {
            nMaxUsernameLength = nLength
        }
    }

    # تعيين الحد الأدنى لطول كلمة المرور
    func setMinPasswordLength(nLength) {
        if nLength > 0 {
            nMinPasswordLength = nLength
        }
    }

    # تعيين الحد الأقصى لطول كلمة المرور
    func setMaxPasswordLength(nLength) {
        if nLength >= nMinPasswordLength {
            nMaxPasswordLength = nLength
        }
    }

    # تعيين نمط التحقق من البريد الإلكتروني
    func setEmailPattern(cPattern) {
        if cPattern != NULL {
            cEmailPattern = cPattern
        }
    }

    # تعيين نمط التحقق من اسم المستخدم
    func setUsernamePattern(cPattern) {
        if cPattern != NULL {
            cUsernamePattern = cPattern
        }
    }

    # تعيين نمط التحقق من كلمة المرور
    func setPasswordPattern(cPattern) {
        if cPattern != NULL {
            cPasswordPattern = cPattern
        }
    }
    # المتغيرات الخاصة
    private
        # الحد الأدنى والأقصى لطول اسم المستخدم
        nMinUsernameLength = 3
        nMaxUsernameLength = 30

        # الحد الأدنى والأقصى لطول كلمة المرور
        nMinPasswordLength = 8
        nMaxPasswordLength = 128

        # التعبيرات النمطية للتحقق
        cEmailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
        cUsernamePattern = "^[A-Za-z0-9_-]+$"
        cPasswordPattern = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$"
}
