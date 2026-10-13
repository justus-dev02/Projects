import Testing
@testable import ProjectsDesignSystem

@Suite("HexColor")
struct HexColorTests {
    @Test func parsesAllSupportedFormats() throws {
        let short = try #require(HexColor("#F00"))
        #expect(short.red == 1 && short.green == 0 && short.blue == 0 && short.alpha == 1)

        let long = try #require(HexColor("5B5BD6"))
        #expect(abs(long.red - 91.0 / 255) < 0.0001)

        let withAlpha = try #require(HexColor("#00000080"))
        #expect(abs(withAlpha.alpha - 128.0 / 255) < 0.0001)
    }

    @Test(arguments: ["", "#", "#12", "#12345", "#GGGGGG", "red", "#1234567890"])
    func rejectsMalformedInput(input: String) {
        #expect(HexColor(input) == nil)
    }

    @Test func chooesReadableForeground() throws {
        #expect(try #require(HexColor("#000000")).prefersLightForeground)
        #expect(try #require(HexColor("#5B5BD6")).prefersLightForeground)
        #expect(try !#require(HexColor("#FFFFFF")).prefersLightForeground)
        #expect(try !#require(HexColor("#FFB800")).prefersLightForeground, "Yellow needs dark text")
    }

    @Test func luminanceBounds() throws {
        #expect(try #require(HexColor("#000")).luminance == 0)
        #expect(abs(try #require(HexColor("#FFF")).luminance - 1) < 0.0001)
    }
}
