import XCTest
import Regex

final class RegexTests: XCTestCase {

    func testAtom() {
        XCTAssertEqual(
            HashableInstruction.atom("a", .accept(1))
                .match(["a"]),
            [MatchResult(result: 1, length: 1)]
        )

        let pattern = HashableInstruction.atom("a", .atom("b", .accept(1)))

        XCTAssertEqual(
            pattern.match(["a", "b"]),
            [MatchResult(result: 1, length: 2)]
        )

        XCTAssertEqual(
            pattern.match(["a"]),
            []
        )

        XCTAssertEqual(
            pattern.match(["a", "b", "c"]),
            [MatchResult(result: 1, length: 2)]
        )
    }

    func testSplit() {
        let pattern =
            HashableInstruction.atom("a", .split([
                .atom("b", .accept(1)),
                .atom("c", .accept(2))
            ]))

        XCTAssertEqual(
            pattern.match(["a"]),
            []
        )

        XCTAssertEqual(
            pattern.match(["a", "b"]),
            [MatchResult(result: 1, length: 2)]
        )

        XCTAssertEqual(
            pattern.match(["a", "c"]),
            [MatchResult(result: 2, length: 2)]
        )
    }

    func testAtEnd() {
        XCTAssertEqual(
            HashableInstruction.atom("a", .atom("b", .atEnd(.accept(1))))
                .match(["a", "b", "c"]),
            []
        )

        XCTAssertEqual(
            HashableInstruction.atom("a", .atom("b", .atom("c", .atEnd(.accept(1)))))
                .match(["a", "b", "c"]),
            [MatchResult(result: 1, length: 3)]
        )
    }

    func testLookup() {
        let pattern = HashableInstruction.atom("a",
              .lookup(
                [
                    "b": .skip(.atom("c", .atEnd(.accept(1)))),
                    "x": .skip(.atom("y", .accept(2)))
                ]
            )
        )

        XCTAssertEqual(
            pattern.match(["a"]),
            []
        )

        XCTAssertEqual(
            pattern.match(["a", "b", "c"]),
            [MatchResult(result: 1, length: 3)]
        )

        XCTAssertEqual(
            pattern.match(["a", "x", "y"]),
            [MatchResult(result: 2, length: 3)]
        )
    }

    func testMultipleResults() {
        let pattern = HashableInstruction.split([
            .atom("a", .accept(1)),
            .atom("a", .accept(2)),
            .atom("a", .atom("b", .accept(3))),
            .split([
                .atom("a", .accept(4)),
                .atom("a", .accept(5))
            ])
        ])

        // NOTE: greedy by default
        XCTAssertEqual(
            Set(pattern.match(["a", "b"])),
            Set([
                MatchResult(result: 1, length: 1),
                MatchResult(result: 2, length: 1),
                MatchResult(result: 3, length: 2),
                MatchResult(result: 4, length: 1),
                MatchResult(result: 5, length: 1),
            ])
        )

        XCTAssertEqual(
            Set(pattern.match(["a", "b"], greedy: false)),
            Set([
                MatchResult(result: 1, length: 1),
                MatchResult(result: 2, length: 1),
                MatchResult(result: 4, length: 1),
                MatchResult(result: 5, length: 1),
            ])
        )
    }
}
