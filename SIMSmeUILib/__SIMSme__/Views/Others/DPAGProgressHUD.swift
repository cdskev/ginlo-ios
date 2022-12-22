//
//  DPAGProgressHUD.swift
// ginlo
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGProgressHUDDelegate: AnyObject {
    func setupHUD(_ hud: DPAGProgressHUDProtocol)
}

public protocol DPAGProgressHUDProtocol: AnyObject {}

private protocol DPAGProgressHUDProtocolPrivate: AnyObject {
    var delegate: DPAGProgressHUDDelegate? { get set }

    func setup()

    func showUsingAnimation(_ animated: Bool)
    func hideUsingAnimation(_ animated: Bool)
    func showUsingAnimation(_ animated: Bool, completion: DPAGCompletion?)
    func hideUsingAnimation(_ animated: Bool, completion: DPAGCompletion?)
}

public class DPAGProgressHUD {
    public static let sharedInstance = DPAGProgressHUD()

    fileprivate func createInstance(frame: CGRect) -> (UIView & DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate) {
        DPAGProgressHUDInstance(frame: frame)
    }

    @discardableResult
    public func show(_ animated: Bool) -> DPAGProgressHUDProtocol? {
        self.show(animated, completion: nil)
    }

    @discardableResult
    public func show(_ animated: Bool, completion: ((DPAGProgressHUDProtocol?) -> Void)?) -> DPAGProgressHUDProtocol? {
        self.show(animated, completion: completion, delegate: nil)
    }

    @discardableResult
    public func show(_ animated: Bool, completion: ((_ alertInstance: DPAGProgressHUDProtocol?) -> Void)?, delegate: DPAGProgressHUDDelegate?) -> DPAGProgressHUDProtocol? {
        if let windowRef = AppConfig.appWindow() {
            return self.show(animated, in: windowRef, completion: completion, delegate: delegate)
        }
        return self.show(animated, in: nil, completion: completion, delegate: delegate)
    }

    @discardableResult
    public func show(_ animated: Bool, in window: UIWindow?, completion: ((_ alertInstance: DPAGProgressHUDProtocol?) -> Void)?, delegate: DPAGProgressHUDDelegate?) -> DPAGProgressHUDProtocol? {
        guard let window = window else {
            completion?(nil)
            return nil
        }

        let hud = self.createInstance(frame: window.bounds)

        hud.delegate = delegate

        window.performBlockOnMainThread {
            hud.setup()

            window.addSubview(hud)

            hud.showUsingAnimation(animated, completion: {
                completion?(hud)
            })
        }

        return hud
    }

    @discardableResult
    public func showForBackgroundProcess(_ animated: Bool, completion: @escaping ((DPAGProgressHUDProtocol?) -> Void)) -> DPAGProgressHUDProtocol? {
        self.showForBackgroundProcess(animated, completion: completion, delegate: nil)
    }

    private let completionBlockBackground: (DPAGProgressHUDProtocol?, @escaping ((DPAGProgressHUDProtocol?) -> Void)) -> Void = { hud, completion in

        if Thread.isMainThread {
            let block = { completion(hud) }

            DispatchQueue.global(qos: .default).async(execute: block)
        } else {
            completion(hud)
        }
    }

    @discardableResult
    public func showForBackgroundProcess(_ animated: Bool, completion: @escaping ((DPAGProgressHUDProtocol?) -> Void), delegate: DPAGProgressHUDDelegate?) -> DPAGProgressHUDProtocol? {
        if let windowRef = AppConfig.appWindow() {
            return self.showForBackgroundProcess(animated, in: windowRef, completion: completion, delegate: delegate)
        }

        return self.showForBackgroundProcess(animated, in: nil, completion: completion, delegate: delegate)
    }

    @discardableResult
    public func showForBackgroundProcess(_ animated: Bool, in window: UIWindow?, completion: @escaping ((DPAGProgressHUDProtocol?) -> Void)) -> DPAGProgressHUDProtocol? {
        self.showForBackgroundProcess(animated, in: window, completion: completion, delegate: nil)
    }

