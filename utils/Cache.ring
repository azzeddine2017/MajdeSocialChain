# نظام التخزين المؤقت - يدير تخزين وإدارة البيانات المؤقتة
# يدعم تخزين المعاملات والكتل والمستخدمين

load "utils/Logger.ring"

class Cache {
    # المتغيرات الخاصة
    
    # دالة البناء
    func init {
        oLogger = new Logger("cache")
    }

    # إضافة عنصر للتخزين المؤقت
    func setcKey cKey, value, nCustomExpiry {
        try {
            # التحقق من حجم التخزين المؤقت
            if len(aCache) >= nMaxSize {
                cleanup()
            }

            # تحديد وقت انتهاء الصلاحية
            nExpiry = nCustomExpiry > 0 ? 
                     time() + nCustomExpiry : 
                     time() + nExpiryTime

            # إنشاء عنصر التخزين المؤقت
            aCacheItem = [
                :key = cKey,
                :value = value,
                :expiry = nExpiry,
                :created = time(),
                :hits = 0
            ]

            # إضافة العنصر
            aCache[cKey] = aCacheItem
            oLogger.info("تم إضافة عنصر جديد للتخزين المؤقت: " + cKey)
            return true
        catch
            oLogger.error("خطأ في إضافة عنصر للتخزين المؤقت: " + cCatchError)
            return false
        }
    }

    # الحصول على عنصر من التخزين المؤقت
    func getcKey cKey {
        try {
            # التحقق من وجود العنصر
            if not has(cKey) {
                return NULL
            }

            aCacheItem = aCache[cKey]

            # التحقق من انتهاء الصلاحية
            if time() > aCacheItem[:expiry] {
                remove(cKey)
                return NULL
            }

            # تحديث عدد مرات الوصول
            aCacheItem[:hits]++
            aCache[cKey] = aCacheItem

            return aCacheItem[:value]
        catch
            oLogger.error("خطأ في الحصول على عنصر من التخزين المؤقت: " + cCatchError)
            return NULL
        }
    }

    # التحقق من وجود عنصر
    func hascKey cKey {
        return isstring(cKey) and aCache[cKey] != NULL
    }

    # إزالة عنصر
    func remove cKey {
        try {
            if has(cKey) {
                aCache[cKey] = NULL
                oLogger.info("تم إزالة عنصر من التخزين المؤقت: " + cKey)
                return true
            }
            return false
        catch
            oLogger.error("خطأ في إزالة عنصر من التخزين المؤقت: " + cCatchError)
            return false
        }
    }

    # تنظيف العناصر منتهية الصلاحية
    func cleanup {
        try {
            nCurrentTime = time()
            aExpiredKeys = []

            # تحديد العناصر منتهية الصلاحية
            for cKey in aCache {
                for aCacheItem in aCache {
                    if aCacheItem != NULL and nCurrentTime > aCacheItem[:expiry] {
                        add(aExpiredKeys, cKey)
                    }
                }
            }

            # إزالة العناصر منتهية الصلاحية
            for cKey in aExpiredKeys {
                remove(cKey)
            }

            oLogger.info("تم تنظيف " + len(aExpiredKeys) + " عنصر من التخزين المؤقت")
            return true
        catch
            oLogger.error("خطأ في تنظيف التخزين المؤقت: " + cCatchError)
            return false
        }
    }

    # تفريغ التخزين المؤقت
    func clear {
        try {
            aCache = []
            oLogger.info("تم تفريغ التخزين المؤقت")
            return true
        catch
            oLogger.error("خطأ في تفريغ التخزين المؤقت: " + cCatchError)
            return false
        }
    }

    # الحصول على إحصائيات التخزين المؤقت
    func getStats {
        aStats = []
        aStats[:total_items] = len(aCache)
        aStats[:max_size] = nMaxSize
        aStats[:expiry_time] = nExpiryTime
        
        nTotalHits = 0
        nExpiredItems = 0
        nCurrentTime = time()
        
        for cKey in aCache {
            for aCacheItem in aCache {
                if aCacheItem != NULL {
                    nTotalHits += aCacheItem[:hits]
                    if nCurrentTime > aCacheItem[:expiry] {
                        nExpiredItems++
                    }
                }
            }
        }
        
        aStats[:total_hits] = nTotalHits
        aStats[:expired_items] = nExpiredItems
        
        return aStats
    }

    # تعديل إعدادات التخزين المؤقت
    func setMaxSize n {  nMaxSize = n }
    func setExpiryTime n {  nExpiryTime = n }
    func getMaxSize { return nMaxSize }
    func getExpiryTime { return nExpiryTime }

    private 
        aCache = []             # مخزن البيانات المؤقتة
        nMaxSize = 1000        # الحد الأقصى لحجم التخزين المؤقت
        nExpiryTime = 3600    # وقت انتهاء الصلاحية (بالثواني)
        oLogger = NULL         # كائن التسجيل
    
}
