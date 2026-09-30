/* ====================================================================
 * Mejde Network - CLI Node Control & Testing Tool 
 * Interacts with running Mejde nodes via HTTP API.
 *
 * Usage:
 *   ring cli.ring [port] <command> [args...]
 *
 * Commands:
 *   status                             View node telemetry and status
 *   peers                              List connected peers
 *   refill  <user_id> [amount]         Request WALA tokens from Mother Node
 *   balance <user_id>                  Check account balance
 *   post    <user_id> <content>        Publish a post and broadcast to network
 *   send    <from> <to> <amount>       Transfer WALA tokens
 *   sync                               Trigger instant P2P sync with peers
 *   posts                              List latest posts on this node
 *   txs                                List confirmed transactions
 *
 * Examples:
 *   ring cli.ring 8545 status
 *   ring cli.ring 8545 refill user_alice 100
 *   ring cli.ring 8545 balance user_alice
 *   ring cli.ring 8545 post user_alice "Hello Mejde Decentralized World!"
 *   ring cli.ring 8546 sync
 *   ring cli.ring 8546 posts
 *   ring cli.ring 8546 balance user_alice
 * ==================================================================== */



load "stdlib.ring"
load "sockets.ring"

# Parse CLI arguments
# sysargv[1] = ring executable
# sysargv[2] = cli.ring
# sysargv[3] = first argument (can be port like 8545, or command like status)
nPort = 8545
cCommand = ""
aArgs = []

if len(sysargv) < 3 {
    printHelp()
    return
}

# Check if first user arg (sysargv[3]) is port number or command
cFirstArg = sysargv[3]
nIdx = 3
try {
    nCheckPort = number(cFirstArg)
    if nCheckPort > 1024 and nCheckPort < 65535 {
        nPort = nCheckPort
        nIdx = 4
    }
catch
}

if len(sysargv) >= nIdx {
    cCommand = lower(sysargv[nIdx])
    for i = (nIdx + 1) to len(sysargv) {
        aArgs + sysargv[i]
    }
else
    cCommand = "status"
}

cBaseUrl = "http://127.0.0.1:" + string(nPort)

see "==================================================================" + nl
see "  MEJDE CLI -> Target Node: " + cBaseUrl + " | Command: " + cCommand + nl
see "==================================================================" + nl

# ----------------------------------------------------------------------
# Command Execution
# ----------------------------------------------------------------------

