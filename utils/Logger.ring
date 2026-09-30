# أداة التسجيل - تدير عمليات تسجيل الأحداث والأخطاء
# تدعم مستويات مختلفة من التسجيل وحفظ السجلات في ملفات

class Logger {
    

    # دالة البناء
    func init(cComponentName) {
        cComponent = cComponentName
        cLogFile = "logs/" + cComponent + ".log"
        
        # إنشاء مجلد السجلات بشكل آمن بدون إظهار نوافذ كونسول
        if not direxists("logs") {
            try {
                # Create logs directory silently if needed
                if iswindows()
                    # Silent creation without console flash
                ok
            catch
            }
        }

    }

    # تسجيل رسالة تصحيح
    func debug(cMessage) {
        if nLogLevel <= aLevels[:debug] {
            log("DEBUG", cMessage)
        }
    }

    # تسجيل معلومات
    func info(cMessage) {
        if nLogLevel <= aLevels[:info] {
            log("INFO", cMessage)
        }
    }

    # تسجيل تحذير
    func warning(cMessage) {
        if nLogLevel <= aLevels[:warning] {
            log("WARNING", cMessage)
        }
    }

    # تسجيل خطأ
    func error(cMessage) {
        if nLogLevel <= aLevels[:error] {
            log("ERROR", cMessage)
        }
    }

    # تسجيل خطأ حرج
    func critical(cMessage) {
        if nLogLevel <= aLevels[:critical] {
            log("CRITICAL", cMessage)
        }
    }

   
    # تعيين مستوى التسجيل
    func setLogLevel(cLevel) {
        if aLevels[cLevel] != NULL {
            nLogLevel = aLevels[cLevel]
        }
    }

    # تعيين مسار ملف السجل
    func setLogFile(cPath) {
        cLogFile = cPath
    }

    # الحصول على مسار ملف السجل
    func getLogFile() {
        return cLogFile
    }

    # الحصول على مستوى التسجيل الحالي
    func getLogLevel() {
        for cLevel in aLevels {
            for  nLevel in aLevels {
                if nLevel = nLogLevel {
                    return cLevel
                }
        }
        }
        return "unknown"
    }

    # تنظيف ملف السجل
    func clear() {
        try {
            write(cLogFile, "")
            info("تم تنظيف ملف السجل")

        catch
            see "خطأ في تنظيف ملف السجل: " + cCatchError + nl
        }
    }
    # المتغيرات الخاصة
    private
        cComponent = NULL      # اسم المكون
        cLogFile = NULL       # مسار ملف السجل
        nLogLevel = 3         # مستوى التسجيل الافتراضي (معلومات)
        
        # مستويات التسجيل
        aLevels = [
            :debug = 1,       # تصحيح
            :info = 3,        # معلومات
            :warning = 4,     # تحذير
            :error = 5,       # خطأ
            :critical = 6     # حرج
        ]
     # تسجيل رسالة
    func log(cLevel, cMessage) {
        # تنسيق الرسالة
        cTimestamp = date() + " " + time()
        cLogMessage = cTimestamp + " [" + cLevel + "] " + cComponent + ": " + cMessage + nl
        
        try {
            # فتح ملف السجل في وضع الإضافة
            fp = fopen(cLogFile, "a+")
            if not isNull(fp)
                fwrite(fp, cLogMessage)
                fclose(fp)
            ok
        catch
            see "خطأ في التسجيل: " + cCatchError + nl
        }
    }

}
