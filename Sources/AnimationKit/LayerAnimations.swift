#if canImport(UIKit)

import Foundation
import UIKit
import Commons

/**

 for layer animations that don't work with standard UIView.animate

     layerAnimation(duration)
         .keyPath(\.shadowOffset)
         .fromValue(vc.logo.layer.shadowOffset)
         .toValue(offset)
         .commit(to: layerToAnimate) // must call
 */
func layerAnimation(_ duration: TimeInterval) -> Builder<CABasicAnimation> {
    Builder(CABasicAnimation.init)
        .duration(duration)
        .isRemovedOnCompletion(false)
        .fillMode(.forwards)
        .curve(.easeOut)
}

func layerAnimation<C: CALayer, T>(_ kp: KeyPath<C, T>) -> Builder<CABasicAnimation> {
    layerAnimation(kp.name)
}

func layerAnimation(_ keyPath: String) -> Builder<CABasicAnimation> {
    layerAnimation(0.3).keyPath(keyPath)
}

typealias LayerAnimation = Builder<CABasicAnimation>

/// animation delegates are weird
/// you can't compare animations because they're making copies
/// it has a strong reference
/// but somehow still manages its own memory, so set this delegate and you're fine
class LayerAnimationDelegate: NSObject, CAAnimationDelegate {
    enum Event {
        case start, finish(Bool)
    }

    @TypedResponderChain
    private var responders: (Event) -> Void = { event in
    }

    init(_ responder: @escaping (Event) -> Void) {
        super.init()
        responders = responder
    }

    func chain(_ responder: @escaping (Event) -> Void) {
        responders = responder
    }

    func animationDidStart(_ anim: CAAnimation) {
        responders(.start)
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        responders(.finish(flag))
    }
}

extension Builder where Model: CABasicAnimation {
    func observeEvents(_ observer: @escaping (LayerAnimationDelegate.Event) -> Void) -> Builder {
        self.delegate(LayerAnimationDelegate(observer))
    }

    func beforeRun(_ run: @escaping () -> Void) -> Builder {
        self.observeEvents({ event in
            switch event {
            case .start:
                run()
            case .finish(_):
                break
            }
        })
    }

    func completion(_ run: @escaping (Bool) -> Void) -> Builder {
        self.observeEvents({ event in
            switch event {
            case .start:
                break
            case .finish(let flag):
                run(flag)
            }
        })
    }

    func completion(_ detyped: @escaping () -> Void) -> Builder {
        self.completion({ _ in
            detyped()
        })
    }

    func keyPath<T>(_ kp: KeyPath<CALayer, T>) -> Builder {
        keyPath(kp.name)
    }

    func curve(_ name: CAMediaTimingFunctionName) -> Builder {
        self.timingFunction(.init(name: name))
    }

    func commit(to layer: CALayer) {
        let animation = self.make()
        guard let keyPath = animation.keyPath else { fatalError() }
        layer.removeAnimation(forKey:keyPath)
        layer.add(animation, forKey: keyPath)
    }
}

extension KeyPath where Root: NSObject {
    var name: String {
        NSExpression(forKeyPath: self).keyPath
    }
}
#endif
