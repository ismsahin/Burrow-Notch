import Foundation
import SQLite3

struct NotificationEntry: Identifiable, Equatable {
    let id: Int64
    let appID: String
    let title: String
    let subtitle: String
    let body: String
    let date: Date
}

/// macOS Bildirim Merkezi veritabanını **salt okunur** okur.
///
/// Konum: `~/Library/Group Containers/group.com.apple.usernoted/db2/db` (macOS 15).
/// Bu dosya Tam Disk Erişimi olmadan açılamaz. Yazma yapılmaz, bağlantı her sorguda açılıp kapatılır
/// (usernoted'un WAL kilidine takılmamak için).
enum NotificationReader {
    static var databaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
    }

    enum ReadError: Error, Equatable {
        case noAccess
        case missing
        case query(String)
    }

    /// Tam Disk Erişimi var mı? (Dosyayı okumaya çalışarak anlarız; başka yolu yok.)
    static func hasAccess(at url: URL = databaseURL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path) && (try? FileHandle(forReadingFrom: url).close()) != nil
    }

    /// `afterID`'den sonraki kayıtlar (eskiden yeniye). `afterID == nil` ise yalnızca en son kimliği döndürür.
    static let pageSize = 50

    static func read(after afterID: Int64?, at url: URL = databaseURL, limit: Int = pageSize) -> Result<(entries: [NotificationEntry], lastID: Int64), ReadError> {
        guard FileManager.default.fileExists(atPath: url.path) else { return .failure(.missing) }
        var db: OpaquePointer?
        let uri = "file:\(url.path)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return .failure(.noAccess)
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 300)

        guard let afterID else {
            return scalar(db, "SELECT IFNULL(MAX(rec_id), 0) FROM record").map { (entries: [], lastID: $0) }
        }

        let sql = """
        SELECT r.rec_id, a.identifier, r.data, r.delivered_date
        FROM record r JOIN app a ON a.app_id = r.app_id
        WHERE r.rec_id > ? ORDER BY r.rec_id ASC LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return .failure(.query(String(cString: sqlite3_errmsg(db))))
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, afterID)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var entries: [NotificationEntry] = []
        var lastID = afterID
        while sqlite3_step(statement) == SQLITE_ROW {
            let recID = sqlite3_column_int64(statement, 0)
            lastID = max(lastID, recID)
            let app = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            var blob = Data()
            if let bytes = sqlite3_column_blob(statement, 2) {
                blob = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 2)))
            }
            let delivered = sqlite3_column_double(statement, 3)
            if let entry = NotificationRecordParser.parse(id: recID, appID: app, data: blob, deliveredDate: delivered) {
                entries.append(entry)
            }
        }
        return .success((entries, lastID))
    }

    private static func scalar(_ db: OpaquePointer?, _ sql: String) -> Result<Int64, ReadError> {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return .failure(.query(String(cString: sqlite3_errmsg(db))))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return .success(0) }
        return .success(sqlite3_column_int64(statement, 0))
    }
}

/// Kayıt verisi (ikili plist) ayrıştırıcı. Saf, test edilir.
enum NotificationRecordParser {
    /// Apple'ın referans tarihi (2001) cinsinden `delivered_date`.
    static func parse(id: Int64, appID: String, data: Data, deliveredDate: Double) -> NotificationEntry? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        let request = plist["req"] as? [String: Any] ?? [:]
        let title = (request["titl"] as? String) ?? ""
        let subtitle = (request["subt"] as? String) ?? ""
        let body = (request["body"] as? String) ?? ""
        guard !(title.isEmpty && body.isEmpty) else { return nil }
        let app = (plist["app"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? appID
        let date = deliveredDate > 0 ? Date(timeIntervalSinceReferenceDate: deliveredDate)
            : ((plist["date"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:)) ?? Date())
        return NotificationEntry(id: id, appID: app, title: title.isEmpty ? body : title,
                                 subtitle: subtitle, body: title.isEmpty ? "" : body, date: date)
    }
}