if cCommand = "status" {
    cResp = httpGet(cBaseUrl + "/p2p/status")
    if isNull(cResp) or cResp = "" {
        see "[Error] Could not connect to node at " + cBaseUrl + ". Is it running?" + nl
    else
        see "[Node Status Response]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "peers" {
    cResp = httpGet(cBaseUrl + "/p2p/peers")
    if isNull(cResp) or cResp = "" {
        see "[Error] Could not connect to node." + nl
    else
        see "[Connected Peers]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "addpeer" {
    if len(aArgs) < 1 {
        see "[Usage] ring cli.ring " + string(nPort) + " addpeer <peer_url>" + nl
        return
    }
    cPeer = aArgs[1]
    cBody = '{"url":"' + cPeer + '","name":"' + cPeer + '"}'
    see "[Registering peer " + cPeer + " on " + cBaseUrl + "...]" + nl
    cResp = httpPost(cBaseUrl + "/p2p/register_peer", cBody)
    if isNull(cResp) or cResp = "" {
        see "[Error] Failed to register peer." + nl
    else
        see "[Peer Registered]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "posts" {
    cResp = httpGet(cBaseUrl + "/p2p/posts")
    if isNull(cResp) or cResp = "" {
        see "[Error] Could not connect to node." + nl
    else
        see "[Node Local Posts]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "txs" {
    cResp = httpGet(cBaseUrl + "/p2p/transactions")
    if isNull(cResp) or cResp = "" {
        see "[Error] Could not connect to node." + nl
    else
        see "[Node Transactions]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "balance" {
    if len(aArgs) < 1 {
        see "[Usage] ring cli.ring " + string(nPort) + " balance <user_id>" + nl
        return
    }
    cUser = aArgs[1]
    cResp = httpGet(cBaseUrl + "/api/balance?user_id=" + cUser)
    if isNull(cResp) or cResp = "" {
        see "[Error] Could not connect to node." + nl
    else
        see "[Balance Result]: " + cResp + nl
    }
    return
}

if cCommand = "refill" {
    if len(aArgs) < 1 {
        see "[Usage] ring cli.ring " + string(nPort) + " refill <user_id> [amount]" + nl
        return
    }
    cUser = aArgs[1]
    nAmount = 50
    if len(aArgs) >= 2 {
        nAmount = number(aArgs[2])
    }
    cBody = '{"user_id":"' + cUser + '","amount":' + string(nAmount) + '}'
    see "[Sending Refill Request to Mother Node for @" + cUser + " (" + string(nAmount) + " WALA)...]" + nl
    cResp = httpPost(cBaseUrl + "/p2p/faucet_request", cBody)
    if isNull(cResp) or cResp = "" {
        see "[Error] Refill failed or node unreachable." + nl
    else
        see "[Refill Response]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "post" {
    if len(aArgs) < 2 {
        see "[Usage] ring cli.ring " + string(nPort) + " post <user_id> <content>" + nl
        return
    }
    cUser = aArgs[1]
    cContent = ""
    for i = 2 to len(aArgs) {
        if i > 2 { cContent += " " }
        cContent += aArgs[i]
    }
    # Escape quotes
    cCleanContent = substr(cContent, '"', '\"')
    cBody = '{"user_id":"' + cUser + '","content":"' + cCleanContent + '"}'
    see "[Publishing post by @" + cUser + "...]" + nl
    cResp = httpPost(cBaseUrl + "/api/post", cBody)
    if isNull(cResp) or cResp = "" {
        see "[Error] Failed to publish post." + nl
    else
        see "[Post Published & Broadcast]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "send" {
    if len(aArgs) < 3 {
        see "[Usage] ring cli.ring " + string(nPort) + " send <sender_id> <receiver_id> <amount>" + nl
        return
    }
    cSender = aArgs[1]
    cReceiver = aArgs[2]
    nAmt = number(aArgs[3])
    cBody = '{"sender_id":"' + cSender + '","receiver_id":"' + cReceiver + '","amount":' + string(nAmt) + '}'
    see "[Transferring " + string(nAmt) + " WALA from @" + cSender + " to @" + cReceiver + "...]" + nl
    cResp = httpPost(cBaseUrl + "/api/send", cBody)
    if isNull(cResp) or cResp = "" {
        see "[Error] Failed to execute transfer." + nl
    else
        see "[Transfer Result]:" + nl
        see cResp + nl
    }
    return
}

if cCommand = "sync" {
    see "[Triggering P2P Sync on node " + cBaseUrl + "...]" + nl
    cResp = httpGet(cBaseUrl + "/api/sync")
    if isNull(cResp) or cResp = "" {
        see "[Error] Failed to trigger sync." + nl
    else
        see "[Sync Result]:" + nl
        see cResp + nl
    }
    return
}

see "[Unknown Command]: " + cCommand + nl
printHelp()

# ----------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------

func printHelp() {
    see "" + nl
    see "Mejde Network CLI Tool Commands:" + nl
    see "  ring cli.ring [port] status                  Get node status" + nl
    see "  ring cli.ring [port] refill <user> [amount]  Refill WALA from Mother node" + nl
    see "  ring cli.ring [port] balance <user>          Check user balance" + nl
    see "  ring cli.ring [port] post <user> <content>   Publish new post" + nl
    see "  ring cli.ring [port] send <from> <to> <amt>  Send WALA tokens" + nl
    see "  ring cli.ring [port] sync                    Trigger P2P sync" + nl
    see "  ring cli.ring [port] posts                   List posts on node" + nl
    see "  ring cli.ring [port] txs                     List transactions on node" + nl
    see "  ring cli.ring [port] peers                   List peer nodes" + nl
    see "" + nl
}

func httpGet(cUrl) {
    try {
        cWork = cUrl
        if substr(cWork, "http://") = 1 {
            cWork = substr(cWork, 8)
        }
        cHost = "127.0.0.1"
        nPort = 8545
        cPath = "/"
        
        nSlash = substr(cWork, "/")
        if nSlash > 0 {
            cHostPort = substr(cWork, 1, nSlash - 1)
            cPath = substr(cWork, nSlash)
        else
            cHostPort = cWork
        }
        
        nColon = substr(cHostPort, ":")
        if nColon > 0 {
            cHost = substr(cHostPort, 1, nColon - 1)
            nPort = number(substr(cHostPort, nColon + 1))
        else
            cHost = cHostPort
        }
        
        sock = socket(AF_INET, SOCK_STREAM, 0)
        if isNull(sock) { return NULL }
        connect(sock, cHost, nPort)
        cReq = "GET " + cPath + " HTTP/1.1" + nl +
               "Host: " + cHost + ":" + string(nPort) + nl +
               "Connection: close" + nl + nl
        send(sock, cReq)
        cResp = ""
        while true
            cChunk = recv(sock, 16384)
            if isNull(cChunk) or cChunk = "" { exit }
            cResp += cChunk
        end
        close(sock)
        
        nBody = substr(cResp, char(13) + char(10) + char(13) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 4) }
        nBody = substr(cResp, char(10) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 2) }
        return cResp
    catch
        return NULL
    }
}

func httpPost(cUrl, cBody) {
    try {
        cWork = cUrl
        if substr(cWork, "http://") = 1 {
            cWork = substr(cWork, 8)
        }
        cHost = "127.0.0.1"
        nPort = 8545
        cPath = "/"
        
        nSlash = substr(cWork, "/")
        if nSlash > 0 {
            cHostPort = substr(cWork, 1, nSlash - 1)
            cPath = substr(cWork, nSlash)
        else
            cHostPort = cWork
        }
        
        nColon = substr(cHostPort, ":")
        if nColon > 0 {
            cHost = substr(cHostPort, 1, nColon - 1)
            nPort = number(substr(cHostPort, nColon + 1))
        else
            cHost = cHostPort
        }
        
        sock = socket(AF_INET, SOCK_STREAM, 0)
        if isNull(sock) { return NULL }
        connect(sock, cHost, nPort)
        cReq = "POST " + cPath + " HTTP/1.1" + nl +
               "Host: " + cHost + ":" + string(nPort) + nl +
               "Content-Type: application/json" + nl +
               "Content-Length: " + string(len(cBody)) + nl +
               "Connection: close" + nl + nl +
               cBody
        send(sock, cReq)
        cResp = ""
        while true
            cChunk = recv(sock, 16384)
            if isNull(cChunk) or cChunk = "" { exit }
            cResp += cChunk
        end
        close(sock)
        
        nBody = substr(cResp, char(13) + char(10) + char(13) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 4) }
        nBody = substr(cResp, char(10) + char(10))
        if nBody > 0 { return substr(cResp, nBody + 2) }
        return cResp
    catch
        return NULL
    }
}
