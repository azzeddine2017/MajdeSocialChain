# عمليات التشفير الداخلية - AES / PBKDF2 / أرقام عشوائية
if iswindows()
    try
        loadlib("ring_openssl.dll")
    catch
    done
ok

class Crypto_Internal {

    func init() {
    }

    /* تشفير البيانات باستخدام AES-256 عبر Ring Encrypt() */
    func aesEncrypt(cData, cKey, cIv) {
        try {
            return Encrypt(cData, cKey, cIv, "aes256")
        catch
            return NULL
        }
    }

    /* فك تشفير البيانات باستخدام AES-256 عبر Ring Decrypt() */
    func aesDecrypt(cEncrypted, cKey, cIv) {
        try {
            return Decrypt(cEncrypted, cKey, cIv, "aes256")
        catch
            return NULL
        }
    }

    /* اشتقاق مفتاح 32 بايت من كلمة المرور والملح عبر SHA-256 */
    func deriveKey(cPassword, cSalt) {
        try {
            cHash = SHA256(cPassword + cSalt)
            # مفتاح AES-256 يتطلب 32 بايت بالضبط
            return left(cHash, 32)
        catch
            return NULL
        }
    }

    /* توليد بايتات عشوائية عبر Ring Randbytes() */
    func generateRandomBytes(nSize) {
        try {
            return Randbytes(nSize)
        catch
            cRes = ""
            for i = 1 to nSize {
                cRes += char(random(255))
            }
            return cRes
        }
    }

    private
        nAesKeySize = 256
}
