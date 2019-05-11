
import ParserDescription
import Foundation
import OrderedSet


public struct UnsupportedPatternError: Error {
    public let pattern: _Pattern
}


extension UnsupportedPatternError: LocalizedError {
    public var errorDescription: String? {
        return "Unsupported pattern: \(pattern)"
    }
}


public protocol Token {
    func value(forTokenLabel: String) -> String
}


public struct TokenMatcher<T>: Matcher
    where T: Token
{
    public let condition: LabelCondition

    public init(condition: LabelCondition) {
        self.condition = condition
    }

    public func match(value: T) -> Bool {
        let matchedValue = value.value(forTokenLabel: condition.label)
        switch condition.op {
        case .isEqualTo:
            return matchedValue == condition.input
        case .isNotEqualTo:
            return matchedValue != condition.input
        case .hasPrefix:
            return matchedValue.starts(with: condition.input)
        case .matchesRegularExpression:
            fatalError("not implemented yet")
        }
    }
}


extension TokenMatcher: Hashable {}


public struct TokenKeyer<T>: Keyer
    where T: Token
{
    public let tokenLabel: String

    public func key(for token: T) -> String {
        return token.value(forTokenLabel: tokenLabel)
    }
}


extension TokenKeyer: Hashable {}


public typealias TokenInstruction<T, Result> =
    Instruction<T, TokenMatcher<T>, TokenKeyer<T>, Result>
    where T: Token


public extension _Pattern {

    func compile<T, Result>(tokenType: T.Type, result: Result, checkEnd: Bool = false)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        var next: TokenInstruction<T, Result> = .accept(result)
        if checkEnd {
            next = .atEnd(next)
        }
        return try compile(next: next)
    }

    // NOTE: no support for CapturePattern yet, RepetitionPattern only with min = 0, max = 1
    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        switch self {
        case let pattern as SequencePattern:
            return try pattern.compile(next: next)
        case let pattern as OrPattern:
            return try pattern.compile(next: next)
        case let pattern as RepetitionPattern:
            return try pattern.compile(next: next)
        case let pattern as TokenPattern:
            return try pattern.compile(next: next)
        case let pattern as AnyPattern:
            return try pattern.compile(next: next)
        default:
            throw UnsupportedPatternError(pattern: self)
        }
    }
}


public extension AnyPattern {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return try pattern.compile(next: next)
    }
}


public extension SequencePattern {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return try patterns
            .reversed()
            .reduce(next) { next, pattern in
                try pattern.compile(next: next)
            }
    }
}


public extension OrPattern {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return .split(
            try patterns.map { pattern in
                try pattern.compile(next: next)
            }
        )
    }
}


public extension RepetitionPattern {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        let instruction = try pattern.compile(next: next)
        switch (min, max) {
        case (0, 1):
            return .split([
                instruction,
                next
            ])
        default:
            throw UnsupportedPatternError(pattern: self)
        }
    }
}


public extension TokenPattern {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        guard let condition = condition else {
            return .skip(next)
        }
        return try condition.compile(next: .skip(next))
    }
}


public struct UnsupportedConditionError: Error {
    public let condition: _Condition
}


public extension _Condition {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        switch self {
        case let condition as AndCondition:
            return try condition.compile(next: next)
        case let condition as OrCondition:
            return try condition.compile(next: next)
        case let condition as LabelCondition:
            return try condition.compile(next: next)
        case let condition as AnyCondition:
            return try condition.compile(next: next)
        default:
            throw UnsupportedConditionError(condition: self)
        }
    }
}


public extension AnyCondition {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return try condition.compile(next: next)
    }
}


public extension AndCondition {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return try conditions
            .reversed()
            .reduce(next) { next, condition in
                try condition.compile(next: next)
        }
    }
}


public extension OrCondition {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return .split(
            try conditions.map { condition in
                try condition.compile(next: next)
            }
        )
    }
}


public extension LabelCondition {

