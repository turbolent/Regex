public protocol Keyer {
    associatedtype Value
    associatedtype Key: Hashable

    func key(for value: Value) -> Key
}


public struct HashableKeyer<T>: Keyer
    where T: Hashable
{
    public func key(for value: T) -> T {
        return value
    }
}


public struct AnyHashableKeyer<T>: Keyer
    where T: Hashable
{
    public func key(for value: T) -> AnyHashable {
        return AnyHashable(value)
    }
}
