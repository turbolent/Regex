import Foundation


/// Matches a pattern, compiled into instructions, against a sequence of values.
///
/// An implementation of Thompson's Virtual Machine-based regular expression engine, as described
/// in great detail by Russ Cox in "Regular Expression Matching: the Virtual Machine Approach"
/// (see http://swtch.com/~rsc/regexp/regexp2.html), generalized to arbitrary instructions,
/// based on simple effects
///
public indirect enum Instruction<Value, Matcher, Keyer, Result>
    where Matcher: Regex.Matcher, Matcher.Value == Value,
        Keyer: Regex.Keyer, Keyer.Value == Value
{
    case end
    case accept(Result)
    case split([Instruction])
    case match(Matcher, Instruction)
    case skip(Instruction)
    case atEnd(Instruction)
    case lookup(Keyer, [Keyer.Key: Instruction])

    public enum Location {
        case next
        case current
    }

    public enum Effect {
        case resume(Location, [Instruction])
        case result(Result)
        case end
    }

    public init(instructions: [Instruction]) {
        if instructions.isEmpty {
            self = .end
            return
        }

        if let instruction = instructions.first, instructions.count == 1 {
            self = instruction
            return
        }

        self = .split(instructions)
    }

    public func evaluate(value: Value?) -> Effect {
        switch self {
        case .end:
            return .end
        case let .accept(result):
            return .result(result)
        case let .match(matcher, next):
            guard
                let value = value,
                matcher.match(value: value)
            else {
                return .end
            }
            return .resume(.current, [next])
        case let .lookup(keyer, table):
            guard
                let value = value,
                let instruction = table[keyer.key(for: value)]
            else {
                return .end
            }
            return .resume(.current, [instruction])
        case let .split(instructions):
            return .resume(.current, instructions)
        case let .atEnd(next):
            guard value == nil else {
                return .end
            }
            return .resume(.current, [next])
        case let .skip(next):
            return .resume(.next, [next])
        }
    }

    public func match<S: Sequence>(_ values: S) -> [Result]
        where S.Element == Value
    {
        var currentThreads: [Instruction] = []
        var newThreads: [Instruction] = []

        currentThreads.append(self)

        // NOTE: can't use for-loop, as last iteration needs to be value == nil
        var valueIterator = values.makeIterator()
        var nextValue = valueIterator.next()

        while !currentThreads.isEmpty {

            let value = nextValue
            nextValue = valueIterator.next()

            var results: [Result] = []

            // NOTE: can't use for-loop, as additions to currentThreads in body should be observed
            var threadIndex = 0
            while threadIndex < currentThreads.count {
                defer { threadIndex += 1 }
                let instruction = currentThreads[threadIndex]

                switch instruction.evaluate(value: value) {
                case let .resume(.next, instructions):
                    newThreads.append(contentsOf: instructions)
                case let .resume(.current, instructions):
                    currentThreads.append(contentsOf: instructions)
                case let .result(result):
                    results.append(result)
                case .end:
                    break
                }
            }

            if !results.isEmpty {
                return results
            }

            if value == nil {
                return []
            }

            swap(&currentThreads, &newThreads)
            newThreads.removeAll()
        }

        return []
    }
}




extension Instruction: Equatable
    where Matcher: Equatable,
        Keyer: Equatable,
        Result: Equatable {}


extension Instruction: Hashable
    where Matcher: Hashable,
        Keyer: Hashable,
        Result: Hashable {}


public extension Instruction
    where Value: Equatable,
    Matcher == EquatableMatcher<Value>
{
    static func atom(_ expected: Value, _ next: Instruction) -> Instruction {
        return .match(EquatableMatcher(expected: expected), .skip(next))
    }
}


public extension Instruction
    where Keyer == HashableKeyer<Value>
{
    static func lookup(_ table: [Keyer.Value: Instruction]) -> Instruction {
        return .lookup(HashableKeyer(), table)
    }
}


public extension Instruction
    where Keyer == AnyHashableKeyer<Value>
{
    static func lookup(_ table: [AnyHashable: Instruction]) -> Instruction {
        return .lookup(AnyHashableKeyer(), table)
    }
}


public typealias HashableInstruction<Value, Result> =
    Instruction<Value, EquatableMatcher<Value>, HashableKeyer<Value>, Result>
    where Value: Hashable


public typealias AnyHashableInstruction<Value, Result> =
    Instruction<Value, EquatableMatcher<Value>, AnyHashableKeyer<Value>, Result>
    where Value: Hashable
