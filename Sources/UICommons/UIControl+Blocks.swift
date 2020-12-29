#if os(iOS)
import UIKit

extension UIControl.Event {
    public static let tap: UIControl.Event = .touchUpInside
    ///
    public static let textChange: UIControl.Event = .editingChanged
    public static let textReturn: UIControl.Event = .editingDidEndOnExit
    public static let textEditingEnded: UIControl.Event = [.editingDidEnd, .editingDidEndOnExit]
}

extension ControlBuilderProtocol where Self: UIControl {
    public var on: ControlBuilder<Self> { .init(control: self) }
}
extension ControlBuilderProtocol where Self: UITextField {
    public var on: ControlBuilder<Self> { .init(control: self) }
}

public struct ControlBuilder<C: UIControl> {
    public let control: C

    fileprivate func callAsFunction(_ pointer: Pointer) {
        control.pointers.append(pointer)
    }

    public func callAsFunction(_ event: UIControl.Event, do action: @escaping Block) {
        let pointer = Pointer(ctrl: control, event: event, action: action)
        self(pointer)
    }

    public func callAsFunction(_ event: UIControl.Event, do action: @escaping (C) -> Void) {
        self(event, with: control, do: action)
    }


    public func callAsFunction(_ event: UIControl.Event, do action: @escaping (C, UIControl.Event) -> Void) {
        let pointer = Pointer(ctrl: control, event: event) { ctrl, event in
            action(ctrl as! C, event)
        }
        self(pointer)
    }

    public func callAsFunction<T: NSObject>(
        _ event: UIControl.Event,
        with target: T,
        do action: @escaping (T) -> Void) {
        self(event) { [weak target] in
            guard let target = target else {
                Log.warn("button handler deallocated")
                return
            }
            action(target)
        }
    }

    public func callAsFunction<T: NSObject>(
        _ event: UIControl.Event,
        with target: T,
        do action: @escaping (T, C) -> Void) {
        self(event) { [weak target] in
            guard let target = target else {
                Log.warn("button handler deallocated")
                return
            }
            action(target, self.control)
        }
    }

    public func callAsFunction<T: NSObject>(
        _ event: UIControl.Event,
        with target: T,
        do action: @escaping (T, C, UIControl.Event) -> Void) {
        self(event) { [weak target] in
            guard let target = target else {
                Log.warn("button handler deallocated")
                return
            }
            action(target, self.control, event)
        }
    }
}


/// Internal
public protocol ControlBuilderProtocol {}
extension UIControl: ControlBuilderProtocol {}

extension UIControl {
    fileprivate var pointers: [Pointer] {
        get {
            var _loaded = self._pointers
            _loaded.flush(whereNil: \.ctrl)
            self._pointers = _loaded
            return _loaded
        }
        set {
            var newValue = newValue
            newValue.flush(whereNil: \.ctrl)
            self._pointers = newValue
        }
    }

    private static var _unsafe_controlHandlersKey = "_unsafe_controlHandlersKey"
    private var _pointers: [Pointer] {
        get {
            let ob = objc_getAssociatedObject(
                self,
                &Self._unsafe_controlHandlersKey
            ) as? [Pointer]

            return ob ?? []
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self._unsafe_controlHandlersKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }


    public func removeAllActions() {
        pointers = []
    }
}

// MARK: Pointer


/// the issue with using one adaptor is that events
/// are highly inconsistent, meaning if I register a selector for
/// an event, it always fires, but the event it passes is not always the event registered
///
/// for this reason, we create a new action pointer for EVERY observer as is intended
/// by uikit
///
fileprivate final class Pointer {
    weak var ctrl: UIControl?
    var action: (UIControl, UIControl.Event) -> Void
    var event: UIControl.Event

    convenience init(
        ctrl: UIControl,
        event: UIControl.Event,
        action: @escaping Block) {
        self.init(
            ctrl: ctrl,
            event: event,
            action: { _, _ in
                action()
            }
        )
    }

    convenience init(
        ctrl: UIControl,
        event: UIControl.Event,
        action: @escaping (UIControl.Event) -> Void) {
        self.init(
            ctrl: ctrl,
            event: event,
            action: { _, event in
                action(event)
            }
        )
    }

    convenience init(
        ctrl: UIControl,
        event: UIControl.Event,
        action: @escaping (UIControl) -> Void) {
        self.init(
            ctrl: ctrl,
            event: event,
            action: { ctrl, _ in
                action(ctrl)
            }
        )
    }

    init(ctrl: UIControl,
         event: UIControl.Event,
         action: @escaping (UIControl, UIControl.Event) -> Void) {
        self.ctrl = ctrl
        self.action = action
        self.event = event

        ctrl.addTarget(
            self,
            action: #selector(_unsafe_handleEventTriggered),
            for: event
        )
    }

    deinit {
        Log.info("all cleaned up :)")
    }

    @objc fileprivate func _unsafe_handleEventTriggered(
        control: UIControl,
        event: UIControl.Event
    ) {
        action(control, event)
    }
}

// MARK: Debugging

extension UIControl.Event {
    /// mostly for debugging
    public func readableMatchedEvents() -> [String] {
        var all = [String]()
        if self.contains(.touchDown) {
            all.append("touchDown")
        }
        if self.contains(.touchDownRepeat) {
            all.append("touchDownRepeat")
        }
        if self.contains(.touchDragInside) {
            all.append("touchDragInside")
        }
        if self.contains(.touchDragOutside) {
            all.append("touchDragOutside")
        }
        if self.contains(.touchDragEnter) {
            all.append("touchDragEnter")
        }
        if self.contains(.touchDragExit) {
            all.append("touchDragExit")
        }
        if self.contains(.touchUpInside) {
            all.append("touchUpInside")
        }
        if self.contains(.touchUpOutside) {
            all.append("touchUpOutside")
        }
        if self.contains(.touchCancel) {
            all.append("touchCancel")
        }
        if self.contains(.valueChanged) {
            all.append("valueChanged")
        }
        if self.contains(.primaryActionTriggered) {
            all.append("primaryActionTriggered")
        }
        if #available(iOS 14.0, *) {
            if self.contains(.menuActionTriggered) {
                all.append("menuActionTriggered")
            }
        }
        if self.contains(.editingDidBegin) {
            all.append("editingDidBegin")
        }
        if self.contains(.editingChanged) {
            all.append("editingChanged")
        }
        if self.contains(.editingDidEnd) {
            all.append("editingDidEnd")
        }
        if self.contains(.editingDidEndOnExit) {
            all.append("editingDidEndOnExit")
        }
        if self.contains(.allTouchEvents) {
            all.append("allTouchEvents")
        }
        if self.contains(.allEditingEvents) {
            all.append("allEditingEvents")
        }
        if self.contains(.applicationReserved) {
            all.append("applicationReserved")
        }
        if self.contains(.systemReserved) {
            all.append("systemReserved")
        }
        if self.contains(.allEvents) {
            all.append("allEvents")
        }

        return all
    }
}

#endif
