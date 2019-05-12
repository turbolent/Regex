
public struct MatchResult<Result> {
    public let result: Result
    public let length: Int

    public init(result: Result, length: Int) {
        self.result = result
        self.length = length
    }
}


extension MatchResult: Equatable
    where Result: Equatable {}


extension MatchResult: Hashable
    where Result: Hashable {}
