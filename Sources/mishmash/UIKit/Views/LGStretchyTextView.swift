#if os(iOS)
import UIKit

// MARK: Container

class StretchyTextViewContainer: UIView, LGStretchyTextViewDelegate {
    private var height: NSLayoutConstraint! = nil
    let textView = LGStretchyTextView()
    private let textViewInsets = UIEdgeInsets(top: 20, left: 28, bottom: 20, right: 28)
    let placeholder = UILabel()

    /// sometimes the patterns aren't clear, when using delegates vs functions like this..
    /// I will try to clarify as I go
    var onUpdates: (LGStretchyTextView) -> Void = { _ in  }
    var onShouldReturn: (LGStretchyTextView) -> Bool = { _ in true }

    func set(maxHeightPortrait: CGFloat) {
        textView.maxHeightPortrait = maxHeightPortrait - (textViewInsets.top + textViewInsets.bottom)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        setupTextView()
        setupPlaceholder()

        layer.cornerRadius = 16
        backgroundColor = "#F3F5F9".uicolor
        update()
    }

    private func setupTextView() {
        textView.stretchyTextViewDelegate = self
        addSubview(textView)
        pin(textView, to: .top, textViewInsets.top)
        pin(textView, to: .left, textViewInsets.left)
        pin(textView, to: .bottom, -textViewInsets.bottom)
        pin(textView, to: .right, -textViewInsets.right)
        height = pin(.height, to: 60)

        textView.returnKeyType = .done
        textView.textContainerInset = .zero
        textView.backgroundColor = .clear

        textView.font = .inter(.regular, size: 20)
    }

    private func setupPlaceholder() {
        textView.addSubview(placeholder)
        placeholder.isUserInteractionEnabled = false
        placeholder.text = "Enter text..."
    }

    // MARK:

    override func layoutSubviews() {
        super.layoutSubviews()
        positionPlaceholder()
    }

    private func positionPlaceholder() {
        let caretRect = textView.caretRect(for: textView.beginningOfDocument)
        var insets = UIEdgeInsets.zero
        insets.left = caretRect.maxX + 2
        placeholder.frame = textView.bounds.inset(by: insets)
    }
    
    private func update() {
        positionPlaceholder()
        placeholder.font = textView.font
        placeholder.textColor = textView.textColor?.withAlphaComponent(0.5)
        placeholder.isHidden = !textView.text.isEmpty

        onUpdates(textView)
    }

    func stretchyTextViewDidChangeSize(_ textView: LGStretchyTextView) {
        let textViewHeight = textView.bounds.height
        let targetConstant = textViewHeight + textViewInsets.top + textViewInsets.bottom
        height.constant = targetConstant
        layoutIfNeeded()
    }

    func stretchyTextViewDidChangeContents(_ textView: LGStretchyTextView) {
        update()
    }

    func stretchyTextViewShouldReturn(_ textView: LGStretchyTextView) -> Bool {
        return onShouldReturn(textView)
    }
}

// MARK: Text View

@objc protocol LGStretchyTextViewDelegate {
    func stretchyTextViewDidChangeSize(_ textView: LGStretchyTextView)
    func stretchyTextViewDidChangeContents(_ textView: LGStretchyTextView)
    @objc optional func stretchyTextViewShouldReturn(_ textView: LGStretchyTextView) -> Bool
}

class LGStretchyTextView : UITextView, UITextViewDelegate {

    // MARK: Delegate

    weak var stretchyTextViewDelegate: LGStretchyTextViewDelegate?

    // MARK: Public Properties

    var maxHeightPortrait: CGFloat = 400
    var maxHeightLandScape: CGFloat = 60
    var maxHeight: CGFloat {
        get {
            return keyWindowScene.interfaceOrientation.isPortrait
                ? maxHeightPortrait
                : maxHeightLandScape
        }
    }

    // MARK: Private Properties

    private var maxSize: CGSize {
        get {
            return CGSize(width: self.bounds.width, height: self.maxHeightPortrait)
        }
    }

    private let sizingTextView = UITextView()

    // MARK: Property Overrides

    override var contentSize: CGSize {
        didSet {
            resize()
        }
    }

    override var font: UIFont! {
        didSet {
            sizingTextView.font = font
        }
    }

    override var textContainerInset: UIEdgeInsets {
        didSet {
            sizingTextView.textContainerInset = textContainerInset
        }
    }

    // MARK: Initializers

    override init(frame: CGRect = .zero, textContainer: NSTextContainer? = nil) {
        super.init(frame: frame, textContainer: textContainer);
        setup()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Setup

    func setup() {
        font = UIFont.systemFont(ofSize: 17.0)
        textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        delegate = self
    }

    // MARK: Sizing

    func resize() {
        bounds.size.height = self.targetHeight()
        layoutIfNeeded()
        stretchyTextViewDelegate?.stretchyTextViewDidChangeSize(self)
    }

    func targetHeight() -> CGFloat {

        /*
        There is an issue when calling `sizeThatFits` on self that results in really weird drawing issues with aligning line breaks ("\n").  For that reason, we have a textView whose job it is to size the textView. It's excess, but apparently necessary.  If there's been an update to the system and this is no longer necessary, or if you find a better solution. Please remove it and submit a pull request as I'd rather not have it.
        */

        sizingTextView.text = self.text
        let targetSize = sizingTextView.sizeThatFits(maxSize)
        let targetHeight = targetSize.height
        let maxHeight = self.maxHeight
        return targetHeight < maxHeight ? targetHeight : maxHeight
    }

    // MARK: Alignment

    func align() {
        guard let end = self.selectedTextRange?.end else { return }
        let caretRect = self.caretRect(for: end)

        let topOfLine = caretRect.minY
        let bottomOfLine = caretRect.maxY

        let contentOffsetTop = self.contentOffset.y
        let bottomOfVisibleTextArea = contentOffsetTop + self.bounds.height

        /*
        If the caretHeight and the inset padding is greater than the total bounds then we are on the first line and aligning will cause bouncing.
        */

        let caretHeightPlusInsets = caretRect.height + self.textContainerInset.top + self.textContainerInset.bottom
        if caretHeightPlusInsets < self.bounds.height {
            var overflow: CGFloat = 0.0
            if topOfLine < contentOffsetTop + self.textContainerInset.top {
                overflow = topOfLine - contentOffsetTop - self.textContainerInset.top
            } else if bottomOfLine > bottomOfVisibleTextArea - self.textContainerInset.bottom {
                overflow = (bottomOfLine - bottomOfVisibleTextArea) + self.textContainerInset.bottom
            }
            self.contentOffset.y += overflow
        }
    }

    // MARK: UITextViewDelegate

    func textViewDidChangeSelection(_ textView: UITextView) {
        self.align()
    }

    func textViewDidChange(_ textView: UITextView) {
        self.stretchyTextViewDelegate?.stretchyTextViewDidChangeContents(self)
    }

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        guard text ==  "\n" else { return true }
        return self.stretchyTextViewDelegate?.stretchyTextViewShouldReturn?(self) ?? true
    }
}
#endif
