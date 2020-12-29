///action models are a replacement to functions, by instead making the functions
///first class objects that can be called on themselves
///
///
public protocol ActionModel {
    /// defines a single callable function with no arguments, the arguments should be built ahead of time
    func callAsFunction()
}

extension Builder where Model: ActionModel {
    public var run: ActionModel {
        self.make()
    }
}
