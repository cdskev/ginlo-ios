//
//  DPAGDefaultTransitioner.swift
// ginlo
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public class DPAGDefaultTransparentTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController() -> DPAGDefaultTransparentTransitioning {
        let animationController = DPAGDefaultTransparentTransitioning()

        return animationController
    }

    public func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animationController = self.animationController()

        animationController.isPresentation = true

        return animationController
    }

    public func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animationController = self.animationController()

        animationController.isPresentation = false

        return animationController
    }
}

public class DPAGDefaultAnimatedTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController() -> DPAGDefaultAnimatedTransitioning {
        let animationController = DPAGDefaultAnimatedTransitioning()

        return animationController
    }

    public func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animationController = self.animationController()

        animationController.isPresentation = true

        return animationController
    }

    public func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animationController = self.animationController()

        animationController.isPresentation = false

        return animationController
    }
}

public class DPAGDefaultAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    var isPresentation = false

    override init() {
        super.init()
    }

    private static func transitionerDelegate(for vc: UIViewController) -> DPAGDefaultTransitionerDelegate? {
        if let delegate = vc as? DPAGDefaultTransitionerDelegate {
            return delegate
        }

        guard let navVC = vc as? UINavigationController else { return nil }

        guard let delegate = navVC.topViewController as? DPAGDefaultTransitionerDelegate else { return nil }

        return delegate
    }

    private static func transitionerZooming(for vc: UIViewController) -> DPAGDefaultTransitionerZoomingBase? {
        if let zoomingVC = vc as? DPAGDefaultTransitionerZoomingBase {
            return zoomingVC
        }
        if let navVC = vc as? UINavigationController,
            let zoomingVC = navVC.topViewController as? DPAGDefaultTransitionerZoomingBase {
            return zoomingVC
        }
        guard let rootContainerVC = vc as? DPAGRootContainerViewControllerProtocol,
            let rootVC = rootContainerVC.rootViewController as? (UIViewController & DPAGContainerViewControllerProtocol),
            let navVC = rootVC.children.first as? UINavigationController,
            let zoomingVC = navVC.topViewController as? DPAGDefaultTransitionerZoomingBase else { return nil }

        return zoomingVC
    }

    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        TimeInterval(UINavigationController.hideShowBarDuration)
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from), let fromView = fromVC.view, let toVC = transitionContext.viewController(forKey: .to), let toView = toVC.view else {
            return
        }

        let containerView = transitionContext.containerView
        let isPresentation = self.isPresentation

        var zoomingRect = CGRect.null

        toView.frame = containerView.bounds

        toView.setNeedsLayout()
        toView.layoutIfNeeded()

        if isPresentation {
            if let toVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: toVC), let fromVCZoom = DPAGDefaultAnimatedTransitioning.transitionerZooming(for: fromVC) {
                zoomingRect = fromVCZoom.zoomingViewForNavigationTransitionInView(fromView, mediaResource: toVCDel.mediaResourceShown())

                toVCDel.preparePresentationWithZoomingRect(zoomingRect)
            }

            containerView.addSubview(toView)
        } else {
            if let fromVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: fromVC), let toVCZoom = DPAGDefaultAnimatedTransitioning.transitionerZooming(for: toVC) {
                zoomingRect = toVCZoom.zoomingViewForNavigationTransitionInView(toView, mediaResource: fromVCDel.mediaResourceShown())

                fromVCDel.prepareDismissalWithZoomingRect(zoomingRect)
            }
        }

        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            if zoomingRect.isNull == false {
                if let fromVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: fromVC) {
                    fromVCDel.animateDismissalZoomingRect(zoomingRect)
                } else if let toVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: toVC) {
                    toVCDel.animatePresentationZoomingRect(zoomingRect)
                }
            }
        }, completion: { _ in

            if zoomingRect.isNull == false {
                if let fromVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: fromVC) {
                    fromVCDel.completeDismissalZoomingRect(zoomingRect)
                } else if let toVCDel = DPAGDefaultAnimatedTransitioning.transitionerDelegate(for: toVC) {
                    toVCDel.completePresentationZoomingRect(zoomingRect)
                }
            }

            if isPresentation == false {
                fromView.removeFromSuperview()
            }
            transitionContext.completeTransition(true)
        })
    }
}

public class DPAGDefaultTransparentTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    var isPresentation = false

    override init() {
        super.init()
    }

    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        TimeInterval(UINavigationController.hideShowBarDuration * 2)
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from), let fromView = fromVC.view, let toVC = transitionContext.viewController(forKey: .to), let toView = toVC.view else {
            return
        }

        let containerView = transitionContext.containerView
        let isPresentation = self.isPresentation

        toView.frame = containerView.bounds

        toView.setNeedsLayout()
        toView.layoutIfNeeded()

        if isPresentation {
            toView.alpha = 0
            containerView.addSubview(toView)
        }

        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            if isPresentation {
                toView.alpha = 1
            } else {
                fromView.alpha = 0
            }
        }, completion: { _ in

            if isPresentation == false {
                fromView.removeFromSuperview()
            }
            transitionContext.completeTransition(true)
        })
    }
}
