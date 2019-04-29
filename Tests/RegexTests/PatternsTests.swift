
import XCTest
import Regex
import ParserDescription
import ParserDescriptionOperators


extension String: Regex.Token {
    public func value(forTokenLabel label: String) -> String {
        // ignore the label, this is just an example
        return self
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

        let instruction =
            try pattern.compile(result: true, checkEnd: true)

        XCTAssertEqual(instruction.match([]), [])
        XCTAssertEqual(instruction.match(["foo"]), [])
        XCTAssertEqual(instruction.match(["foo", "baz"]), [true])
        XCTAssertEqual(instruction.match(["foo", "bar", "baz"]), [true])
        XCTAssertEqual(instruction.match(["foo", "bar", "baz", "x"]), [])
    }

    func testLookupCompilation() throws {
        let fooPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "foo")
        )
        let barPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "bar")
        )
        let bazPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "baz")
        )
        let quxPattern = TokenPattern(condition:
            LabelCondition(label: "text", op: .isEqualTo, input: "qux")
        )

        let patterns = [
            fooPattern ~ barPattern,
            fooPattern ~ bazPattern,
            barPattern ~ bazPattern,
            fooPattern ~ barPattern ~ bazPattern,
            // NOTE: duplicate of second
            fooPattern ~ bazPattern,
            (fooPattern || barPattern) ~ quxPattern,
            quxPattern ~ bazPattern.opt() ~ barPattern.opt() ~ fooPattern,
            quxPattern ~ bazPattern
        ]

        let instructions =
            try patterns.enumerated().map { entry -> TokenInstruction<Int> in
                let (offset, pattern) = entry
                return try pattern.compile(result: offset, checkEnd: true)
            }

        let instruction = compile(instructions: instructions)

        XCTAssertEqual(instruction.match([]), [])
        XCTAssertEqual(instruction.match(["foo"]), [])
        XCTAssertEqual(instruction.match(["foo", "bar"]), [0])
        // NOTE: multiple results
        XCTAssertEqual(instruction.match(["foo", "baz"]), [1, 4])
        XCTAssertEqual(instruction.match(["foo", "bar", "baz"]), [3])
        XCTAssertEqual(instruction.match(["foo", "bar", "baz", "x"]), [])
        XCTAssertEqual(instruction.match(["foo", "qux"]), [5])
        XCTAssertEqual(instruction.match(["bar", "qux"]), [5])
        XCTAssertEqual(instruction.match(["qux", "foo"]), [6])
        XCTAssertEqual(instruction.match(["qux", "baz", "foo"]), [6])
        XCTAssertEqual(instruction.match(["qux", "baz", "bar", "foo"]), [6])
        XCTAssertEqual(instruction.match(["qux", "baz"]), [7])
    }
}
