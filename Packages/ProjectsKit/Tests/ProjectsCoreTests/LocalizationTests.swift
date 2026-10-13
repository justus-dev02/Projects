import Foundation
import Testing
@testable import ProjectsCore

/// Resolves strings through the German resources of the module, independent of the language of
/// the machine running the tests.
@Suite("Localization")
struct LocalizationTests {
    private func bundle(_ language: String) throws -> Bundle {
        let resources = try #require(Bundle.module.resourceURL)
        let url = resources.appending(path: "\(language).lproj", directoryHint: .isDirectory)
        return try #require(Bundle(url: url), "\(language).lproj missing in \(resources.path())")
    }

    @Test func germanStatusNames() throws {
        let german = try bundle("de")
        #expect(german.localizedString(forKey: "To Do", value: nil, table: nil) == "Offen")
        #expect(german.localizedString(forKey: "Urgent", value: nil, table: nil) == "Dringend")
    }

    @Test("German plural rules", arguments: [(1, "Jede Woche"), (2, "Alle 2 Wochen"), (12, "Alle 12 Wochen")])
    func germanPlurals(count: Int, expected: String) throws {
        let format = try bundle("de").localizedString(forKey: "Every %lld weeks", value: nil, table: nil)
        #expect(String.localizedStringWithFormat(format, count) == expected)
    }

    @Test("English plural rules", arguments: [(1, "Every week"), (3, "Every 3 weeks")])
    func englishPlurals(count: Int, expected: String) throws {
        let format = try bundle("en").localizedString(forKey: "Every %lld weeks", value: nil, table: nil)
        #expect(String.localizedStringWithFormat(format, count) == expected)
    }

    @Test func germanErrorMessagesKeepArgumentOrder() throws {
        let format = try bundle("de").localizedString(forKey: "%@ must not be longer than %lld characters.", value: nil, table: nil)
        #expect(String(format: format, "Projektname", 120) == "Projektname darf höchstens 120 Zeichen lang sein.")
    }
}
