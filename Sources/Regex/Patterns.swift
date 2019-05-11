
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


public struct TokenMatcher: Matcher {

    public let condition: LabelCondition

    public init(condition: LabelCondition) {
        self.condition = condition
    }

    public func match(value: Token) -> Bool {
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


public struct TokenKeyer: Keyer {
    public let tokenLabel: String

    public func key(for token: Token) -> String {
        return token.value(forTokenLabel: tokenLabel)
    }
}


extension TokenKeyer: Hashable {}


public typealias TokenInstruction<Result> =
    Instruction<Token, TokenMatcher, TokenKeyer, Result>


public extension _Pattern {

    func compile<Result>(result: Result, checkEnd: Bool = false)
        throws -> TokenInstruction<Result>
    {
        var next: TokenInstruction<Result> = .accept(result)
        if checkEnd {
            next = .atEnd(next)
        }
        return try compile(next: next)
    }

    // NOTE: no support for CapturePattern yet, RepetitionPattern only with min = 0, max = 1
    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
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

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return try pattern.compile(next: next)
    }
}


public extension SequencePattern {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return try patterns
            .reversed()
            .reduce(next) { next, pattern in
                try pattern.compile(next: next)
            }
    }
}


public extension OrPattern {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return .split(
            try patterns.map { pattern in
                try pattern.compile(next: next)
            }
        )
    }
}


public extension RepetitionPattern {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
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

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
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

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
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

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return try condition.compile(next: next)
    }
}


public extension AndCondition {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return try conditions
            .reversed()
            .reduce(next) { next, condition in
                try condition.compile(next: next)
        }
    }
}


public extension OrCondition {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return .split(
            try conditions.map { condition in
                try condition.compile(next: next)
            }
        )
    }
}


public extension LabelCondition {

    func compile<Result>(next: TokenInstruction<Result>)
        throws -> TokenInstruction<Result>
    {
        return .match(TokenMatcher(condition: self), next)
    }
}


struct TokenEqualityMatch<Result> {
    let label: String
    let value: String
    let next: TokenInstruction<Result>
}


extension TokenEqualityMatch: Equatable
    where Result: Equatable {}


extension TokenEqualityMatch: Hashable
    where Result: Hashable {}


struct TokenMatch<Result> {
    let matcher: TokenMatcher
    let next: TokenInstruction<Result>
}

extension TokenMatch: Equatable
    where Result: Equatable {}


extension TokenMatch: Hashable
    where Result: Hashable {}



func flattenSplits<S, Result>(_ instructions: S) -> [TokenInstruction<Result>]
    where S: Sequence,
    S.Element == TokenInstruction<Result>
{
    var result: [TokenInstruction<Result>] = []
    for instruction in instructions {
        if case let .split(nestedInstructions) = instruction {
            result.append(contentsOf: flattenSplits(nestedInstructions))
        } else {
            result.append(instruction)
        }
    }
    return result
}


public func compile<S, Result>(instructions: S)
    -> TokenInstruction<Result>
    where S: Sequence,
        S.Element == TokenInstruction<Result>,
        Result: Hashable
{
    var newInstructions: [TokenInstruction<Result>] = []
    var equalityMatches: OrderedSet<TokenEqualityMatch<Result>> = []
    var otherMatches: OrderedSet<TokenMatch<Result>> = []
    var skipNextInstructions: OrderedSet<TokenInstruction<Result>> = []
    var atEndNextInstructions: OrderedSet<TokenInstruction<Result>> = []

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
            .map { entry -> TokenInstruction<Result> in
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
