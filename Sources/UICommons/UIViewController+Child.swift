import UIKit

extension UIViewController {
    func presentChildViewController(_ vc: UIViewController, completion: ((Bool) -> Void)?) {
        addChild(vc)
        view.addSubview(vc.view)

        vc.view.alpha = 0
        UIView.animate(withDuration: 0.25, animations: {
            vc.view.alpha = 1
        }, completion: { [weak self] finished in
            if let strongSelf = self {
                vc.didMove(toParent: strongSelf)
            }
            completion?(finished)
        })
    }

    func dismissChildViewController(_ vc: UIViewController, completion: ((Bool) -> Void)?) {
        vc.willMove(toParent: nil)

        UIView.animate(withDuration: 0.25, animations: { [weak vc] in
            vc?.view.alpha = 0
        }, completion: { [weak vc] finished in
            vc?.view.removeFromSuperview()
            vc?.removeFromParent()
            completion?(finished)
        })
    }
}