    @discardableResult
    public func showForBackgroundProcess(_ animated: Bool, in window: UIWindow?, completion: @escaping ((DPAGProgressHUDProtocol?) -> Void), delegate: DPAGProgressHUDDelegate?) -> DPAGProgressHUDProtocol? {
        guard let window = window else {
            DispatchQueue.global(qos: .default).async {
                completion(nil)
            }
            return nil
        }

        let hud = self.createInstance(frame: window.bounds)

        hud.delegate = delegate

        window.performBlockOnMainThread {
            hud.setup()

            window.addSubview(hud)

            hud.showUsingAnimation(animated, completion: {
                AppConfig.setIdleTimerDisabled(true)
                self.completionBlockBackground(hud, completion)
            })
        }

        return hud
    }

    public func hide(_ animated: Bool) {
        self.hide(animated, completion: nil)
    }

    public func hide(_ animated: Bool, completion: DPAGCompletion?) {
        let block = { [weak self] in

            if let windowRef = AppConfig.appWindow() {
                self?.hide(animated, in: windowRef, completion: completion)
            } else {
                self?.hide(animated, in: nil, completion: completion)
            }
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    public func hide(_ animated: Bool, in window: UIWindow?, completion: DPAGCompletion?) {
        DispatchQueue.main.async {
            AppConfig.setIdleTimerDisabled(false)

            guard let window = window else {
                completion?()
                return
            }

            guard let hud = self.HUDForView(window) else {
                completion?()
                return
            }

            hud.hideUsingAnimation(animated, completion: completion)
        }
    }

    private func HUDForView(_ view: UIView) -> (DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate)? {
        let subViews = view.subviews.reversed()

        return subViews.first(where: { $0 is (DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate) }) as? (DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate)
    }

    public func isHUDVisible() -> Bool {
        guard let mainWindowRef = AppConfig.appWindow(), let mainWindow = mainWindowRef else {
            return false
        }
        if self.HUDForView(mainWindow) != nil {
            return true
        }
        return false
    }
}

class DPAGProgressHUDInstance: UIView, DPAGProgressHUDProtocol, DPAGProgressHUDProtocolPrivate {
    var viewBackground: UIVisualEffectView = UIVisualEffectView()
    var viewForeground: UIVisualEffectView = UIVisualEffectView()

    var activityIndicator = UIActivityIndicatorView(style: .whiteLarge)

    var blurEffect = UIBlurEffect(style: DPAGColorProvider.shared[.progressHUDBackground].blurEffectStyle())

    weak var delegate: DPAGProgressHUDDelegate?

    override required init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setup() {
        self.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last

        self.isOpaque = false
        self.backgroundColor = UIColor.clear
        self.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        self.setupBackground()
        self.setupForeground()
        self.setupActivityIndicator()

        self.delegate?.setupHUD(self)

        self.setNeedsDisplay()
    }

    fileprivate func setupBackground() {
        self.viewBackground.layer.cornerRadius = 5
        self.viewBackground.layer.masksToBounds = true

        // self.layer.allowsGroupOpacity = false

        self.insertSubview(viewBackground, at: 0)

        self.viewBackground.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            self.viewBackground.constraintWidth(100),
            self.viewBackground.constraintHeight(100),

            self.constraintCenterX(subview: self.viewBackground),
            self.constraintCenterY(subview: self.viewBackground)
        ])
    }

    fileprivate func setupForeground() {
        self.viewBackground.contentView.addSubview(self.viewForeground)

        self.viewForeground.translatesAutoresizingMaskIntoConstraints = false

        self.viewBackground.contentView.addConstraintsFill(subview: self.viewForeground)
    }

    fileprivate func setupActivityIndicator() {
        let contentView = self.viewBackground.contentView

        contentView.addSubview(self.activityIndicator)

        self.activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.activityIndicator.color = DPAGColorProvider.shared[.progressHUDActivityIndicator]

        [
            contentView.constraintCenterX(subview: self.activityIndicator),
            contentView.constraintCenterY(subview: self.activityIndicator)
        ].activate()
    }

    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    /* override func drawRect(rect: CGRect)
     {
         super.drawRect(rect)

         let allRect = self.bounds
         let boxRect = CGRectMake(round((allRect.size.width - self.size.width) / 2) + CGFloat(self.xOffset),
             round((allRect.size.height - self.size.height) / 2) + CGFloat(self.yOffset), self.size.width, self.size.height)

         self.viewBackground.frame = boxRect
      } */

    func hideUsingAnimation(_ animated: Bool) {
        self.hideUsingAnimation(animated, completion: nil)
    }

    func showUsingAnimation(_ animated: Bool) {
        self.showUsingAnimation(animated, completion: nil)
    }

