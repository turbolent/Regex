import XCTest
import Regex

final class RegexTests: XCTestCase {
    
    func testAtom() {
        XCTAssertEqual(
            Instruction.atom("a", .accept(1))
                .match(["a"]),
            1
        )

        let pattern = Instruction.atom("a", .atom("b", .accept(1)))

        XCTAssertEqual(
            pattern.match(["a", "b"]),
            1
        )

        XCTAssertEqual(
            pattern.match(["a"]),
            nil
        )

        XCTAssertEqual(
            pattern.match(["a", "b", "c"]),
            1
        )
    }

    func testSplit() {
        let pattern =
            Instruction.atom("a", .split([
                .atom("b", .accept(1)),
                .atom("c", .accept(2))
            ]))

        XCTAssertEqual(
            pattern.match(["a"]),
            nil
        )

        XCTAssertEqual(
            pattern.match(["a", "b"]),
            1
        )

        XCTAssertEqual(
            pattern.match(["a", "c"]),
            2
        )
    }

    func testAtEnd() {
        XCTAssertEqual(
            Instruction.atom("a", .atom("b", .atEnd(.accept(1))))
                .match(["a", "b", "c"]),
            nil
        )

        XCTAssertEqual(
            Instruction.atom("a", .atom("b", .atom("c", .atEnd(.accept(1)))))
                .match(["a", "b", "c"]),
            1
        )
    }

    func testLookup() {
        let pattern = Instruction.atom("a",
              .lookup(
                [
                    "B": [.skip(.atom("c", .atEnd(.accept(1))))],
                    "X": [.skip(.atom("y", .accept(2)))]
                ],
                key: { $0.uppercased() }
            )
        )

        XCTAssertEqual(
            pattern.match(["a"]),
            nil
        )

        XCTAssertEqual(
            pattern.match(["a", "b", "c"]),
            1
        )

        XCTAssertEqual(
            pattern.match(["a", "x", "y"]),
            2
        )
    }
}
