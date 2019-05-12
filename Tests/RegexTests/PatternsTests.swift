
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
            try pattern.compile(tokenType: String.self, result: true, checkEnd: true)

        XCTAssertEqual(
            instruction.match([]),
            []
        )

        XCTAssertEqual(
            instruction.match(["foo"]),
            []
        )

        XCTAssertEqual(
            instruction.match(["foo", "baz"]),
            [MatchResult(result: true, length: 2)]
        )

        XCTAssertEqual(
            instruction.match(["foo", "bar", "baz"]),
            [MatchResult(result: true, length: 3)]
        )

        XCTAssertEqual(
            instruction.match(["foo", "bar", "baz", "x"]),
            []
        )
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
            try patterns.enumerated().map { entry -> TokenInstruction<String, Int> in
                let (offset, pattern) = entry
                return try pattern.compile(tokenType: String.self, result: offset, checkEnd: true)
            }

        let instruction = compile(instructions: instructions)

        XCTAssertEqual(instruction.match([]), [])

        XCTAssertEqual(instruction.match(["foo"]), [])

        XCTAssertEqual(
            instruction.match(["foo", "bar"]),
            [MatchResult(result: 0, length: 2)]
        )

        // NOTE: multiple results
        XCTAssertEqual(
            instruction.match(["foo", "baz"]),
            [
                MatchResult(result: 1, length: 2),
                MatchResult(result: 4, length: 2)
            ]
        )

        XCTAssertEqual(
            instruction.match(["foo", "bar", "baz"]),
            [MatchResult(result: 3, length: 3)]
        )

        XCTAssertEqual(instruction.match(["foo", "bar", "baz", "x"]), [])

        XCTAssertEqual(
            instruction.match(["foo", "qux"]),
            [MatchResult(result: 5, length: 2)]
        )

        XCTAssertEqual(
            instruction.match(["bar", "qux"]),
            [MatchResult(result: 5, length: 2)]
        )

        XCTAssertEqual(
            instruction.match(["qux", "foo"]),
            [MatchResult(result: 6, length: 2)]
        )

        XCTAssertEqual(
            instruction.match(["qux", "baz", "foo"]),
            [MatchResult(result: 6, length: 3)]
        )

        XCTAssertEqual(
            instruction.match(["qux", "baz", "bar", "foo"]),
            [MatchResult(result: 6, length: 4)]
        )

        XCTAssertEqual(
            instruction.match(["qux", "baz"]),
            [MatchResult(result: 7, length: 2)]
        )
    }
}
