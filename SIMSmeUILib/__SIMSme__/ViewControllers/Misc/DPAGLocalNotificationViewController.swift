//
//  DPAGLocalNotificationViewController.m
// ginlo
//
//  Created by Florin Pop on 20/11/14.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGScrollView: UIScrollView {
    weak var designatedTouchCoordinator: UIView?

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        self.designatedTouchCoordinator?.frame.contains(point) ?? true
    }
}

public class DPAGLocalNotificationViewController: UIViewController, UIScrollViewDelegate {
    private static var notificationInstances: [DPAGLocalNotificationViewController] = []

    @IBOutlet private var scrollView: DPAGScrollView? {
        didSet {
            self.scrollView?.delegate = self
        }
    }

    @IBOutlet private var viewBackground: UIView? {
        didSet {
            self.viewBackground?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var viewContentSafe: UIView? {
        didSet {}
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewBackground?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                self.viewBorderBottom?.layer.shadowColor = DPAGColorProvider.shared[.backgroundBorder].cgColor
                self.labelContent?.textColor = DPAGColorProvider.shared[.labelText]
                self.labelTitle?.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet private var viewDragHandle: UIView? {
        didSet {
            self.viewDragHandle?.layer.cornerRadius = 3
            self.viewDragHandle?.layer.masksToBounds = true
        }
    }

    @IBOutlet private var buttonDragHandle: DPAGInAppPushButton? {
        didSet {
            self.buttonDragHandle?.delegatePanTracking = self
        }
    }

    @IBOutlet private var viewBorderBottom: UIView? {
        didSet {
            self.viewBorderBottom?.layer.shadowOffset = CGSize(width: 0, height: 1)
            self.viewBorderBottom?.layer.shadowColor = DPAGColorProvider.shared[.backgroundBorder].cgColor
            self.viewBorderBottom?.layer.shadowRadius = 3.0
            self.viewBorderBottom?.layer.shadowOpacity = 0.35
        }
    }

    @IBOutlet private var labelContent: UILabel? {
        didSet {
            self.labelContent?.numberOfLines = 0
            self.labelContent?.textColor = DPAGColorProvider.shared[.labelText]
            self.labelContent?.font = UIFont.kFontCaption1
        }
    }

    @IBOutlet private var labelTitle: UILabel? {
        didSet {
            self.labelTitle?.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var imageView: UIImageView? {
        didSet {
            self.imageView?.image = DPAGImageProvider.shared[.kImageButtonAlert]
            self.imageView?.backgroundColor = .clear
        }
    }

    @IBOutlet private var imageViewProfile: UIImageView? {
        didSet {
            self.imageViewProfile?.backgroundColor = .clear
        }
    }

    private var hideCompletionBlock: DPAGCompletion?

    private var isScrollingUp = false
    private var expandsOnShow = false
    private var isDismissedWithTapGesture = false
    private var isDismissedWithSwipeUpGesture = false
    private var getsDismissed = false
    private var lastOffset: CGPoint = .zero

    private var initialHeight: CGFloat = 0

    private weak var tapGrContent: UITapGestureRecognizer?

    @IBOutlet private var constraintViewHeight: NSLayoutConstraint?

    init() {
        super.init(nibName: "DPAGLocalNotificationViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last

        self.initialHeight = self.constraintViewHeight?.constant ?? 0

        let msgTap = UITapGestureRecognizer(target: self, action: #selector(messageTapAction))

        self.viewContentSafe?.addGestureRecognizer(msgTap)
        msgTap.isEnabled = false

        self.tapGrContent = msgTap
    }

    private var message: String? {
        self.labelContent?.text
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.scrollView?.designatedTouchCoordinator = self.viewBackground
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if self.expandsOnShow {
            self.constraintViewHeight?.isActive = false
        }

        self.tapGrContent?.isEnabled = true
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        DPAGFunctionsGlobal.synchronized(self, block: {
            self.hideCompletionBlock?()
            self.hideCompletionBlock = nil
        })
    }

    private func setup(config: LocalNotificationConfig) {
        self.labelTitle?.text = config.title
        self.labelContent?.text = config.message
        self.imageView?.image = config.image
        self.imageViewProfile?.image = config.imageProfile

        if config.roundedImageProfile, let imageView = self.imageView {
            self.imageViewProfile?.layer.cornerRadius = imageView.frame.size.width / 2.0
            self.imageViewProfile?.layer.masksToBounds = true
        }
    }

    @objc
    private func messageTapAction() {
        self.isDismissedWithTapGesture = true
        self.hide(true)
    }

    @objc
    private func hideAnimated() {
        self.hide(true)
    }

    private func hide(_ animated: Bool) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)

        if animated {
            self.getsDismissed = true

            var rect = self.view.bounds

            rect.origin.y = -rect.height

            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseIn, animations: {
                self.view.frame = rect
                self.view.window?.rootViewController?.setNeedsStatusBarAppearanceUpdate()

            }, completion: { _ in

                self.view.removeFromSuperview()
            })
        } else {
            self.view.removeFromSuperview()
        }
    }

    private class func addNotificationInstance(_ instance: DPAGLocalNotificationViewController) {
        DPAGFunctionsGlobal.synchronized(self, block: {
            self.notificationInstances.append(instance)
        })
    }

    private class func removeNotificationInstance(_ instance: DPAGLocalNotificationViewController?) {
        if let instance = instance {
            DPAGFunctionsGlobal.synchronized(self, block: {
                if let idx = self.notificationInstances.firstIndex(of: instance) {
                    self.notificationInstances.remove(at: idx)
                }
            })
        }
    }

    public struct LocalNotificationConfig {
        let title: String?
        let message: String?
        let image: UIImage?
        let imageProfile: UIImage?
        let roundedImageProfile: Bool
        let duration: TimeInterval
        let isExpanded: Bool
        let completionOnShow: ((Bool) -> Void)?
        let completionOnHide: ((Bool, Bool) -> Void)?

        public init(title: String?, message: String?, image: UIImage?, imageProfile: UIImage?, roundedImageProfile: Bool, duration: TimeInterval, isExpanded: Bool) {
            self.init(title: title, message: message, image: image, imageProfile: imageProfile, roundedImageProfile: roundedImageProfile, duration: duration, isExpanded: isExpanded, completionOnShow: nil, completionOnHide: nil)
        }

        public init(title: String?, message: String?, image: UIImage?, imageProfile: UIImage?, roundedImageProfile: Bool, duration: TimeInterval, isExpanded: Bool, completionOnShow: ((Bool) -> Void)?, completionOnHide: ((Bool, Bool) -> Void)?) {
            self.title = title
            self.message = message
            self.image = image
            self.imageProfile = imageProfile
            self.roundedImageProfile = roundedImageProfile
            self.duration = duration
            self.isExpanded = isExpanded

            self.completionOnHide = completionOnHide
            self.completionOnShow = completionOnShow
        }
    }

    @discardableResult
    public class func show(config: LocalNotificationConfig) -> DPAGLocalNotificationViewController? {
        guard let windowRef = AppConfig.appWindow(), let window = windowRef, window.rootViewController != nil else {
            DPAGLog("Cannot show a notification when the window root view controller is nil")

            config.completionOnShow?(false)

            return nil
        }

        let localNotificationViewController = DPAGLocalNotificationViewController()

        DPAGLocalNotificationViewController.addNotificationInstance(localNotificationViewController)

        weak var weakLocalNotificationViewController: DPAGLocalNotificationViewController? = localNotificationViewController

        localNotificationViewController.hideCompletionBlock = {
            if weakLocalNotificationViewController != nil {
                config.completionOnHide?(weakLocalNotificationViewController?.isDismissedWithTapGesture ?? false, weakLocalNotificationViewController?.isDismissedWithSwipeUpGesture ?? false)
                DPAGLocalNotificationViewController.removeNotificationInstance(weakLocalNotificationViewController)
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()
            } else {
                config.completionOnHide?(false, false)
            }
        }

        let block = {
            window.addSubview(localNotificationViewController.view)

            let rect = window.bounds

            localNotificationViewController.view.frame = CGRect(x: 0, y: -rect.size.height, width: rect.size.width, height: rect.size.height)

            localNotificationViewController.setup(config: config)
            localNotificationViewController.expandsOnShow = config.isExpanded

            // Show
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                weakLocalNotificationViewController?.view.frame = window.bounds
                window.rootViewController?.setNeedsStatusBarAppearanceUpdate()

            }, completion: { _ in

                config.completionOnShow?(true)

                if config.duration > 0.1 {
                    weakLocalNotificationViewController?.perform(#selector(hideAnimated), with: nil, afterDelay: config.duration)
                }
            })
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }

        return localNotificationViewController
    }

    class var topmostLocalNotification: UIViewController? {
        var returnValue: DPAGLocalNotificationViewController?

        DPAGFunctionsGlobal.synchronized(self, block: {
            let notifications = self.notificationInstances

            for localNotificationViewController in notifications where !localNotificationViewController.getsDismissed {
                returnValue = localNotificationViewController
            }
        })
        return returnValue
    }

    public class func hideAllNotifications(_ animated: Bool) {
        DPAGFunctionsGlobal.synchronized(self, block: {
            let notifications = self.notificationInstances

            for localNotificationViewController in notifications {
                localNotificationViewController.hide(animated)
            }
        })
    }
}

extension DPAGLocalNotificationViewController: ButtonInAppPushPanTrackingDelegate {
    public static let NOTIFICATION_DISPLAY_DURATION = TimeInterval(4)

    func handleBtnPanCancel() {
        self.constraintViewHeight?.constant = self.initialHeight

        UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            self?.viewContentSafe?.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.perform(#selector(strongSelf.hideAnimated), with: nil, afterDelay: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION)
        })
    }

    func handleBtnPanBegin() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }

    func handleBtnPanTracking(locationNew: CGPoint, locationOld: CGPoint) {
        var newConst = self.constraintViewHeight?.constant ?? 0
        let diff = locationNew.y - locationOld.y

        newConst += diff
        self.isScrollingUp = diff < 0

        self.constraintViewHeight?.constant = min(newConst, self.initialHeight * 2)
    }

    func handleBtnPanTrackingEnd(locationNew _: CGPoint, locationOld _: CGPoint) {
        if self.isScrollingUp || (self.constraintViewHeight?.constant ?? 0) < self.initialHeight {
            self.isDismissedWithSwipeUpGesture = true
            self.hide(true)
        } else {
            self.perform(#selector(self.hideAnimated), with: nil, afterDelay: DPAGLocalNotificationViewController.NOTIFICATION_DISPLAY_DURATION)
        }
    }
}

protocol ButtonInAppPushPanTrackingDelegate: AnyObject {
    func handleBtnPanBegin()
    func handleBtnPanCancel()
    func handleBtnPanTracking(locationNew: CGPoint, locationOld: CGPoint)
    func handleBtnPanTrackingEnd(locationNew: CGPoint, locationOld: CGPoint)
}

class DPAGInAppPushButton: UIButton {
    weak var delegatePanTracking: ButtonInAppPushPanTrackingDelegate?

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let retVal = super.beginTracking(touch, with: event)

        self.delegatePanTracking?.handleBtnPanBegin()

        return retVal
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let retVal = super.continueTracking(touch, with: event)

        if let event = event, event.type == .touches, touch.view == self {
            let pt1Self = touch.location(in: self)
            let pt0Self = touch.previousLocation(in: self)

            self.delegatePanTracking?.handleBtnPanTracking(locationNew: pt1Self, locationOld: pt0Self)
        }
        return retVal
    }

    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)

        NSObject.cancelPreviousPerformRequests(withTarget: self)

        self.delegatePanTracking?.handleBtnPanCancel()
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)

        NSObject.cancelPreviousPerformRequests(withTarget: self)

        if let touch = touch {
            let pt1Self = touch.location(in: self)
            let pt0Self = touch.previousLocation(in: self)

            self.delegatePanTracking?.handleBtnPanTrackingEnd(locationNew: pt1Self, locationOld: pt0Self)
        } else {
            self.delegatePanTracking?.handleBtnPanCancel()
        }
    }
}
