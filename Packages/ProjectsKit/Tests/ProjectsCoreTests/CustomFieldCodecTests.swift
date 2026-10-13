import Foundation
import Testing
@testable import ProjectsCore

@Suite("CustomFieldCodec")
struct CustomFieldCodecTests {
    private func normalize(_ raw: String, _ type: CustomFieldType, options: [String] = [], required: Bool = false) throws -> String {
        try CustomFieldCodec.normalize(raw, type: type, options: options, isRequired: required, fieldName: "Field")
    }

    @Test func emptyValueIsAllowedForOptionalFields() throws {
        #expect(try normalize("   ", .number) == "")
    }

    @Test func emptyValueThrowsForRequiredFields() {
        #expect(throws: ProjectsError.requiredCustomFieldMissing(fieldName: "Field")) {
            try normalize("", .text, required: true)
        }
    }

    @Test("Numbers are stored locale independently")
    func numbers() throws {
        #expect(try normalize(" 1.5 ", .number) == "1.5")
        #expect(try normalize("42", .number) == "42.0")
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("1,5", .number) }
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("inf", .number) }
    }

    @Test func choicesMustBeOneOfTheOptions() throws {
        #expect(try normalize("B", .choice, options: ["A", "B"]) == "B")
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) {
            try normalize("C", .choice, options: ["A", "B"])
        }
    }

    @Test func urlsNeedAWebScheme() throws {
        #expect(try normalize("https://apple.com", .url) == "https://apple.com")
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("javascript:alert(1)", .url) }
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("apple", .url) }
    }

    @Test func datesRoundTrip() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let raw = CustomFieldCodec.encode(date: date)
        #expect(try normalize(raw, .date) == raw)
        #expect(CustomFieldCodec.decodeDate(raw) == date)
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("01.02.2026", .date) }
    }

    @Test func checkboxes() throws {
        #expect(try normalize("true", .checkbox) == "true")
        #expect(CustomFieldCodec.decodeBool(CustomFieldCodec.encode(bool: false)) == false)
        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Field")) { try normalize("yes", .checkbox) }
    }
}
