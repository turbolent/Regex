
import ParserDescription
import Foundation


public struct UnsupportedPatternError: Error {
    public let pattern: _Pattern
}


extension UnsupportedPatternError: LocalizedError {
    public var errorDescription: String? {
        return "Unsupported pattern: \(pattern)"
    }
}


public extension _Pattern {

    func compile<Token, Result>(result: Result, checkEnd: Bool = false)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
    {
        var next: Instruction<Token, Result> = .accept(result)
        if checkEnd {
            next = .atEnd(next)
        }
        return try compile(next: next)
    }

    // NOTE: no support for CapturePattern yet, RepetitionPattern only with min = 0, max = 1
    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
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

    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
    {
        return try pattern.compile(next: next)
    }
}


public extension SequencePattern {

    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
    {
        return try patterns
            .reversed()
            .reduce(next) { next, pattern in
                try pattern.compile(next: next)
            }
    }
}


public extension OrPattern {

    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
    {
        return .split(
            try patterns.map { pattern in
                try pattern.compile(next: next)
            }
        )
    }
}


public extension RepetitionPattern {

    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
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

    func compile<Token, Result>(next: Instruction<Token, Result>)
        throws -> Instruction<Token, Result>
        where Token: ParserDescription.Token
    {
        guard let condition = condition else {
            return .skip(next)
        }
        let predicate = try condition.compile()
        return Instruction { token in
            guard let token = token, predicate(token) else {
                return .end
            }
            return .resume(.next, [next])
        }
    }
}
