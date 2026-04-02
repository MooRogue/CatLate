import XCTest
@testable import CatLate

final class CatLateTests: XCTestCase {
    func testDefaultConversationDirectionUsesEnglishToSpanish() {
        let direction = ConversationDirection.default

        XCTAssertEqual(direction.source, .english)
        XCTAssertEqual(direction.target, .spanish)
    }
}
