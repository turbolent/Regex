import Foundation


/// Matches a pattern, compiled into instructions, against a sequence of values.
///
/// An implementation of Thompson's Virtual Machine-based regular expression engine, as described
/// in great detail by Russ Cox in "Regular Expression Matching: the Virtual Machine Approach"
/// (see http://swtch.com/~rsc/regexp/regexp2.html), generalized to arbitrary instructions,
/// based on simple effects
///
public final class Instruction<Value, Result> {

    public enum Location {
        case next
        case current
    }

    public enum Effect {
        case resume(Location, [Instruction])
        case result(Result)
        case end
    }

    public let evaluate: (Value?) -> Effect

    public init(evaluate: @escaping (Value?) -> Effect) {
        self.evaluate = evaluate
    }

    public func match<S: Sequence>(_ values: S) -> Result? where S.Element == Value {

        var currentThreads: [Instruction] = []
        var newThreads: [Instruction] = []

        currentThreads.append(self)

        // NOTE: can't use for-loop, as last iteration needs to be value == nil
        var valueIterator = values.makeIterator()
        var nextValue = valueIterator.next()

        while !currentThreads.isEmpty {

            let value = nextValue
            nextValue = valueIterator.next()

            // NOTE: can't use for-loop, as additions to currentThreads in body should be observed
            var threadIndex = 0
            while threadIndex < currentThreads.count {
                defer { threadIndex += 1 }
                let instruction = currentThreads[threadIndex]

                switch instruction.evaluate(value) {
                case let .resume(.next, instructions):
                    newThreads.append(contentsOf: instructions)
                case let .resume(.current, instructions):
                    currentThreads.append(contentsOf: instructions)
                case let .result(result):
                    return result
                case .end:
                    break
                }
            }

            if value == nil {
                return nil
            }

            swap(&currentThreads, &newThreads)
            newThreads.removeAll()
        }

        return nil
    }
}


public extension Instruction {

    static func accept(_ result: Result) -> Instruction {
        return Instruction { _
            in .result(result)
        }
    }

    static func split(_ instructions: [Instruction]) -> Instruction {
        return Instruction { _ in
            .resume(.current, instructions)
        }
    }

    static func atEnd(_ next: Instruction) -> Instruction {
        return Instruction { value in
            guard value == nil else {
                return .end
            }
            return .resume(.current, [next])
        }
    }

    static func skip(_ next: Instruction) -> Instruction {
        return Instruction { value in
            return .resume(.next, [next])
        }
    }
}


public extension Instruction where Value: Equatable {

    static func atom(_ expected: Value, _ next: Instruction) -> Instruction {
        return Instruction { value in
            guard value == expected else {
                return .end
            }
            return .resume(.next, [next])
        }
    }
}


public  extension Instruction where Value: Hashable {

    static func lookup<Key>(
        _ table: [Key: [Instruction]],
        key: @escaping (Value) -> Key
    ) -> Instruction {
        return Instruction { value in
            guard
                let value = value,
                let instructions = table[key(value)]
            else {
                return .end
            }
            return .resume(.current, instructions)
        }
    }
}
