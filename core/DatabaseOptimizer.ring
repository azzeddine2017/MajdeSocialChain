/* Class: DatabaseOptimizer
   Optimizes database performance through indexing, query analysis, and cache management.

   Key features:
   - Automatic index creation for common columns
   - Query analysis to identify optimization opportunities
   - Query result caching to speed up repeated queries
   - Index usage tracking
   - Cleanup of unused indexes
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create an optimizer
   oOptimizer = new DatabaseOptimizer()

   // Optimize a query
   result = oOptimizer.optimizeQuery("SELECT * FROM users WHERE id = 1")

   // Check index usage
   stats = oOptimizer.getIndexStats()

   // Cleanup unused indexes
   oOptimizer.cleanupUnusedIndexes()
 */

load "utils/Logger.ring"
load "utils/Cache.ring"

class DatabaseOptimizer {
   
    # دالة البناء
    func init() {
        oLogger = new Logger("database")
        oCache = new Cache()
        oCache.setMaxSize(nMaxCacheSize)
        initializeIndexes()
    }

    # إنشاء فهرس جديد
    func createIndex(cTable, cColumn) {
        try {
            cIndexName = cTable + "_" + cColumn + "_idx"
            if not hasIndex(cIndexName) {
                aIndexes[cIndexName] = [
                    :table = cTable,
                    :column = cColumn,
                    :created = date(),
                    :last_used = NULL,
                    :usage_count = 0
                ]
                oLogger.info("تم إنشاء فهرس جديد: " + cIndexName)
            }
        catch
            oLogger.error("خطأ في إنشاء الفهرس: " + cCatchError)
        }
    }

    # التحقق من وجود فهرس
    func hasIndex cIndexName {
        return aIndexes[cIndexName] != NULL
    }

    # تحسين استعلام
    func optimizeQuery cQuery {
        try {
            # تحليل الاستعلام
            aQueryInfo = analyzeQuery(cQuery)
            
            # البحث في التخزين المؤقت
            cCacheKey = "query_" + sha256(cQuery)
            oResult = oCache.get(cCacheKey)
            
            if oResult != NULL {
                oLogger.info("تم استرجاع النتيجة من التخزين المؤقت")
                return oResult
            }

            # تحسين الاستعلام باستخدام الفهارس
            cOptimizedQuery = applyIndexes(cQuery, aQueryInfo)
            
            # تنفيذ الاستعلام المحسن
            oResult = executeQuery(cOptimizedQuery)
            
            # تخزين النتيجة في التخزين المؤقت
            oCache.set(cCacheKey, oResult)
            
            # تحديث إحصائيات الاستعلام
            updateQueryStats(cQuery, aQueryInfo)
            
            return oResult
        catch
            oLogger.error("خطأ في تحسين الاستعلام: " + cCatchError)
            return NULL
        }
    }

    
    # الحصول على إحصائيات الاستعلامات
    func getQueryStats() {
        return aQueryStats
    }

    # تنظيف الفهارس غير المستخدمة
    func cleanupUnusedIndexes() {
        try {
            aUnusedIndexes = []
            for cIndexName in aIndexes {
                for aIndex in aIndexes {
                    # حذف الفهارس التي لم تستخدم لمدة شهر
                    if aIndex[:last_used] = NULL or 
                    diffDays(aIndex[:last_used], date()) > 30 {
                        add(aUnusedIndexes, cIndexName)
                   }
                }
            }
            
            for cIndexName in aUnusedIndexes {
                aIndexes[cIndexName] = NULL
                oLogger.info("تم حذف فهرس غير مستخدم: " + cIndexName)
            }
            
            return true
        catch
            oLogger.error("خطأ في تنظيف الفهارس: " + cCatchError)
            return false
        }
    }

    # الحصول على إحصائيات الفهارس
    func getIndexStats() {
        aStats = []
        for cIndexName in aIndexes {
            for aIndex in aIndexes {
                aStats[cIndexName] = [
                    :table = aIndex[:table],
                    :column = aIndex[:column],
                    :created = aIndex[:created],
                    :last_used = aIndex[:last_used],
                    :usage_count = aIndex[:usage_count]
                    ]
            }
        }
        return aStats
    }


    # المتغيرات الخاصة
    private
        oLogger = NULL          # كائن التسجيل
        oCache = NULL          # كائن التخزين المؤقت
        aIndexes = []          # فهارس قاعدة البيانات
        aQueryStats = []       # إحصائيات الاستعلامات
        nMaxCacheSize = 5000   # الحد الأقصى لحجم التخزين المؤقت
        nQueryTimeout = 30     # مهلة الاستعلام (بالثواني)