    fileprivate func hideSubviews() {
        self.activityIndicator.stopAnimating()
        self.viewBackground.effect = nil
        self.viewForeground.effect = nil
    }

    func hideUsingAnimation(_ animated: Bool, completion: DPAGCompletion?) {
        let block = {
            self.hideSubviews()
        }

        let blockCompletion = {
            self.removeFromSuperview()
            completion?()
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: block, completion: { _ in
                blockCompletion()
            })
        } else {
            block()
            blockCompletion()
        }
    }

    fileprivate func showSubviews() {
        self.viewBackground.effect = self.blurEffect
        self.viewForeground.effect = UIVibrancyEffect(blurEffect: self.blurEffect)
        self.activityIndicator.startAnimating()
    }

    func showUsingAnimation(_ animated: Bool, completion: DPAGCompletion?) {
        let block = {
            self.showSubviews()
        }

        let blockCompletion = {
            completion?()
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: block, completion: { _ in
                blockCompletion()
            })
        } else {
            block()
            blockCompletion()
        }
    }
}

public protocol DPAGProgressHUDFullViewProtocol: DPAGProgressHUDProtocol {
    var statusBarStyle: UIStatusBarStyle { get }
}

public class DPAGProgressHUDFullView: DPAGProgressHUD {
    public static let sharedInstanceFullView = DPAGProgressHUDFullView()

    override fileprivate func createInstance(frame: CGRect) -> (UIView & DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate) {
        DPAGProgressHUDFullViewInstance(frame: frame)
    }
}

class DPAGProgressHUDFullViewInstance: DPAGProgressHUDInstance, DPAGProgressHUDFullViewProtocol {
    required init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func setup() {
        super.setup()

        self.blurEffect = UIBlurEffect(style: DPAGColorProvider.shared[.progressHUDFullViewBackground].blurEffectStyle())
    }

    var statusBarStyle: UIStatusBarStyle {
        DPAGColorProvider.shared[.progressHUDFullViewBackground].statusBarStyle(backgroundColor: DPAGColorProvider.shared[.progressHUDFullViewActivityIndicator])
    }

    override func setupBackground() {
        self.insertSubview(viewBackground, at: 0)

        self.viewBackground.translatesAutoresizingMaskIntoConstraints = false

        self.addConstraintsFill(subview: self.viewBackground)
    }

    override func setupForeground() {
        self.viewBackground.contentView.addSubview(self.viewForeground)

        self.viewForeground.translatesAutoresizingMaskIntoConstraints = false

        self.viewBackground.contentView.addConstraintsFill(subview: self.viewForeground)
    }
}

public protocol DPAGProgressHUDWithLabelProtocol: DPAGProgressHUDFullViewProtocol {
    var labelTitle: DPAGLabelMain { get }
}

public class DPAGProgressHUDWithLabel: DPAGProgressHUDFullView {
    public static let sharedInstanceLabel = DPAGProgressHUDWithLabel()

    override fileprivate func createInstance(frame: CGRect) -> (UIView & DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate) {
        DPAGProgressHUDWithLabelInstance(frame: frame)
    }
}

public class DPAGLabelMain: UILabel {
    override public var text: String? {
        get {
            super.text
        }
        set {
            if Thread.isMainThread {
                super.text = newValue
            } else {
                self.performBlockOnMainThread { [weak self] in
                    self?.text = newValue
                }
            }
        }
    }
}

class DPAGProgressHUDWithLabelInstance: DPAGProgressHUDFullViewInstance, DPAGProgressHUDWithLabelProtocol {
    let labelTitle = DPAGLabelMain()

    required init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func setupActivityIndicator() {
        super.setupActivityIndicator()

        self.activityIndicator.color = DPAGColorProvider.shared[.progressHUDFullViewActivityIndicator]

        self.labelTitle.translatesAutoresizingMaskIntoConstraints = false
        self.labelTitle.font = UIFont.kFontHeadline
        self.labelTitle.textAlignment = .center
        self.labelTitle.numberOfLines = 0
        self.labelTitle.textColor = DPAGColorProvider.shared[.progressHUDFullViewText]
        self.labelTitle.alpha = 0

        let contentView = self.viewBackground.contentView

        contentView.addSubview(self.labelTitle)

        [
            contentView.constraintLeading(subview: self.labelTitle, padding: DPAGConstantsGlobal.kPadding),
            contentView.constraintTrailing(subview: self.labelTitle, padding: DPAGConstantsGlobal.kPadding),

            contentView.constraintBottomToTop(bottomView: self.activityIndicator, topView: self.labelTitle, padding: 8)
        ].activate()
    }