    func compile<T, Result>(next: TokenInstruction<T, Result>)
        throws -> TokenInstruction<T, Result>
        where T: Token
    {
        return .match(TokenMatcher(condition: self), next)
    }
}


struct TokenEqualityMatch<T, Result> where T: Token {
    let label: String
    let value: String
    let next: TokenInstruction<T, Result>
}


extension TokenEqualityMatch: Equatable
    where Result: Equatable {}


extension TokenEqualityMatch: Hashable
    where Result: Hashable {}


struct TokenMatch<T, Result>
    where T: Token
{
    let matcher: TokenMatcher<T>
    let next: TokenInstruction<T, Result>
}

extension TokenMatch: Equatable
    where Result: Equatable {}


extension TokenMatch: Hashable
    where Result: Hashable {}



func flattenSplits<S, T, Result>(_ instructions: S) -> [TokenInstruction<T, Result>]
    where S: Sequence,
        S.Element == TokenInstruction<T, Result>,
        T: Token
{
    var result: [TokenInstruction<T, Result>] = []
    for instruction in instructions {
        if case let .split(nestedInstructions) = instruction {
            result.append(contentsOf: flattenSplits(nestedInstructions))
        } else {
            result.append(instruction)
        }
    }
    return result
}


public func compile<S, T, Result>(instructions: S)
    -> TokenInstruction<T, Result>
    where S: Sequence,
        S.Element == TokenInstruction<T, Result>,
        T: Token,
        Result: Hashable
{
    var newInstructions: [TokenInstruction<T, Result>] = []
    var equalityMatches: OrderedSet<TokenEqualityMatch<T, Result>> = []
    var otherMatches: OrderedSet<TokenMatch<T, Result>> = []
    var skipNextInstructions: OrderedSet<TokenInstruction<T, Result>> = []
    var atEndNextInstructions: OrderedSet<TokenInstruction<T, Result>> = []

    for instruction in flattenSplits(instructions) {
        switch instruction {
        case .end:
            continue
        case .accept:
            newInstructions.append(instruction)
        case .split:
            fatalError("unreachable: should have been handled by flattenSplits")
        case let .match(matcher, next):
            if case .isEqualTo = matcher.condition.op {
                let equalityMatch = TokenEqualityMatch(
                    label: matcher.condition.label,
                    value: matcher.condition.input,
                    next: next
                )
                equalityMatches.insert(equalityMatch)
            } else {
                let tokenMatch = TokenMatch(
                    matcher: matcher,
                    next: next
                )
                otherMatches.insert(tokenMatch)
            }
        case let .skip(next):
            skipNextInstructions.insert(next)
        case let .atEnd(next):
            atEndNextInstructions.insert(next)
        case .lookup:
            fatalError("TODO")
        }
    }

    newInstructions.append(contentsOf:
        Dictionary(grouping: equalityMatches) { $0.label }
            .map { entry -> TokenInstruction<T, Result> in
                let (label, equalityMatches) = entry
                let table =
                    Dictionary(
                        equalityMatches.map {
                            (
                                // key: matched value
                                $0.value,
                                // value: next instructions (initially one, merged)
                                [$0.next]
                            )
                        },
                        // merge instructions
                        uniquingKeysWith: { $0 + $1 }
                    )
                    // recursively compile next instructions
                    .mapValues {
                        compile(instructions: $0)
                    }

                return TokenInstruction.lookup(
                    TokenKeyer(tokenLabel: label),
                    table
                )
            }
    )

    for match in otherMatches {
        newInstructions.append(
            .match(match.matcher, compile(instructions: [match.next]))
        )
    }

    if !skipNextInstructions.isEmpty {
        newInstructions.append(
            .skip(compile(instructions: skipNextInstructions))
        )
    }

    if !atEndNextInstructions.isEmpty {
        newInstructions.append(
            .atEnd(compile(instructions: atEndNextInstructions))
        )
    }

    return Instruction(instructions: newInstructions)
}
