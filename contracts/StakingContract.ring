# عقد التوثيق والرهن الذكي (Staking & Anti-Bot Defense Contract)
# يدير رهن عملات WALA لرفع حصص النشر ومكافحة الروبوتات وتوثيق العقد



class StakingContract from SmartContract {

    cContractName = "StakingContract"
    oToken        = NULL

    func init(cOwnerAddress, oTokenContractObj, oDatabase) {
        cContractName = "StakingContract"
        super.init(cOwnerAddress, oDatabase)
        oToken = oTokenContractObj
    }

    # رهن عملات WALA
    func stake(cUser, nAmount) {
        if nAmount <= 0 { return false }
        
        # تحويل العملات من المستخدم إلى العقد
        bOk = oToken.transfer(cUser, cContractAddress, nAmount)
        if not bOk { return false }

        nCurrentStake = getStaked(cUser)
        nNewStake = nCurrentStake + nAmount
        setState("staked_" + cUser, nNewStake)
        
        nTotalPool = number(getState("total_staked_pool"))
        setState("total_staked_pool", nTotalPool + nAmount)
        
        return true
    }

    # إلغاء رهن العملات
    func unstake(cUser, nAmount) {
        if nAmount <= 0 { return false }
        nCurrentStake = getStaked(cUser)
        if nCurrentStake < nAmount { return false }

        bOk = oToken.transfer(cContractAddress, cUser, nAmount)
        if not bOk { return false }

        setState("staked_" + cUser, nCurrentStake - nAmount)
        nTotalPool = number(getState("total_staked_pool"))
        setState("total_staked_pool", nTotalPool - nAmount)

        return true
    }

    # قراءة الرصيد المرهون
    func getStaked(cUser) {
        val = getState("staked_" + cUser)
        if isNull(val) { return 0 }
        return number(val)
    }

    # حساب الزيادة في حصة النشر اليومية الناتجة عن الرهن (منشور إضافي لكل 10 WALA مرهونة)
    func getDailyQuotaBoost(cUser) {
        nStaked = getStaked(cUser)
        return floor(nStaked / 10)
    }

    func executeAction(cAction, aParams) {
        switch cAction {
            case "stake"
                return stake(aParams[:user], number(aParams[:amount]))
            case "unstake"
                return unstake(aParams[:user], number(aParams[:amount]))
            case "getStaked"
                return getStaked(aParams[:user])
            other
                return false
        }
    }

    func isValidAction(cAction) {
        return cAction = "stake" or cAction = "unstake" or cAction = "getStaked"
    }
}
