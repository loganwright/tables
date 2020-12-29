import UIKit

/// a basic label class for displaying text with a gradient
@dynamicMemberLookup
public class GradientTextLabel: UIView {
    public let label: UILabel
    public var gradient: GradientOverlay

    /// colors: colors to use in gradient
    /// multiplier: how much larger the gradient should be than the label, a gradient of 1
    init(colors: [UIColor], multiplier: CGFloat = 1) {
        self.label = UILabel()
        self.gradient = .init(colors: colors, widthMultiplier: multiplier)

        super.init(frame: .sizing)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(label)

        insertSubview(gradient, belowSubview: label)
        gradient.layer.mask = label.layer
    }

    /// this view gets mad w the masking to let label do the sizing
    /// if you want default behavior, use a secondary hidden label with layout constraints
    /// and bind the gradient label to that label
    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        label.frame = bounds
    }

    subscript<T>(dynamicMember kp: ReferenceWritableKeyPath<UILabel, T>) -> T {
        get { label[keyPath: kp] }
        set { label[keyPath: kp] = newValue }
    }
}

final class GradientOverlay: UIView {
    enum Direction {
        case left, right, up, down, custom(start: CGPoint, end: CGPoint)

        var gradientPoints: (start: CGPoint, end: CGPoint) {
            var start = CGPoint(x: 0.5, y: 0.5)
            var end = CGPoint(x: 0.5, y: 0.5)
            switch self {
            case .up:
                start.y = 1
                end.y = 0
            case .down:
                start.y = 0
                end.y = 1
            case .left:
                start.x = 1
                end.x = 0
            case .right:
                start.x = 0
                end.x = 1
            case .custom(start: let s, end: let e):
                start = s
                end = e
            }
            return (start, end)
        }
    }

    /// how the gradient should be fixed in cases where
    /// the gradient is larger than the view
    enum Anchor {
        case center, leading, trailing
    }

    let colors: [UIColor]
    /// note: check
    /// this overlay thing is weird, and I think vestigial
    /// don't want to remove now, making note
    let overlay: UIView
    lazy var gradient: CAGradientLayer = Builder(CAGradientLayer.init)
        .colors(colors.map(\.cgColor))
        .type(.axial)
        .startPoint(direction.gradientPoints.start)
        .endPoint(direction.gradientPoints.end)
        .make()

    private(set) var completed: CGFloat = 0.0

    private var sizeMultiplierConstraint: NSLayoutConstraint?
    var widthMultiplier: CGFloat {
        didSet {
            updateSizeMultiplierConstraint()
        }
    }

    private var anchorConstraint: NSLayoutConstraint?
    var anchor: Anchor {
        didSet {
            updateAnchorConstraint()
        }
    }

    var direction: Direction = .right {
        didSet {
            let (start, end) = direction.gradientPoints
            gradient.startPoint = start
            gradient.endPoint = end
        }
    }

    init(colors: [UIColor], anchor: Anchor = .center, widthMultiplier: CGFloat = 1) {
        self.colors = colors
        self.overlay = UIView()
        self.widthMultiplier = widthMultiplier
        self.anchor = anchor
        super.init(frame: .sizing)

        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        overlay.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        addSubview(overlay)
        pin(overlay, to: .height)
        pin(overlay, to: .centerY)
        updateSizeMultiplierConstraint()
        updateAnchorConstraint()

        overlay.layer.addSublayer(gradient)
        gradient.frame = overlay.bounds

        clipsToBounds = true
    }

    private func updateSizeMultiplierConstraint() {
        if let existing = sizeMultiplierConstraint {
            removeConstraint(existing)
        }
        sizeMultiplierConstraint = pin(overlay, .width, to: self, .width, multiplier: widthMultiplier)
    }

    private func updateAnchorConstraint() {
        if let existing = anchorConstraint {
            removeConstraint(existing)
        }

        /// should this just take layout attribute?
        switch anchor {
        case .center:
            anchorConstraint = pin(overlay, to: .centerX)
        case .leading:
            anchorConstraint = pin(overlay, to: .leading)
        case .trailing:
            anchorConstraint = pin(overlay, to: .trailing)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradient()
    }

    func update(completed: CGFloat) {
        assert(0...1.0 ~= completed)
        self.completed = completed
        updateGradient()
        layoutIfNeeded()
    }

    private func updateGradient() {
        gradient.frame = overlay.bounds

        /// add slight motion, slide gradient endpoint vertically, higher number is less movement
        /// this changes the way the gradient is drawn, it doesn't move the view
        let variance = CGFloat(5)
        let offset = completed / variance
        let inset = 0.5 - (offset / 2)
        gradient.endPoint.y = inset + offset

        /// slide gradient accross
        switch anchor {
        case .center:
            break
        case .trailing:
            let max = overlay.frame.width - frame.width
            anchorConstraint?.constant = max - (max * completed)
        case .leading:
            let max = overlay.frame.width - frame.width
            anchorConstraint?.constant = -(max - (max * completed))
        }
    }
}

extension GradientOverlay {
    func animateFillInGradient(duration: TimeInterval = 0.62) {
        layerAnimation(duration)
            .keyPath("locations")
            .fromValue([0, 0.01])
            .toValue([0, 1])
            .commit(to: gradient)
    }
}
extension GradientOverlay {
    func animateLoading(duration: TimeInterval = 2.35, offsetDuration: TimeInterval? = nil) -> Cancel {
        let cancel = Cancel()
        repeateAnimateStartPoint(duration, cancel)
        let b = offsetDuration ?? duration
        repeateAnimateEndPoint(b, cancel)
        return cancel
    }

    private func repeateAnimateStartPoint(_ duration: TimeInterval, _ cancel: Cancel) {
        layerAnimation(duration)
            .curve(.easeIn)
            .keyPath("startPoint")
            .toValue(CGPoint(x: 1, y: 0))
            .autoreverses(true)
            .completion { [weak self] in
                guard !cancel.cancelled else { return }
                self?.repeateAnimateStartPoint(duration, cancel)
            }
            .commit(to: gradient)
    }

    private func repeateAnimateEndPoint(_ duration: TimeInterval, _ cancel: Cancel) {
        layerAnimation(duration)
            .curve(.easeInEaseOut)
            .keyPath("endPoint")
            .toValue(CGPoint(x: 0, y: 1))
            .autoreverses(true)
            .completion { [weak self] in
                guard !cancel.cancelled else { return }
                self?.repeateAnimateEndPoint(duration, cancel)
            }
            .commit(to: gradient)
    }

    private func easeInStartPoint() -> LayerAnimation {
        layerAnimation("startPoint")
            .duration(1.2)
            .curve(.easeIn)
            .fromValue(gradient.startPoint)
            .toValue(CGPoint.zero)
            .autoreverses(false)
    }

    private func easeInEndPoint() -> LayerAnimation {
        layerAnimation("endPoint")
            .duration(1.2)
            .curve(.easeOut)
            .fromValue(gradient.endPoint)
            .toValue(CGPoint.one)
            .autoreverses(false)
    }

    func isAnimatingLoading() -> Bool {
        gradient.animationKeys()?.set.union(["startPoint", "endPoint"]).count == 2
    }
}
