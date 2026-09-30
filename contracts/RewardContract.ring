# عقد المكافآت الذكي (Merit & Node Reward Contract)
# يدير توزيع مكافآت الجدارة للمبدعين وحوافز تشغيل العقد المصاحبة



class RewardContract from SmartContract {

    cContractName   = "MeritRewardContract"
    oToken          = NULL
    nBasePostReward = 5
    nStarBonus      = 2

    func init(cOwnerAddress, oTokenContractObj, oDatabase) {
        cContractName = "MeritRewardContract"
        super.init(cOwnerAddress, oDatabase)
        oToken = oTokenContractObj
        nBasePostReward = 5
        nStarBonus = 2
    }

    # توزيع مكافأة لصانع محتوى بناءً على جدارته
    func rewardCreator(cAuthor, nMeritScore) {
        if nMeritScore <= 0 { return false }
        
        # حساب كمية المكافأة: الأساس + نقاط الجدارة
        nReward = nBasePostReward + (nMeritScore * nStarBonus)
        
        # تحويل من محفظة المكافآت التأسيسية للمؤلف
        bSuccess = oToken.transfer(cOwner, cAuthor, nReward)
        if bSuccess {
            nTotalRewarded = number(getState("total_rewarded"))
            setState("total_rewarded", nTotalRewarded + nReward)
            setState("user_reward_" + cAuthor, number(getState("user_reward_" + cAuthor)) + nReward)
        }
        return bSuccess
    }

    # توزيع حوافز لعقد التخزين والمزامنة النشطة
    func rewardNodeOperator(cNodeAddress, nUptimeHours) {
        if nUptimeHours <= 0 { return false }
        nNodeReward = nUptimeHours * 1 # 1 WALA per verified uptime period
        bSuccess = oToken.transfer(cOwner, cNodeAddress, nNodeReward)
        return bSuccess
    }

    func executeAction(cAction, aParams) {
        switch cAction {
            case "rewardCreator"
                return rewardCreator(aParams[:author], number(aParams[:score]))
            case "rewardNode"
                return rewardNodeOperator(aParams[:node], number(aParams[:uptime]))
            other
                return false
        }
    }

    func isValidAction(cAction) {
        return cAction = "rewardCreator" or cAction = "rewardNode"
    }
}
