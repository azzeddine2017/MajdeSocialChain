# مدير ومسجل العقود الذكية لشبكة Mejde (SocialChain)
# يدير جميع العقود الاقتصادية، المكافآت، والتوثيق، ويربطها بقاعدة بيانات LibSQL

class ContractManager {

    cOwner = ""
    oDB = NULL
    aContracts = []
    aContractAddresses = [
        :token = "",
        :reward = "",
        :staking = ""
    ]
    oTokenContract = NULL
    oRewardContract = NULL
    oStakingContract = NULL

    # دالة البناء
    func init(cOwnerAddress, oDatabase) {
        cOwner = cOwnerAddress
        oDB = oDatabase
        initializeContracts()
    }

    # الحصول على عنوان عقد معين
    func getContractAddress(cContractType) {
        return aContractAddresses[cContractType]
    }

    # الحصول على كائن عقد معين
    func getContract(cContractAddress) {
        for oItem in aContracts {
            if oItem[:address] = cContractAddress {
                return oItem[:contract]
            }
        }
        return NULL
    }

    func getTokenContract() { return oTokenContract }
    func getRewardContract() { return oRewardContract }
    func getStakingContract() { return oStakingContract }

    # تنفيذ عملية مباشرة على عقد معين
    func executeContract(cContractAddress, cAction, aParams) {
        oContract = getContract(cContractAddress)
        if not isNull(oContract) {
            return oContract.execute(cAction, aParams)
        }
        return false
    }

    # عمليات تسهيلية سريعة للربط مع BlockchainService
    func transferWALA(cFrom, cTo, nAmount) {
        if not isNull(oTokenContract) {
            return oTokenContract.transfer(cFrom, cTo, nAmount)
        }
        return false
    }

    func rewardCreator(cAuthor, nMeritScore) {
        if not isNull(oRewardContract) {
            return oRewardContract.rewardCreator(cAuthor, nMeritScore)
        }
        return false
    }

    func stakeWALA(cUser, nAmount) {
        if not isNull(oStakingContract) {
            return oStakingContract.stake(cUser, nAmount)
        }
        return false
    }

    func rewardNode(cNodeAddress, nUptimeHours) {
        if not isNull(oRewardContract) {
            return oRewardContract.rewardNodeOperator(cNodeAddress, nUptimeHours)
        }
        return false
    }

    func unstakeWALA(cUser, nAmount) {
        if not isNull(oStakingContract) {
            return oStakingContract.unstake(cUser, nAmount)
        }
        return false
    }

    func getDailyQuota(cUser) {
        nBase = 25 # الحصة اليومية الأساسية للحسابات المجانية
        if not isNull(oStakingContract) {
            nBoost = oStakingContract.getDailyQuotaBoost(cUser)
            return nBase + nBoost
        }
        return nBase
    }

    private
        # تهيئة العقود الأساسية في شبكة مجد
        func initializeContracts() {
            # 1. عقد عملة الولاء WALA
            oTokenContract = new TokenContract(cOwner, oDB)
            aContractAddresses[:token] = oTokenContract.getAddress()
            add(aContracts, [
                :address = aContractAddresses[:token],
                :contract = oTokenContract,
                :name = "WalaCoin"
            ])

            # 2. عقد مكافآت الجدارة والعقد
            oRewardContract = new RewardContract(cOwner, oTokenContract, oDB)
            aContractAddresses[:reward] = oRewardContract.getAddress()
            add(aContracts, [
                :address = aContractAddresses[:reward],
                :contract = oRewardContract,
                :name = "MeritRewardContract"
            ])

            # 3. عقد الرهن ومكافحة الروبوتات
            oStakingContract = new StakingContract(cOwner, oTokenContract, oDB)
            aContractAddresses[:staking] = oStakingContract.getAddress()
            add(aContracts, [
                :address = aContractAddresses[:staking],
                :contract = oStakingContract,
                :name = "StakingContract"
            ])

            see "Contracts initialized on Mejde Network: Token=" + aContractAddresses[:token] + nl
        }
}
