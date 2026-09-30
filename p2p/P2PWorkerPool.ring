/* ====================================================================
 * Mejde Network - P2P Worker Pool
 * Multi-threaded P2P Engine powered by RingThreadPro.
 *
 * Provides:
 *  1. Concurrent Worker Pool for incoming HTTP/P2P client requests.
 *  2. Background Outbound Gossip Broadcast Worker (Zero UI Lag).
 *  3. Thread-safe Mutex protection for LibSQL Companion DB.
 * ==================================================================== */

load "../core/RingThreadPro.ring"

# Global Synchronization & Pool State
bP2PPoolRunning     = true
oP2PThreadMgr       = NULL
nP2PClientMutex     = 0
nP2PClientCond      = 0
aP2PClientQueue     = []

nP2PGossipMutex     = 0
nP2PGossipCond      = 0
aP2PGossipQueue     = []

nP2PDbMutex         = 0

# Handler references
oP2PPoolDatabase    = NULL
oP2PPoolBlockchain  = NULL
oP2PPoolPosts       = NULL
oP2PPoolMessages    = NULL
oP2PPoolSyncService = NULL
nP2PPoolPort        = 8545

# ----------------------------------------------------------------------
# Worker Thread Functions
# ----------------------------------------------------------------------

# Worker thread loop for handling incoming HTTP / P2P client sockets
func p2pServerWorker nId
    while bP2PPoolRunning
        # Wait for client socket
        oP2PThreadMgr.lockMutex(nP2PClientMutex)
        while len(aP2PClientQueue) = 0 and bP2PPoolRunning
            oP2PThreadMgr.waitCondition(nP2PClientCond, nP2PClientMutex)
        end

        # Check for shutdown signal
        if not bP2PPoolRunning and len(aP2PClientQueue) = 0
            oP2PThreadMgr.unlockMutex(nP2PClientMutex)
            exit
        ok

        clientSocket = aP2PClientQueue[1]
        del(aP2PClientQueue, 1)
        oP2PThreadMgr.unlockMutex(nP2PClientMutex)

        # Process client socket
        if not isNull(clientSocket)
            try{
                handleServerRequest(clientSocket, oP2PPoolDatabase, oP2PPoolBlockchain, oP2PPoolPosts, oP2PPoolMessages, oP2PPoolSyncService, nP2PPoolPort)
            catch
                see "[P2P Worker " + string(nId) + " Error]: " + cCatchError + nl
                try { close(clientSocket)  catch }
            }
        ok
    end

# Background worker loop for dispatching outbound gossip broadcasts
func p2pGossipWorker {
    while bP2PPoolRunning
        # Wait for broadcast items
        oP2PThreadMgr.lockMutex(nP2PGossipMutex)
        while len(aP2PGossipQueue) = 0 and bP2PPoolRunning
            oP2PThreadMgr.waitCondition(nP2PGossipCond, nP2PGossipMutex)
        end

        # Check for shutdown signal
        if not bP2PPoolRunning and len(aP2PGossipQueue) = 0
            oP2PThreadMgr.unlockMutex(nP2PGossipMutex)
            exit
        ok

        aGossipItem = aP2PGossipQueue[1]
        del(aP2PGossipQueue, 1)
        oP2PThreadMgr.unlockMutex(nP2PGossipMutex)

        # Dispatch gossip broadcast in background
        if not isNull(aGossipItem) and not isNull(oP2PPoolSyncService){
            try{
                cType = aGossipItem[:type]
                aData = aGossipItem[:data]
                oP2PPoolSyncService.broadcast(cType, aData)
            catch
                see "[P2P Gossip Worker Error]: " + cCatchError + nl
            }
        }
    end
}


class P2PWorkerPool {

    nWorkers = 4

    func init(nWorkerCount) {
        if nWorkerCount > 0 { nWorkers = nWorkerCount }
        bP2PPoolRunning = true
        aP2PClientQueue = []
        aP2PGossipQueue = []
    }

