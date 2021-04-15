//
//  DPAGDestructionViewController.swift
//  SIMSme
//
//  Created by RBU on 12/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

enum DPAGShowDestructionViewState: UInt {
    case normal,
        destruction
}

protocol DPAGDestructionViewControllerProtocol: AnyObject {}

extension DPAGDestructionViewController: DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        guard let navigationController = self.navigationController else { return }

        navigationController.navigationBar.barTintColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        navigationController.navigationBar.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
        navigationController.navigationBar.titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.alertDestructiveTint]]
        navigationController.navigationBar.largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.alertDestructiveTint]]
    }
}

class DPAGDestructionViewController: DPAGViewControllerBackground, DPAGDestructionViewControllerProtocol, DPAGViewControllerOrientationFlexible {
    private static let explosionDuration = TimeInterval(1.0)

    private static var nf: NumberFormatter {
        let nf = NumberFormatter()

        nf.numberStyle = .decimal
        nf.minimumIntegerDigits = 2

        return nf
    }

    private var daysLeft = 0
    private var hoursLeft = 0
    private var minutesLeft = 0
    private var secondsLeft = 0
    private var hundredthLeft = 0
    var countdownTimer: Timer?
    var messageDeleted = false
    var scrollTimer: Timer?

    @IBOutlet var contentView: UIView!
    @IBOutlet private var pleaseTouchView: UIView! {
        didSet {
            self.pleaseTouchView.backgroundColor = UIColor.clear
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.timerLabel.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.backgroundView.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.pleaseTouchLabel.textColor = DPAGColorProvider.shared[.labelText]
                self.pleaseTouchImage.tintColor = DPAGColorProvider.shared[.labelText]

                guard let navigationController = self.navigationController else { return }
                navigationController.navigationBar.barTintColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                navigationController.navigationBar.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
                navigationController.navigationBar.titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.alertDestructiveTint]]
                navigationController.navigationBar.largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.alertDestructiveTint]]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @IBOutlet var selfdestructionFooter: UIView!

    @IBOutlet private var backgroundView: UIView! {
        didSet {
            self.backgroundView.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var timerLabel: UILabel! {
        didSet {
            self.timerLabel.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            self.timerLabel.text = nil
            self.timerLabel.attributedText = nil
        }
    }

    @IBOutlet private var pleaseTouchLabel: UILabel! {
        didSet {
            self.pleaseTouchLabel.text = self.pleaseTouchText
            self.pleaseTouchLabel.textAlignment = .center
            self.pleaseTouchLabel.numberOfLines = 0
            self.pleaseTouchLabel.textColor = DPAGColorProvider.shared[.labelText]
            self.pleaseTouchLabel.font = UIFont.kFontBody
        }
    }

    @IBOutlet private var pleaseTouchImage: UIImageView! {
        didSet {
            self.pleaseTouchImage.image = DPAGImageProvider.shared[.kImageChatMessageFingerprint]
            self.pleaseTouchImage.tintColor = DPAGColorProvider.shared[.labelText]
        }
    }

    private var messageGuid: String
    var decryptedMessage: DPAGDecryptedMessage
    var streamGuid: String

    var readyToStart = false
    var hasSelfDestructionStarted = false

    override var preferredStatusBarStyle: UIStatusBarStyle {
        DPAGColorProvider.shared[.alertDestructiveTint].statusBarStyle(backgroundColor: DPAGColorProvider.shared[.alertDestructiveBackground])
    }

    init(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String) {
        self.decryptedMessage = decMessage
        self.messageGuid = messageGuid
        self.streamGuid = streamGuid

        super.init(nibName: "DPAGDestructionViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.extendedLayoutIncludesOpaqueBars = true

        if (self.navigationController?.viewControllers.count ?? 0) == 1 {
            self.setLeftBackBarButtonItem(action: #selector(dismissViewController))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.selfdestructionFooter.isHidden = true
        self.pleaseTouchView.isHidden = true
        self.contentView.isHidden = true

        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil, queue: .main) { [weak self] _ in

            self?.navigationController?.isNavigationBarHidden = false
            self?.navigationController?.popViewController(animated: false)
        }
    }

    @objc
    private func dismissViewController() {
        self.countdownTimer?.invalidate()
        self.countdownTimer = nil
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.countdownTimer?.invalidate()
        self.countdownTimer = nil

        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
        }
    }

    private func setSecondsLeftFromDate(_ destructionDate: Date?) {
        let timeDifference: TimeInterval

        if let destructionDate = destructionDate {
            timeDifference = destructionDate.timeIntervalSince(Date())
        } else {
            timeDifference = 0
        }

        self.secondsLeft = Int(round(timeDifference))

        self.daysLeft = self.secondsLeft / 86_400
        self.secondsLeft -= self.daysLeft * 86_400

        self.hoursLeft = self.secondsLeft / 3_600
        self.secondsLeft -= self.hoursLeft * 3_600

        self.minutesLeft = self.secondsLeft / 60
        self.secondsLeft -= self.minutesLeft * 60
    }

    func configureSelfDestruction() {
        self.pleaseTouchView.isHidden = false
        self.contentView.isHidden = true
        self.selfdestructionFooter.isHidden = true

        if let configuration = self.decryptedMessage.sendOptions {
            let dateSelfDestruction = configuration.destructionDateForCountdown(messageGuid: self.decryptedMessage.messageGuid)

            NotificationCenter.default.addObserver(self, selector: #selector(handleScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)

            self.setSecondsLeftFromDate(dateSelfDestruction)
        }

        self.selfdestructionFooter.setNeedsLayout()
        self.selfdestructionFooter.layoutIfNeeded()
    }

    private var timerLabelString: NSAttributedString {
        let localizedString = DPAGLocalizedString("chats.showText.destroyedIn")
        let localizedStringAttributed = NSAttributedString(string: localizedString)

        let daysString = (DPAGDestructionViewController.nf.string(from: NSNumber(value: self.daysLeft)) ?? "00") + ":"
        let hoursString = (DPAGDestructionViewController.nf.string(from: NSNumber(value: self.hoursLeft)) ?? "00") + ":"
        let minutesString = (DPAGDestructionViewController.nf.string(from: NSNumber(value: self.minutesLeft)) ?? "00") + ":"
        let secondsString = (DPAGDestructionViewController.nf.string(from: NSNumber(value: self.secondsLeft)) ?? "00") + "."

        let timeString: String

        if self.daysLeft > 0 {
            timeString = daysString + hoursString + minutesString + secondsString + "\(self.hundredthLeft)"
        } else if self.hoursLeft > 0 {
            timeString = hoursString + minutesString + secondsString + "\(self.hundredthLeft)"
        } else if self.minutesLeft > 0 {
            timeString = minutesString + secondsString + "\(self.hundredthLeft)"
        } else {
            timeString = secondsString + "\(self.hundredthLeft)"
        }

        let retVal = NSMutableAttributedString(string: localizedString + " " + timeString)

        let monoSpaced = UIFont.monospacedDigitSystemFont(ofSize: self.timerLabel.font.pointSize, weight: UIFont.Weight(rawValue: 0))

        retVal.addAttribute(.font, value: monoSpaced, range: NSRange(location: localizedStringAttributed.length + 1, length: retVal.length - localizedStringAttributed.length - 1))

        return retVal
    }

    func removeContent() {}

    private func fireSelfDestruction() {
        if let presentedVC = self.navigationController?.topViewController, presentedVC == self {
            self.removeContent()

            if !self.messageDeleted {
                self.deleteMessage()
            }

            self.navigationController?.popViewController(animated: true)
        }
    }

    var destructionFinishedText: String {
        DPAGLocalizedString("chats.showText.destroyedLabel")
    }

    private var explosionArray: [UIImage] {
        var retVal: [UIImage] = []

        for idx in 1 ... 30 {
            if let image = DPAGImageProvider.shared["szf_" + (DPAGDestructionViewController.nf.string(from: NSNumber(value: idx)) ?? "00")] {
                retVal.append(image)
            } else {
                break
            }
        }

        return retVal
    }

    @objc
    func updateCountdownLabel() {
        if self.hundredthLeft > 0 {
            self.hundredthLeft -= 1
        } else if self.hundredthLeft == 0, self.secondsLeft > 0 {
            self.secondsLeft -= 1
            self.hundredthLeft = 9
        } else if self.secondsLeft == 0, self.minutesLeft > 0 {
            self.minutesLeft -= 1
            self.secondsLeft = 60
        } else if self.minutesLeft == 0, self.hoursLeft > 0 {
            self.hoursLeft -= 1
            self.minutesLeft = 60
        } else if self.hoursLeft == 0, self.daysLeft > 0 {
            self.daysLeft -= 1
            self.hoursLeft = 24
        } else {
            self.hasSelfDestructionStarted = true
            self.countdownTimer?.invalidate()
            self.scrollTimer?.invalidate()
            self.selfdestructionFooter.isHidden = true
            self.pleaseTouchView.isHidden = true

            self.fireSelfDestruction()
        }
        self.timerLabel.attributedText = self.timerLabelString
    }

    @objc
    func handleScreenshot() {
        if self.contentView.isHidden == false {
            self.contentView.isHidden = true

            self.countdownTimer?.invalidate()
            self.scrollTimer?.invalidate()
            self.selfdestructionFooter.isHidden = true
            self.pleaseTouchView.isHidden = true

            self.fireSelfDestruction()
        }
    }

    var pleaseTouchText: String {
        DPAGLocalizedString("chats.showText.pleaseTouch")
    }

    func updateTouchState(_ isTouching: Bool) {
        if isTouching {
            self.pleaseTouchView.isHidden = true
            self.contentView.isHidden = false
            self.selfdestructionFooter.isHidden = false
        } else {
            self.contentView.isHidden = true
            self.pleaseTouchView.isHidden = false
        }
        self.setNeedsStatusBarAppearanceUpdate()
    }

    func countDownStarted() {
        DPAGApplicationFacade.messageWorker.startSelfDestructionCountDown(messageGuid: self.decryptedMessage.messageGuid, sendOptions: self.decryptedMessage.sendOptions)
    }

    private func deleteMessage() {
        DPAGApplicationFacade.messageWorker.deleteSelfDestructedMessage(messageGuid: self.decryptedMessage.messageGuid)

        self.messageDeleted = true
    }
}