    override func hideSubviews() {
        super.hideSubviews()

        self.labelTitle.alpha = 0
    }

    override func showSubviews() {
        super.showSubviews()

        self.labelTitle.alpha = 1
    }
}

public protocol DPAGProgressHUDWithProgressProtocol: DPAGProgressHUDWithLabelProtocol {
    var labelDescription: UILabel { get }
    var viewProgress: UIProgressView { get }
}

public class DPAGProgressHUDWithProgress: DPAGProgressHUDWithLabel {
    public static let sharedInstanceProgress = DPAGProgressHUDWithProgress()

    override fileprivate func createInstance(frame: CGRect) -> (UIView & DPAGProgressHUDProtocol & DPAGProgressHUDProtocolPrivate) {
        DPAGProgressHUDWithProgressInstance(frame: frame)
    }
}

class DPAGProgressHUDWithProgressInstance: DPAGProgressHUDWithLabelInstance, DPAGProgressHUDWithProgressDelegate, DPAGProgressHUDWithProgressProtocol {
    let labelDescription = UILabel()
    let viewProgress = UIProgressView(progressViewStyle: .default)

    required init(frame: CGRect) {
        super.init(frame: frame)
    }

    func setProgress(_ progress: CGFloat, withText text: String?) {
        self.viewProgress.setProgress(Float(progress), animated: true)
        self.labelDescription.text = text
    }

    override func setupActivityIndicator() {
        super.setupActivityIndicator()

        self.labelDescription.translatesAutoresizingMaskIntoConstraints = false
        self.viewProgress.translatesAutoresizingMaskIntoConstraints = false

        self.labelDescription.font = UIFont.kFontSubheadline

        self.labelDescription.textAlignment = .center

        self.labelDescription.numberOfLines = 0

        self.viewProgress.progressTintColor = DPAGColorProvider.shared[.progressHUDFullViewProgress]
        self.viewProgress.trackTintColor = DPAGColorProvider.shared[.progressHUDFullViewTrack]
        self.labelDescription.textColor = DPAGColorProvider.shared[.progressHUDFullViewText]

        let contentView = self.viewBackground.contentView

        contentView.addSubview(self.labelDescription)
        contentView.addSubview(self.viewProgress)

        [
            contentView.constraintLeading(subview: self.labelDescription, padding: DPAGConstantsGlobal.kPadding),
            contentView.constraintLeading(subview: self.viewProgress, padding: DPAGConstantsGlobal.kPadding),
            contentView.constraintTrailing(subview: self.labelDescription, padding: DPAGConstantsGlobal.kPadding),
            contentView.constraintTrailing(subview: self.viewProgress, padding: DPAGConstantsGlobal.kPadding),

            contentView.constraintBottomToTop(bottomView: self.labelTitle, topView: self.viewProgress, padding: 8),
            contentView.constraintBottomToTop(bottomView: self.viewProgress, topView: self.labelDescription, padding: 13),

            contentView.constraintBottomGreaterThan(subview: self.labelDescription, padding: 5)
        ].activate()

        self.viewProgress.transform = self.viewProgress.transform.scaledBy(x: 1, y: 2)
        self.viewProgress.accessibilityIdentifier = "DPAGProgressHUDWithProgress"
    }
}

extension UIViewController {
    func hideProgressHUD(animated _: Bool, completion: @escaping DPAGCompletion) {
        self.performBlockOnMainThread { [weak self] in

            DPAGProgressHUD.sharedInstance.hide(true, in: self?.view.window, completion: completion)
        }
    }

    func showProgressHUD(animated _: Bool, completion: ((DPAGProgressHUDProtocol?) -> Void)?) {
        self.performBlockOnMainThread { [weak self] in

            DPAGProgressHUD.sharedInstance.show(true, in: self?.view.window, completion: completion, delegate: nil)
        }
    }

    func showProgressHUDForBackgroundProcess(animated _: Bool, completion: @escaping ((DPAGProgressHUDProtocol?) -> Void)) {
        self.performBlockOnMainThread { [weak self] in

            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true, in: self?.view.window, completion: completion, delegate: nil)
        }
    }
}