    func setContext(oDB, oBC, oPosts, oMsgs, oSync, nPort){
        oP2PPoolDatabase    = oDB
        oP2PPoolBlockchain  = oBC
        oP2PPoolPosts       = oPosts
        oP2PPoolMessages    = oMsgs
        oP2PPoolSyncService = oSync
        nP2PPoolPort        = nPort
    }

    func start {
        # Total threads: nWorkers (for incoming requests) + 1 (for outbound gossip)
        nTotalThreads = nWorkers + 1
        oP2PThreadMgr = new ThreadManager(nTotalThreads)

        # Create Synchronization Primitives
        nP2PClientMutex = oP2PThreadMgr.createMutex(1)  # Plain mutex
        nP2PClientCond  = oP2PThreadMgr.createCondition()

        nP2PGossipMutex = oP2PThreadMgr.createMutex(1)  # Plain mutex
        nP2PGossipCond  = oP2PThreadMgr.createCondition()

        nP2PDbMutex     = oP2PThreadMgr.createMutex(4)  # Recursive mutex for DB operations

        # Start incoming request worker threads (Worker 1 to nWorkers)
        for i = 1 to nWorkers
            oP2PThreadMgr.setThreadName(i, "P2P-Worker-" + i)
            oP2PThreadMgr.setThreadPriority(i, 6)
            oP2PThreadMgr.createThread(i, "p2pServerWorker(" + i + ")")
        next

        # Start dedicated outbound gossip worker thread (Thread nTotalThreads)
        nGossipThreadIdx = nTotalThreads
        oP2PThreadMgr.setThreadName(nGossipThreadIdx, "P2P-Gossip-Worker")
        oP2PThreadMgr.setThreadPriority(nGossipThreadIdx, 7)
        oP2PThreadMgr.createThread(nGossipThreadIdx, "p2pGossipWorker()")

        see "[P2P Worker Pool] Started successfully with " + string(nWorkers) + " concurrent workers + 1 gossip worker." + nl
    }

    # Dispatch incoming client socket to worker pool (Instant, Non-blocking)
    func dispatchClient(clientSocket) {
        if isNull(clientSocket) { return }
        oP2PThreadMgr.lockMutex(nP2PClientMutex)
        add(aP2PClientQueue, clientSocket)
        oP2PThreadMgr.signalCondition(nP2PClientCond)
        oP2PThreadMgr.unlockMutex(nP2PClientMutex)
    }

    # Queue an outbound gossip event to be broadcast in background (Instant, Non-blocking)
    func queueBroadcast(cType, aData) {
        oP2PThreadMgr.lockMutex(nP2PGossipMutex)
        add(aP2PGossipQueue, [:type = cType, :data = aData])
        oP2PThreadMgr.signalCondition(nP2PGossipCond)
        oP2PThreadMgr.unlockMutex(nP2PGossipMutex)
    }

    # Thread-safe Database Lock Helper
    func lockDB {
        if nP2PDbMutex > 0 and not isNull(oP2PThreadMgr){
            oP2PThreadMgr.lockMutex(nP2PDbMutex)
        }
    }

    func unlockDB{
        if nP2PDbMutex > 0 and not isNull(oP2PThreadMgr){
            oP2PThreadMgr.unlockMutex(nP2PDbMutex)
        }
    }

    # Graceful Shutdown
    func stop {
        see "[P2P Worker Pool] Shutting down workers..." + nl
        bP2PPoolRunning = false

        # Wake up all request workers
        oP2PThreadMgr.lockMutex(nP2PClientMutex)
        oP2PThreadMgr.broadcastCondition(nP2PClientCond)
        oP2PThreadMgr.unlockMutex(nP2PClientMutex)

        # Wake up gossip worker
        oP2PThreadMgr.lockMutex(nP2PGossipMutex)
        oP2PThreadMgr.broadcastCondition(nP2PGossipCond)
        oP2PThreadMgr.unlockMutex(nP2PGossipMutex)

        # Join and destroy all threads
        oP2PThreadMgr.destroy()
        see "[P2P Worker Pool] Shutdown complete." + nl
    }

}