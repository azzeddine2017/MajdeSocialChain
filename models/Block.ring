/* Class: Block
   Represents a block in the blockchain.
   Each block contains transactions and has a hash that links it to the previous block.

   Key features:
   - Contains transactions, previous hash, Merkle root, nonce, and timestamp
   - Supports mining with difficulty level
   - Verifies block integrity
   - Safe with prepared statements and no raw string interpolation

   Usage:
   // Create a new block
   oBlock = new Block("previous-hash-123")

   // Add transactions
   oBlock.addTransaction(oTransaction)

   // Mine the block
   oBlock.mine(4)  // 4 leading zeros

   // Check if block is valid
   if oBlock.isValid() { ... }

   // Get block data
   data = oBlock.toList()

   // Create from list
   oBlock.fromList(data)
 */
class Block from Model {
    # دالة التهيئة
    func init(cPrevHash) {
        super.init()
        cPreviousHash = cPrevHash
        cTimestamp = date() + " " + time()
        nNonce = 0
        aTransactions = []
    }
    
    # دوال الحصول على قيم المتغيرات
    func getPreviousHash() { return cPreviousHash }
    func getMerkleRoot() { return cMerkleRoot }
    func getNonce() { return nNonce }
    func getTimestamp() { return cTimestamp }
    func getTransactions() { return aTransactions }
    
    # دوال تعيين قيم المتغيرات
    func setPreviousHash(cHash) { cPreviousHash = cHash }
    func setNonce(nValue) { nNonce = nValue }
    func setTimestamp(cTime) { cTimestamp = cTime }
    
    # إضافة معاملة جديدة للكتلة
    func addTransaction(oTransaction) {
        add(aTransactions, oTransaction)
        calculateMerkleRoot()  # إعادة حساب جذر ميركل
    }
    
    # حساب جذر شجرة ميركل
    func calculateMerkleRoot() {
        if len(aTransactions) = 0 {
            cMerkleRoot = ""
            return
        }
        
        # حساب هاش لكل معاملة
        aHashes = []
        for oTransaction in aTransactions {
            add(aHashes, sha256(oTransaction.getMessage()))
        }
        
        # دمج الهاشات حتى نصل إلى هاش واحد
        while len(aHashes) > 1 {
            # إذا كان عدد الهاشات فردي، نكرر آخر هاش
            if len(aHashes) % 2 != 0 {
                add(aHashes, aHashes[len(aHashes)])
            }
            
            # دمج كل زوج من الهاشات
            aNewHashes = []
            for i = 1 to len(aHashes) step 2 {
                cCombined = aHashes[i] + aHashes[i+1]
                add(aNewHashes, sha256(cCombined))
            }
            aHashes = aNewHashes
        }
        
        cMerkleRoot = aHashes[1]
    }
    
    # تعدين الكتلة
    func mine(nDifficulty) {
        cTarget = substr("0", 1, nDifficulty)  # الهدف هو عدد معين من الأصفار في بداية الهاش
        
        # تكرار حتى نجد هاش يبدأ بالعدد المطلوب من الأصفار
        while left(calculateHash(), nDifficulty) != cTarget {
            nNonce++
        }
    }
    
    # حساب هاش الكتلة
    func calculateHash() {
        cData = cPreviousHash + cMerkleRoot + string(nNonce) + cTimestamp
        return sha256(cData)
    }
    
    # تحويل الكتلة إلى قائمة
    func toList() {
        aData = []
        aData[:id] = cId
        aData[:previous_hash] = cPreviousHash
        aData[:merkle_root] = cMerkleRoot
        aData[:nonce] = nNonce
        aData[:timestamp] = cTimestamp
        
        # تحويل كل المعاملات إلى قوائم
        aTransactionsList = []
        for oTransaction in aTransactions {
            add(aTransactionsList, oTransaction.toList())
        }
        aData[:transactions] = aTransactionsList
        
        return aData
    }
    
    # تحميل بيانات الكتلة من قائمة
    func fromList(aData) {
        cId = aData[:id]
        cPreviousHash = aData[:previous_hash]
        cMerkleRoot = aData[:merkle_root]
        nNonce = aData[:nonce]
        cTimestamp = aData[:timestamp]
        
        # تحميل المعاملات
        aTransactions = []
        if aData[:transactions] != NULL {
            for aTransactionData in aData[:transactions] {
                oTransaction = new Transaction(null, null, 0)
                oTransaction.fromList(aTransactionData)
                add(aTransactions, oTransaction)
            }
        }
    }
    
    # التحقق من صحة الكتلة
    func isValid() {
        # التحقق من صحة الهاش
        if calculateHash() != cHash {
            return false
        }
        
        # التحقق من صحة جذر ميركل
        cCurrentMerkleRoot = cMerkleRoot
        calculateMerkleRoot()
        if cCurrentMerkleRoot != cMerkleRoot {
            return false
        }
        
        # التحقق من صحة المعاملات
        for oTransaction in aTransactions {
            if not oTransaction.isValid() {
                return false
            }
        }
        
        return true
    }
     # المتغيرات الخاصة بالكتلة
    private 
        cPreviousHash    # هاش الكتلة السابقة
        cMerkleRoot      # جذر شجرة ميركل للمعاملات
        nNonce           # قيمة النونس المستخدمة في التعدين
        cTimestamp       # الطابع الزمني للكتلة
        aTransactions    # قائمة المعاملات في الكتلة
}