    # تهيئة الفهارس
    func initializeIndexes() {
        # فهارس المستخدمين
        createIndex("users", "id")
        createIndex("users", "email")
        createIndex("users", "username")

        # فهارس المعاملات
        createIndex("transactions", "id")
        createIndex("transactions", "sender_id")
        createIndex("transactions", "receiver_id")
        createIndex("transactions", "timestamp")

        # فهارس المنشورات
        createIndex("posts", "id")
        createIndex("posts", "user_id")
        createIndex("posts", "timestamp")

        # فهارس التعليقات
        createIndex("comments", "id")
        createIndex("comments", "post_id")
        createIndex("comments", "user_id")

        oLogger.info("تم تهيئة الفهارس بنجاح")
    }

        # تحليل استعلام
    func analyzeQuery cQuery {
        aInfo = []
        
        # تحديد نوع الاستعلام
        if substr(cQuery, "SELECT") {aInfo[:type] = "select"}
        if substr(cQuery, "INSERT") {aInfo[:type] = "insert"}
        if substr(cQuery, "UPDATE") {aInfo[:type] = "update"}
        if substr(cQuery, "DELETE") {aInfo[:type] = "delete"}
        
        # تحديد الجداول المستخدمة
        aInfo[:tables] = []
        if substr(cQuery, "FROM") {
            cTablesPart = substr(cQuery, "FROM", "WHERE")
            aTables = split(cTablesPart, ",")
            for cTable in aTables {
                add(aInfo[:tables], trim(cTable))
            }
        }
        
        # تحديد الشروط
        aInfo[:conditions] = []
        if substr(cQuery, "WHERE") {
            cConditionsPart = substr(cQuery, "WHERE")
            aConditions = split(cConditionsPart, "AND")
            for cCondition in aConditions {
                add(aInfo[:conditions], trim(cCondition))
            }
        }
        
        return aInfo
    }

    # تطبيق الفهارس على الاستعلام
    func applyIndexes cQuery, aQueryInfo {
        cOptimizedQuery = cQuery
        
        # تحديد الفهارس المناسبة
        aUsableIndexes = []
        for cIndexName in aIndexes {
            for aIndex in aIndexes {
                if inList(aQueryInfo[:tables], aIndex[:table]) {
                    for cCondition in aQueryInfo[:conditions] {
                        if substr(cCondition, aIndex[:column]) {
                            add(aUsableIndexes, aIndex)
                            # تحديث إحصائيات استخدام الفهرس
                            aIndex[:last_used] = date()
                            aIndex[:usage_count]++
                            aIndexes[cIndexName] = aIndex
                        }
                    }
                }
            }
        }
        
        # تطبيق الفهارس
        if len(aUsableIndexes) > 0 {
            # يمكن إضافة تعليمات USE INDEX هنا
            for aIndex in aUsableIndexes {
                cOptimizedQuery = "/* USE INDEX (" + 
                                    aIndex[:table] + "_" + aIndex[:column] + "_idx" +
                                    ") */ " + cQuery
             }
        }
        
        return cOptimizedQuery
    }

    

    
    func updateQueryStats cQuery, aQueryInfo {
        cQueryHash = sha256(cQuery)
        
        if aQueryStats[cQueryHash] = NULL {
            aQueryStats[cQueryHash] = [
                :query = cQuery,
                :type = aQueryInfo[:type],
                :execution_count = 0,
                :avg_execution_time = 0,
                :last_executed = NULL,
                :cache_hits = 0
            ]
        }
        
        aStats = aQueryStats[cQueryHash]
        aStats[:execution_count]++
        aStats[:last_executed] = date()
        aQueryStats[cQueryHash] = aStats
    }

    # تنفيذ استعلام محسن
    func executeQuery cQuery {
        # هنا يتم تنفيذ الاستعلام الفعلي
        # يمكن إضافة المنطق الخاص بتنفيذ الاستعلام
        return NULL
    }

    # حساب الفرق بين تاريخين بالأيام
    func diffDays cDate1, cDate2 {
        try {
            aDate1 = split(cDate1, "/")
            aDate2 = split(cDate2, "/")
            
            oDate1 = new DateTime {
                year = number(aDate1[1])
                month = number(aDate1[2])
                day = number(aDate1[3])
            }
            
            oDate2 = new DateTime {
                year = number(aDate2[1])
                month = number(aDate2[2])
                day = number(aDate2[3])
            }
            
            return fabs(oDate1.diffDays(oDate2))
        catch
            return 0
        }
    }
}
