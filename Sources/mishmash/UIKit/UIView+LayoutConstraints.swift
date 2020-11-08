#if os(iOS)
import Foundation
import UIKit

extension UIView {
    @discardableResult
    func pin(_ attr: NSLayoutConstraint.Attribute, _ relation: NSLayoutConstraint.Relation = .equal, to: CGFloat, priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
        translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: attr,
            relatedBy: relation,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: to
        )
        if let priority = priority {
            constraint.priority = priority
        }
        addConstraint(constraint)
        return constraint
    }

    @discardableResult
    func pin(_ subview: UIView, _ relation: NSLayoutConstraint.Relation = .equal, to: NSLayoutConstraint.Attribute,_ const: CGFloat = 0.0, priority: UILayoutPriority? = nil, multiplier: CGFloat = 1) -> NSLayoutConstraint {
        subview.translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint(
            item: subview,
            attribute: to,
            relatedBy: relation,
            toItem: self,
            attribute: to,
            multiplier: multiplier,
            constant: const
        )
        if let priority = priority {
            constraint.priority = priority
        }
        addConstraint(constraint)
        return constraint
    }

    @discardableResult
    func pin(_ av: UIView,
             _ a: NSLayoutConstraint.Attribute,
             _ relation: NSLayoutConstraint.Relation = .equal,
             to bv: UIView,
             _ b: NSLayoutConstraint.Attribute,
             _ constant: CGFloat = 0,
             multiplier: CGFloat = 1.0,
             priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
        av.translatesAutoresizingMaskIntoConstraints = false
        /// to avoid a view controller's view from setting to false and 'disappearing'
        /// this might cause issues elsewhere to be aware of
        if bv != self {
            bv.translatesAutoresizingMaskIntoConstraints = false
        }

        let constraint = NSLayoutConstraint(
            item: av,
            attribute: a,
            relatedBy: relation,
            toItem: bv,
            attribute: b,
            multiplier: multiplier,
            constant: constant
        )
        if let priority = priority {
            constraint.priority = priority
        }
        addConstraint(constraint)
        return constraint
    }

    @discardableResult
    func pinAspectRatio(_ a: NSLayoutConstraint.Attribute, _ relation: NSLayoutConstraint.Relation, _ b: NSLayoutConstraint.Attribute, _ multiplier: CGFloat = 1.0) -> NSLayoutConstraint {
        translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint(
            item: self,
            attribute: a,
            relatedBy: relation,
            toItem: self,
            attribute: b,
            multiplier: multiplier,
            constant: 0.0
        )
        addConstraint(constraint)
        return constraint
    }
}

// MARK: UIImageView

enum WidthHeight {
    case width, height
}
extension UIImageView {
    /// used to pin an imageview
    func pinAspectRatio(maintaining: WidthHeight) {
        guard image != nil else {
            Log.warn("unable to pin image aspect ratio, no image set")
            return
        }
        guard let image = image else { return }
        let width = image.size.width
        let height = image.size.height
        switch maintaining {
        case .width:
            pinAspectRatio(.height, .equal, .width, height / width)
        case .height:
            pinAspectRatio(.width, .equal, .height, width / height)
        }
    }
}

#endif
