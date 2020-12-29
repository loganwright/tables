#if canImport(UIKit)

import UIKit
import Commons

/**

 Animation Wrapper

     animation(duration)
         .springDamping(0.95)
         .initialSpringVelocity(1)
         .animations(positionViewsEnd)
         .commit() // must call commit to trigger
 
 */
/// a la swiftui syntax
public func animation(_ duration: TimeInterval? = nil) -> Builder<Animation> {
    return Builder(Animation.init).duration(ifExists: duration)
}


public func animation(_ duration: TimeInterval, animations: @escaping () -> Void) -> Builder<Animation> {
    Builder(Animation.init).duration(duration).animations(animations)
}

public typealias AnimationBuilder = Builder<Animation>

extension AnimationBuilder {
    public func commit() {
        make().commit()
    }

    public func completion(_ detyped: @escaping () -> Void) -> Builder<Model> {
        self.completion { _ in
            detyped()
        }
    }
}

extension Array where Element == AnimationBuilder {
    public enum AnimationStyle {
        /// all run at the same time
        case parallel
        /// sequential on completion, regardless of cancel
        case sequential
    }

    public func commit(style: AnimationStyle = .parallel, completion: (() -> Void)? = nil) {
        commit(style: style, completion: { _ in completion?() })
    }


    public func commit(style: AnimationStyle = .parallel, completion: ((Bool) -> Void)?) {
        switch style {
        case .parallel:
            let group = DispatchGroup()
            var completions: [Bool] = []
            forEach { animation in
                group.enter()
                animation
                    .completion { completions.append($0) }
                    .completion(group.leave)
                    .commit()
            }
            group.onComplete {
                let allSuccess = completions.firstIndex(of: false) == nil
                completion?(allSuccess)
            }
        case .sequential:
            var consumable = self
            let next = consumable.removeFirst()
            next.completion { success in
                if consumable.isEmpty {
                    completion?(success)
                } else {
                    consumable.commit(style: style, completion: completion)
                }
            } .commit()
        }
    }
}

/// concats blocks together so they aggregate and run sequentially
@propertyWrapper
public final class ResponderChain {
    private var chain: [() -> Void] = []
    public var wrappedValue: () -> Void {
        get {
            return chain.reduce({}) { previous, next in
                return {
                    previous()
                    next()
                }
            }
        }
        set {
            chain.append(newValue)
        }
    }

    public init(wrappedValue: @escaping () -> Void) {
        self.wrappedValue = wrappedValue
    }
}

/// same as ResponderChain but w arguments
@propertyWrapper
public final class TypedResponderChain<T> {
    public var wrappedValue: (T) -> Void {
        didSet {
            let newValue = wrappedValue
            wrappedValue = {
                oldValue($0)
                newValue($0)
            }
        }
    }

    public init(wrappedValue: @escaping (T) -> Void) {
        self.wrappedValue = wrappedValue
    }
}

extension TypedResponderChain where T == Int {
    convenience init(wrappedValue: @escaping () -> Void) {
        self.init { _ in
            wrappedValue()
        }
    }
}

public class Animation {
    @ResponderChain
    public var beforeRun: () -> Void = { }
    @ResponderChain
    public var animations: () -> Void = { }
    @TypedResponderChain
    public var completion: (Bool) -> Void = { _ in }

    public var duration: TimeInterval = 0.5
    public var delay: TimeInterval = 0
    public var options: UIView.AnimationOptions = [.allowAnimatedContent, .curveEaseOut]

    public var springDamping: CGFloat = 1
    public var initialSpringVelocity: CGFloat = 0

    public init() {}
}

// MARK: UIView.Animation

extension Animation {
    /// use global animate builder functions
    fileprivate func commit() {
        beforeRun()
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: initialSpringVelocity,
            options: options,
            animations: animations,
            completion: completion
        )
    }
}

// MARK: Breakout
extension DispatchGroup {
    public func onComplete(_ block: @escaping () -> Void) {
        DispatchQueue.global().async {
            self.wait()
            DispatchQueue.main.async(execute: block)
        }
    }
}
#endif
