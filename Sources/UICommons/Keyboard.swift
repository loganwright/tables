import UIKit

public final class KeyboardNotifications: NSObject {
    public static func boot() {
        self.shared = KeyboardNotifications()
    }
    /// forcing the fail if boot forgets because otherwise we don't know about the current keyboard
    /// status on first check (if it's already showing)
    public private(set) static var shared: KeyboardNotifications = {
        fatalError("must call '\(Self.self).boot()` on app launch")
    }()

    public private(set) var last: KeyboardUpdate = .init(
        begin: .zero, end: .zero, duration: 0, options: []
    )

    /// garbage collected memory management
    /// be aware of any closures that might be retaining an object longer
    ///
    /// where necessary, call `.remove(listenersFor: )` to force a release
    @ThreadSafe private(set) var listeners: [(ob: Weak<AnyObject>, listener: (KeyboardUpdate) -> Void)]


    public func listen(with ob: AnyObject, _ listener: @escaping (KeyboardUpdate) -> Void) {
        listeners.flush(whereNil: \.ob.value)
        listeners.append((Weak(ob), listener))
    }

    func listen<A: AnyObject>(
        with ob: A,
        _ listener: @escaping (A, KeyboardUpdate
    ) -> Void) {
        listen(with: ob as AnyObject) { [weak ob] message in
            guard let welf = ob else { return }
            listener(welf, message)
        }
    }

    func remove(listenersFor ob: AnyObject) {
        listeners.flush(where: \.ob.value, matches: ob)
    }

    private override init() {
        self.listeners = []
        super.init()
        startObserving()
    }

    private func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )

    }

    @objc private func keyboardWillChange(_ note: Notification) {
        listeners.flush(whereNil: \.ob.value)
        let message = note.keyboardAnimation
        self.last = message
        listeners.pass(each: \.listener, arg: message)
    }
}

protocol EncapsulationProtocol {
    associatedtype Wrapped
    var wrapped: Wrapped? { get }
}
extension Optional: EncapsulationProtocol {
    var wrapped: Wrapped? { self }
}

extension Array where Element: EncapsulationProtocol {
    func flatten() -> [Element.Wrapped] {
        compactMap { $0.wrapped }
    }
}

extension Array {
    func flatten<T>(as t: T.Type) -> [T] {
        compactMap { $0 as? T }
    }
}


extension Sequence {
    var array: [Element] { Array(self) }
}
extension Sequence where Element: Hashable {
    var set: Set<Element> { Set(self)}
}

extension Array {
    mutating func set<T>(each  kp: WritableKeyPath<Element, T>, to new: T) {
        self = self.map { element in
            var element = element
            element[keyPath: kp] = new
            return element
        }
    }

    func set<T>(each kp: ReferenceWritableKeyPath<Element, T>, to new: T) {
        self.forEach { element in
            element[keyPath: kp] = new
        }
    }

    func pass<T>(each kp: KeyPath<Element, (T) -> Void>, arg: T) {
        self.forEach { element in
            // can I just map this?
            let function = element[keyPath: kp]
            function(arg)
        }
    }
}

extension Array {
    mutating func flush<T>(whereNil kp: KeyPath<Element, T?>) {
        self = self.filter { $0[keyPath: kp] != nil }
    }

    mutating func flush(where shouldFlush: (Element) -> Bool) {
        self = self.filter { !shouldFlush($0) }
    }
}

extension Array {
    mutating func flush<T: Equatable>(where kp: KeyPath<Element, T?>, matches: T?) {
        self = self.filter { $0[keyPath: kp] == matches }
    }

    mutating func flush<T: AnyObject>(where kp: KeyPath<Element, T?>, matches: T?) {
        self = self.filter { $0[keyPath: kp] === matches }
    }
}

extension KeyboardNotifications {
    public struct KeyboardUpdate {
        public enum Event {
            case change, appear, disappear
        }

        public let begin: CGRect
        public let end: CGRect
        public let duration: TimeInterval
        public let options: UIView.AnimationOptions

        public var event: Event {
            let startsOnScreen = keyWindow.bounds.contains(begin)
            let endsOnScreen = keyWindow.bounds.contains(end)

            if startsOnScreen && endsOnScreen {
                return .change
            } else if endsOnScreen {
                return .appear
            } else if startsOnScreen {
                return .disappear
            } else {
                Log.warn("undefined keyboard behavior")
                /// would mean keyboard never appears?
                /// maybe impossible
                return .change
            }
        }

        public var syncKeyboard: AnimationBuilder {
            animation(duration).options(options)
        }

        public func endVisibleHeight(in space: UICoordinateSpace) -> CGFloat {
            /// todo: be more aware of sizing in how it fits, for now
            /// I think it's fine
            guard end != .zero else { return 0 }
            return space.bounds.height - keyWindow.convert(end, to: space).minY
        }
    }
}

extension Notification {
    fileprivate var keyboardAnimation: KeyboardNotifications.KeyboardUpdate {
        .init(
            begin: keyboardBegin,
            end: keyboardEnd,
            duration: keyboardAnimationDuration,
            options: keyboardAnimationOptions
        )
    }

    func force<T>(key: AnyHashable, as: T.Type = T.self) -> T {
        return userInfo![key] as! T
    }

    private var keyboardBegin: CGRect! {
        return force(key: UIResponder.keyboardFrameBeginUserInfoKey)
    }

    private var keyboardEnd: CGRect! {
        return force(key: UIResponder.keyboardFrameEndUserInfoKey)
    }

    private var keyboardAnimationDuration: TimeInterval! {
        return force(key: UIResponder.keyboardAnimationDurationUserInfoKey)
    }

    private var keyboardAnimationOptions: UIView.AnimationOptions! {
        let raw = force(key: UIResponder.keyboardAnimationCurveUserInfoKey,
                      as: UInt.self)
        let curve = UIView.AnimationOptions(rawValue: raw << 16)
        return curve
    }
}
