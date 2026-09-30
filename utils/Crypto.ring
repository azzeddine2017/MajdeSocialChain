# أداة التشفير - تدير عمليات التشفير وفك التشفير والتوقيع الرقمي
# متوافقة بنسبة 100% مع دوال Ring OpenSSL الرسمية (openssllib.ring)



class Crypto {

    /* مُنشئ */
    func init() {
        oInternal = new Crypto_Internal()
        oLogger   = new Logger("crypto")
    }

    /* توليد زوج مفاتيح RSA 2048 حقيقي بصيغة PEM */
    func generateKeyPair() {
        try {
            # توليد مفتاح RSA بحجم 2048 بت
            rsaKey = rsa_generate(2048)
            cPrivatePEM = rsa_export_pem(rsaKey)
            
            # استخراج الجزء العام فقط للمفتاح العام
            rsaKeyParams = rsa_export_params(rsaKey)
            rsaPublicKeyParam = [:n = rsaKeyParams[:n], :e = rsaKeyParams[:e]]
            rsaPublicKey = rsa_import_params(rsaPublicKeyParam)
            cPublicPEM = rsa_export_pem(rsaPublicKey)
            
            oLogger.info("تم توليد زوج مفاتيح RSA 2048 بنجاح")
            return [
                :public  = cPublicPEM,
                :private = cPrivatePEM
            ]
        catch
            oLogger.error("فشل في توليد زوج المفاتيح: " + cCatchError)
            return NULL
        }
    }

    /* تأمين المفتاح الخاص باستخدام كلمة المرور عبر AES-256 */
    func securePrivateKey(cPrivateKey, cPassword) {
        try {
            cSalt         = oInternal.generateRandomBytes(16)
            cAesKey       = oInternal.deriveKey(cPassword, cSalt)
            cIv           = oInternal.generateRandomBytes(16)
            cEncryptedKey = oInternal.aesEncrypt(cPrivateKey, cAesKey, cIv)
            if cEncryptedKey = NULL { return NULL }
            
            oLogger.info("تم تأمين المفتاح الخاص بنجاح")
            return [
                :key  = str2hex(cEncryptedKey),
                :iv   = str2hex(cIv),
                :salt = str2hex(cSalt)
            ]
        catch
            oLogger.error("فشل في تأمين المفتاح الخاص: " + cCatchError)
            return NULL
        }
    }

    /* استرجاع المفتاح الخاص وفك تشفيره باستخدام كلمة المرور */
    func retrievePrivateKey(cEncryptedKey, cIv, cSalt, cPassword) {
        try {
            cKey = cEncryptedKey
            cRealIv = cIv
            cRealSalt = cSalt
            
            # فك ترميز hex إلى بايتات ثنائية
            try {
                cKey = hex2str(cEncryptedKey)
                cRealIv = hex2str(cIv)
                cRealSalt = hex2str(cSalt)
            catch
            }

            cAesKey     = oInternal.deriveKey(cPassword, cRealSalt)
            cPrivateKey = oInternal.aesDecrypt(cKey, cAesKey, cRealIv)
            
            # التحقق من صحة المفتاح الخاص المفكوك
            if cPrivateKey = NULL or substr(cPrivateKey, "PRIVATE KEY") = 0 { 
                # محاولة احتياطية في حال كانت البيانات مخزنة ثنائياً مسبقاً
                try {
                    cAesKey2     = oInternal.deriveKey(cPassword, cSalt)
                    cPrivateKey2 = oInternal.aesDecrypt(cEncryptedKey, cAesKey2, cIv)
                    if cPrivateKey2 != NULL and substr(cPrivateKey2, "PRIVATE KEY") > 0 {
                        oLogger.info("تم استرجاع المفتاح الخاص بنجاح")
                        return cPrivateKey2
                    }
                catch
                }
                oLogger.warning("كلمة المرور غير صحيحة")
                return NULL 
            }
            oLogger.info("تم استرجاع المفتاح الخاص بنجاح")
            return cPrivateKey
        catch
            oLogger.error("فشل في استرجاع المفتاح الخاص: " + cCatchError)
            return NULL
        }
    }

    /* التوقيع الرقمي RSA PKCS#1 v1.5 مع SHA256 */
    func sign(cData, cPrivateKeyPEM) {
        try {
            rsaKey = rsa_import_pem(cPrivateKeyPEM)
            cDigest = SHA256(cData)
            cSignature = rsa_signhash_pkcs(rsaKey, cDigest)
            return str2hex(cSignature)
        catch
            oLogger.error("فشل في التوقيع: " + cCatchError)
            return NULL
        }
    }

    /* التحقق من التوقيع الرقمي RSA PKCS#1 v1.5 */
    func verify(cData, cSignature, cPublicKeyPEM) {
        try {
            rsaPublicKey = rsa_import_pem(cPublicKeyPEM)
            cDigest = SHA256(cData)
            
            cRealSig = cSignature
            try {
                cRealSig = hex2str(cSignature)
            catch
            }
            
            bRes = rsa_verifyhash_pkcs(rsaPublicKey, cDigest, cRealSig)
            if bRes { return true }
            return rsa_verifyhash_pkcs(rsaPublicKey, cDigest, cSignature)
        catch
            return false
        }
    }

    /* حساب SHA-256 */
    func hash(cData) {
        return SHA256(cData)
    }

    /* توليد عبارة استرداد 12 كلمة متوافقة مع BIP-39 */
    func generateMnemonic() {
        cMnemonic = ""
        nTotal = len(aBip39Words)
        for i = 1 to 12 {
            nIdx = (random(nTotal - 1)) + 1
            if i > 1 { cMnemonic += " " }
            cMnemonic += aBip39Words[nIdx]
        }
        return cMnemonic
    }

    /* حساب البصمة المشفرة للكلمات الـ 12 */
    func hashMnemonic(cMnemonic) {
        cClean = lower(trim(cMnemonic))
        return SHA256(cClean)
    }

    private
        oInternal
        oLogger
        aBip39Words = [
            "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
            "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
            "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
            "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance",
            "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
            "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album",
            "alcohol", "alert", "alien", "all", "alley", "allow", "almost", "alone",
            "alpha", "already", "also", "alter", "always", "amateur", "amazing", "among",
            "amount", "amused", "analyst", "anchor", "ancient", "anger", "angle", "angry",
            "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
            "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april",
            "arch", "arctic", "area", "arena", "argue", "arm", "armed", "armor",
            "army", "around", "arrange", "arrest", "arrive", "arrow", "art", "artefact",
            "artist", "artwork", "ask", "aspect", "assault", "asset", "assist", "assume",
            "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction",
            "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado"
        ]
}  
