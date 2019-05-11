public protocol Matcher {
    associatedtype Value
    func match(value: Value) -> Bool
}


public struct EquatableMatcher<T>: Matcher
    where T: Equatable
{
    public let expected: T

    public init(expected: T) {
        self.expected = expected
    }

    public func match(value: T) -> Bool {
        return value == expected
    }
}
