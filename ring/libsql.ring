/* ====================================================================
 * Mejde Network - Universal LibSQL / SQLite Companion Engine
 * Provides the full LibSQL database API backed directly by the embedded
 * SQLite engine. Zero external .so / DLL dependencies on Android!
 * ==================================================================== */

if iswindows()
    try
        loadlib("ring_sqlite.dll")
    catch
    done
ok

class LibSQL

    cPath = ""

    func openFile(cDbPath)
        cPath = cDbPath
        return self

    func openSyncWithConfig(aConfig)
        if aConfig[:db_path] != NULL { cPath = aConfig[:db_path] }
        return self

    func sync()
        return true

    func connect()
        oConn = new LibSQLConnection(cPath)
        return oConn

class LibSQLConnection
    pDb = NULL
    cDbPath = ""

    func init(cPath)
        cDbPath = cPath
        pDb = sqlite_init()
        if not isNull(pDb)
            sqlite_open(pDb, cDbPath)
        ok

    func execute(cSQL)
        if isNull(pDb) { return NULL }
        return sqlite_execute(pDb, cSQL)

    func query(cSQL)
        oRows = new LibSQLRows(self, cSQL, [])
        return oRows

    func prepare(cSQL)
        oStmt = new LibSQLStatement(self, cSQL)
        return oStmt

    func disconnect()
        if not isNull(pDb)
            sqlite_close(pDb)
            pDb = NULL
        ok

    func close()
        disconnect()

class LibSQLStatement
    oConn = NULL
    cSQL = ""
    aParams = []

    func init(conn, sql)
        oConn = conn
        cSQL = sql
        aParams = []

    func bindString(nIdx, cVal)
        setParam(nIdx, string(cVal))

    func bindInt(nIdx, nVal)
        setParam(nIdx, number(nVal))

    func bindFloat(nIdx, nVal)
        setParam(nIdx, number(nVal))

    func setParam(nIdx, val)
        while len(aParams) < nIdx
            add(aParams, "")
        end
        aParams[nIdx] = val

    func execute()
        if isNull(oConn) or isNull(oConn.pDb) { return NULL }
        if len(aParams) > 0
            return sqlite_execute(oConn.pDb, cSQL, aParams)
        else
            return sqlite_execute(oConn.pDb, cSQL)
        ok

    func query()
        oRows = new LibSQLRows(oConn, cSQL, aParams)
        return oRows

    func finalize()
        aParams = []

    func close()
        finalize()

class LibSQLRows
    oConn = NULL
    cSQL = ""
    aParams = []
    aRawData = []

    func init(conn, sql, params)
        oConn = conn
        cSQL = sql
        aParams = params
        fetch()

    func fetch()
        if isNull(oConn) or isNull(oConn.pDb) { return }
        if len(aParams) > 0
            aRawData = sqlite_execute(oConn.pDb, cSQL, aParams)
        else
            aRawData = sqlite_execute(oConn.pDb, cSQL)
        ok

    func fetchAll()
        aResult = []
        if isNull(aRawData) or len(aRawData) = 0 { return aResult }
        for aRow in aRawData
            aRowVals = []
            for aCol in aRow
                if len(aCol) >= 2 { add(aRowVals, aCol[2]) }
            next
            add(aResult, aRowVals)
        next
        return aResult

    func fetchAllAssoc()
        aResult = []
        if isNull(aRawData) or len(aRawData) = 0 { return aResult }
        for aRow in aRawData
            aRowAssoc = []
            for aCol in aRow
                if len(aCol) >= 2
                    cColName = lower(aCol[1])
                    cColVal = aCol[2]
                    if cColVal = "NULL" { cColVal = "" }
                    aRowAssoc[cColName] = cColVal
                ok
            next
            add(aResult, aRowAssoc)
        next
        return aResult

    nRowIdx = 0

    func fetchRow()
        if isNull(aRawData) or len(aRawData) = 0 { return NULL }
        nRowIdx++
        if nRowIdx > len(aRawData) { return NULL }
        aRow = aRawData[nRowIdx]
        aRowVals = []
        for aCol in aRow
            if len(aCol) >= 2 { add(aRowVals, aCol[2]) }
        next
        return new LibSQLRow(aRowVals)

class LibSQLRow
    aValues = []

    func init(aVals)
        aValues = aVals

    func getValue(nCol)
        if nCol <= len(aValues) { return aValues[nCol] }
        return ""

    func toList()
        return aValues
