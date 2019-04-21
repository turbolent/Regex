public protocol Keyer {
    associatedtype Value

    func key(for value: Value) -> AnyHashable
}


public struct AnyHashableKeyer<T>: Keyer where T: Hashable {

    public func key(for value: T) -> AnyHashable {
        return AnyHashable(value)
    }
}
