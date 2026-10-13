import Foundation

/// Writes RFC 4180 compliant CSV.
public struct CSVWriter: Sendable {
    public let header: [String]
    private var rows: [[String]] = []

    public init(header: [String]) {
        self.header = header
    }

    public mutating func append(_ row: [String]) {
        precondition(row.count == header.count, "CSV row has \(row.count) fields, header has \(header.count)")
        rows.append(row)
    }

    /// Quotes a field when it contains a delimiter, quote or line break and doubles inner quotes.
    public static func escape(_ field: String) -> String {
        let needsQuoting = field.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" || $0 == ";" }
        guard needsQuoting else { return field }
        return "\"" + field.replacing("\"", with: "\"\"") + "\""
    }

    /// The CSV document with CRLF line endings and a UTF-8 byte order mark, so that Excel
    /// (including the German version) detects the encoding correctly.
    public func makeData() -> Data {
        let lines = ([header] + rows).map { $0.map(Self.escape).joined(separator: ",") }
        let text = lines.joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }
}
