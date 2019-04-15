
import XCTest
import Regex
import ParserDescription
import ParserDescriptionOperators


extension String: Token {

    public func isTokenLabel(_ label: String, equalTo conditionInput: String) -> Bool {
        return label == "text"
            && self == conditionInput
    }

    public func doesTokenLabel(_ label: String, havePrefix prefix: String) -> Bool {
        return label == "text"
            && self.starts(with: prefix)
    }

    public func isTokenLabel(
        _ label: String,
        matchingRegularExpression: NSRegularExpression
    ) -> Bool {
        return false
    }
}


final class PatternsTests: XCTestCase {
    func testCompilation() throws {
        let fooPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "foo")
        )
        let barPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "bar")
        )
        let bazPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "baz")
        )

        let pattern = fooPattern ~ barPattern.opt() ~ bazPattern

        let instruction: Instruction<String, Bool> =
            try pattern.compile(result: true, checkEnd: true)

        XCTAssertEqual(instruction.match([]), nil)
        XCTAssertEqual(instruction.match(["foo"]), nil)
        XCTAssertEqual(instruction.match(["foo", "baz"]), true)
        XCTAssertEqual(instruction.match(["foo", "bar", "baz"]), true)
        XCTAssertEqual(instruction.match(["foo", "bar", "baz", "x"]), nil)
    }
}
