# عقد عملة الولاء الذكي (WalaCoin Smart Contract)
# يدير المعروض النقدي الإجمالي (24,375,000 WALA) والتحويلات والتفويضات



class TokenContract from SmartContract {

    cContractName  = "WalaCoin"
    cName          = "WalaCoin"
    cSymbol        = "WALA"
    nDecimals      = 6
    nSubUnitFactor = 1000000
    cSubUnitName   = "Ikhlas"
    cSubUnitSymbol = "IKH"
    nMaxSupply     = 24375000
    nTotalSupply   = 24375000
    cStatus        = "active"

    # دالة البناء
    func init(cOwnerAddress, oDatabase) {
        cContractName = "WalaCoin"
        super.init(cOwnerAddress, oDatabase)
        
        cName = "WalaCoin"
        cSymbol = "WALA"
        nDecimals = 6
        nSubUnitFactor = 1000000
        cSubUnitName = "Ikhlas"
        cSubUnitSymbol = "IKH"
        nMaxSupply = 24375000
        nTotalSupply = 24375000
        cStatus = "active"

        # إيداع الرصيد الأولي لمالك العقد (Genesis Pool) فقط إذا لم تتم تهيئته مسبقاً
        cInitCheck = getState("total_supply")
        if isNull(cInitCheck) or cInitCheck = "" {
            setBalance(cOwnerAddress, nTotalSupply)
            setState("name", cName)
            setState("symbol", cSymbol)
            setState("decimals", nDecimals)
            setState("subunit_name", cSubUnitName)
            setState("subunit_symbol", cSubUnitSymbol)
            setState("subunit_factor", nSubUnitFactor)
            setState("total_supply", nTotalSupply)
            setState("max_supply", nMaxSupply)
        }
    }

    # دوال القراءة
    func getName() { return cName }
    func getSymbol() { return cSymbol }
    func getDecimals() { return nDecimals }
    func getSubUnitFactor() { return nSubUnitFactor }
    func getSubUnitName() { return cSubUnitName }
    func getSubUnitSymbol() { return cSubUnitSymbol }
    func getTotalSupply() { return nTotalSupply }
    func getMaxSupply() { return nMaxSupply }
    func getStatus() { return cStatus }

    # التحويل الحسابي بين الولاء والإخلاص
    func toIkhlas(nWala) { return nWala * nSubUnitFactor }
    func toWala(nIkhlas) { return nIkhlas / nSubUnitFactor }

    # قراءة رصيد عنوان بوحدة الولاء
    func getBalanceOf(cAddress) {
        val = getState("balance_" + cAddress)
        if isNull(val) { return 0 }
        return number(val)
    }

    # قراءة رصيد عنوان بوحدة الإخلاص
    func getBalanceOfIkhlas(cAddress) {
        return toIkhlas(getBalanceOf(cAddress))
    }

    # تعيين رصيد عنوان
    func setBalance(cAddress, nAmount) {
        setState("balance_" + cAddress, nAmount)
    }

    # تحويل عملات بين حسابين
    func transfer(cFrom, cTo, nAmount) {
        if nAmount <= 0 { return false }
        if cStatus != "active" { return false }

        nFromBal = getBalanceOf(cFrom)
        if nFromBal < nAmount { return false }

        nToBal = getBalanceOf(cTo)

        # تحديث الأرصدة
        setBalance(cFrom, nFromBal - nAmount)
        setBalance(cTo, nToBal + nAmount)

        # تسجيل المعاملة في دفتر العقد
        add(aTransactions, [
            :from = cFrom,
            :to = cTo,
            :amount = nAmount,
            :type = "transfer",
            :timestamp = date() + " " + time()
        ])

        return true
    }

    # تفويض إنفاق
    func approve(cOwnerAddress, cSpenderAddress, nAmount) {
        if nAmount < 0 { return false }
        setState("allowance_" + cOwnerAddress + "_" + cSpenderAddress, nAmount)
        return true
    }

    # قراءة التفويض
    func getAllowance(cOwnerAddress, cSpenderAddress) {
        val = getState("allowance_" + cOwnerAddress + "_" + cSpenderAddress)
        if isNull(val) { return 0 }
        return number(val)
    }

    # تنفيذ الإجراءات عبر executeAction
    func executeAction(cAction, aParams) {
        switch cAction {
            case "transfer"
                return transfer(aParams[:from], aParams[:to], number(aParams[:amount]))
            case "approve"
                return approve(aParams[:owner], aParams[:spender], number(aParams[:amount]))
            case "balanceOf"
                return getBalanceOf(aParams[:address])
            other
                return false
        }
    }

    func isValidAction(cAction) {
        return cAction = "transfer" or cAction = "approve" or cAction = "balanceOf"
    }
}
