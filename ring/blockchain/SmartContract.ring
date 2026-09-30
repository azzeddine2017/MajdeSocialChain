# النظام الأساسي للعقود الذكية في Mejde (SocialChain)
# يوفر البنية الأساسية للعقود، تخزين الحالة في LibSQL، وتنفيذ العمليات



class SmartContract {

    cContractAddress = ""
    cContractName    = ""
    cOwner           = ""
    cCurrentSender   = ""
    aState           = []
    aTransactions    = []
    nTimestamp       = 0
    oDB              = NULL

    # دالة البناء
    func init(cOwnerAddress, oDatabase) {
        cOwner = cOwnerAddress
        oDB = oDatabase
        if isNull(cContractName) or cContractName = "" { cContractName = "SmartContract" }
        nTimestamp = time()
        cCurrentSender = cOwnerAddress
        cContractAddress = ""
        if not isNull(oDB) {
            try {
                aRows = oDB.queryAssoc("SELECT address FROM contracts WHERE name = '" + cContractName + "' LIMIT 1")
                if not isNull(aRows) and len(aRows) > 0 {
                    cContractAddress = aRows[1][:address]
                }
            catch
            }
        }
        if cContractAddress = "" {
            cContractAddress = generateAddress()
            registerContract()
        }
    }

    # تسجيل العقد في قاعدة البيانات المصاحبة
    func registerContract() {
        if isNull(oDB) { return }
        try {
            oStmt = oDB.prepare("INSERT OR IGNORE INTO contracts (address, name, owner, created_at) VALUES (?, ?, ?, ?)")
            if not isNull(oStmt) {
                oStmt.bindString(1, cContractAddress)
                oStmt.bindString(2, cContractName)
                oStmt.bindString(3, cOwner)
                oStmt.bindString(4, date() + " " + time())
                oStmt.execute()
            }
        catch
        }
    }

    # تحديد مرسل العملية الحالي
    func setSender(cSenderAddress) {
        cCurrentSender = cSenderAddress
    }

    # إرجاع عنوان المرسل
    func sender() {
        if cCurrentSender != "" { return cCurrentSender }
        return cOwner
    }

    # تنفيذ العقد
    func execute(cAction, aParams) {
        if not isValidAction(cAction) { return false }
        
        # تسجيل المعاملة
        aTransaction = [ 
            :action = cAction,
            :params = aParams,
            :timestamp = time(),
            :sender = sender() 
        ]
        
        # تنفيذ الإجراء في العقد الفرعي
        result = executeAction(cAction, aParams)
        aTransaction[:result] = result
        
        # حفظ المعاملة في الذاكرة
        add(aTransactions, aTransaction)
        return result
    }

    # حفظ قيمة في حالة العقد (مع الحفظ الدائم في LibSQL)
    func setState(cKey, value) {
        # 1. تحديث الذاكرة
        bFound = false
        for i = 1 to len(aState) {
            if aState[i][:key] = cKey {
                aState[i][:value] = value
                bFound = true
                exit
            }
        }
        if not bFound {
            add(aState, [ :key = cKey, :value = value ])
        }

        # 2. الحفظ في قاعدة بيانات LibSQL
        if not isNull(oDB) {
            try {
                oStmt = oDB.prepare("INSERT OR REPLACE INTO contract_state (contract_address, key, value, updated_at) VALUES (?, ?, ?, ?)")
                if not isNull(oStmt) {
                    oStmt.bindString(1, cContractAddress)
                    oStmt.bindString(2, cKey)
                    oStmt.bindString(3, string(value))
                    oStmt.bindString(4, date() + " " + time())
                    oStmt.execute()
                }
            catch
            }
        }
    }

    # قراءة قيمة من حالة العقد
    func getState(cKey) {
        # 1. فحص الكاش المحلي أولاً
        for item in aState {
            if item[:key] = cKey {
                return item[:value]
            }
        }

        # 2. فحص قاعدة البيانات إذا لم تكن في الكاش
        if not isNull(oDB) {
            try {
                aRows = oDB.queryAssoc("SELECT value FROM contract_state WHERE contract_address = '" + cContractAddress + "' AND key = '" + cKey + "' LIMIT 1")
                if not isNull(aRows) and len(aRows) > 0 {
                    val = aRows[1][:value]
                    add(aState, [ :key = cKey, :value = val ])
                    return val
                }
            catch
            }
        }

        return NULL
    }

    # التحقق من المالك
    func isOwner() {
        return sender() = cOwner
    }

    # إرجاع عنوان العقد
    func getAddress() {
        return cContractAddress
    }

    # إرجاع سجل المعاملات
    func getTransactions() {
        return aTransactions
    }

    private
        # توليد عنوان فريد وثابت للعقد
        func generateAddress() {
            cData = "Mejde_Contract_" + cContractName + "_" + cOwner
            return "0x" + SHA256(cData)
        }

        # التحقق من صحة الإجراء (يتم تجاوزه في العقود المشتقة)
        func isValidAction(cAction) {
            return true
        }

        # تنفيذ الإجراء (يتم تجاوزه في العقود المشتقة)
        func executeAction(cAction, aParams) {
            return false
        }
}
