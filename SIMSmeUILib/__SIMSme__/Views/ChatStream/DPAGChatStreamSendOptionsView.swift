//
//  DPAGChatStreamSendOptionsView.swift
// ginlo
//
//  Created by RBU on 02/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGTransparentIfClearView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            if view == self {
                if self.isHidden || self.backgroundColor == .clear {
                    return nil
                }
            }
            return view
        }
        return nil
    }
}

public enum DPAGChatStreamSendOptionsViewSendOption: Int {
    case hidden,
        closed,
        opened,
        highPriority,
        selfDestruct,
        sendTimed,
        deactivated
}

public protocol DPAGChatStreamSendOptionsViewDelegate: AnyObject {
    func sendOptionSelected(sendOption: DPAGChatStreamSendOptionsViewSendOption)
}

public protocol DPAGChatStreamSendOptionsViewProtocol: AnyObject {
    var delegate: DPAGChatStreamSendOptionsViewDelegate? { get set }

    func updateButtonTextsWithSendOptions()

    func show()
    func close()
    func reset()
    func deactivate()
}

class DPAGChatStreamSendOptionsView: DPAGTransparentIfClearView, DPAGChatStreamSendOptionsViewProtocol {
    private var showState: DPAGChatStreamSendOptionsViewSendOption = .hidden

    weak var delegate: DPAGChatStreamSendOptionsViewDelegate?

    @IBOutlet private var viewActionLabel: UIView! {
        didSet {
            self.viewActionLabel.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsAction]
            self.viewActionLabel.isHidden = true
        }
    }

    @IBOutlet private var labelAction: UILabel! {
        didSet {
            self.labelAction.textAlignment = .center
            self.labelAction.font = UIFont.kFontSubheadline
            self.labelAction.textColor = DPAGColorProvider.shared[.messageSendOptionsActionContrast]
        }
    }

    @IBOutlet private var viewActions: DPAGTransparentIfClearView! {
        didSet {
            self.viewActions.isHidden = true
            self.viewActions.backgroundColor = .clear
        }
    }

    @IBOutlet private var viewActionsFrame: UIView!

    @IBOutlet private var constraintActionHighPriorityTrailing: NSLayoutConstraint!
    @IBOutlet private var viewActionHighPriority: UIView! {
        didSet {
            self.viewActionHighPriority.alpha = 0
        }
    }

    @IBOutlet private var constraintActionSelfDestructTrailing: NSLayoutConstraint!
    @IBOutlet private var viewActionSelfDestruct: UIView! {
        didSet {
            self.viewActionSelfDestruct.alpha = 0
        }
    }

    @IBOutlet private var constraintActionSendTimedTrailing: NSLayoutConstraint!
    @IBOutlet private var viewActionSendTimed: UIView! {
        didSet {
            self.viewActionSendTimed.alpha = 0
        }
    }

    @IBOutlet private var viewActionShowHide: UIView! {
        didSet {
            self.viewActionShowHide.alpha = 1
        }
    }

    private var backgroundColorButtonUnselected: UIColor {
        DPAGColorProvider.shared[.messageSendOptionsActionUnselected]
    }

    private var tintColorButtonUnselected: UIColor {
        DPAGColorProvider.shared[.messageSendOptionsActionUnselectedContrast]
    }

    @IBOutlet private var buttonHighPriority: UIButton! {
        didSet {
            self.buttonHighPriority.accessibilityIdentifier = "chat.button.enable_highPriority"
            self.configureButtonAction(self.buttonHighPriority)

            self.buttonHighPriority.setImage(DPAGImageProvider.shared[.kImagePriority], for: .normal)

            self.buttonHighPriority.addTargetClosure { [weak self] _ in

                guard let strongSelf = self else { return }

                strongSelf.viewActionLabel.isHidden = false

                if strongSelf.showState != .highPriority, DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh {
                    strongSelf.buttonHighPriority.backgroundColor = strongSelf.backgroundColorButtonUnselected
                    strongSelf.buttonHighPriority.tintColor = strongSelf.tintColorButtonUnselected
                    strongSelf.imageViewHighPriorityCancel.isHidden = true
                    strongSelf.imageViewHighPriorityCheck.isHidden = true

                    strongSelf.delegate?.sendOptionSelected(sendOption: .highPriority)

                    strongSelf.labelAction.text = DPAGLocalizedString("chat.sendOptions.highPriority.unselected")

                    strongSelf.updateButtonTextsWithSendOptions()
                } else {
                    strongSelf.delegate?.sendOptionSelected(sendOption: .highPriority)

                    strongSelf.labelAction.text = DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh ? DPAGLocalizedString("chat.sendOptions.highPriority.selected") : DPAGLocalizedString("chat.sendOptions.highPriority.unselected")

                    strongSelf.updateButtonTextsWithSendOptions()

                    switch strongSelf.showState {
                        case .highPriority:
                            strongSelf.showState = .opened
                            strongSelf.buttonHighPriority.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonHighPriority.tintColor = strongSelf.tintColorButtonUnselected
                            strongSelf.imageViewHighPriorityCancel.isHidden = true
                            strongSelf.imageViewHighPriorityCheck.isHidden = true
                        case .opened:
                            strongSelf.showState = .highPriority
                            strongSelf.buttonHighPriority.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionHighPriority]
                            strongSelf.buttonHighPriority.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionHighPriorityContrast]
                            strongSelf.imageViewHighPriorityCancel.isHidden = true
                            strongSelf.imageViewHighPriorityCheck.isHidden = false
                        case .selfDestruct, .sendTimed:
                            strongSelf.buttonHighPriority.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonHighPriority.tintColor = strongSelf.tintColorButtonUnselected
                            strongSelf.imageViewHighPriorityCancel.isHidden = false
                            strongSelf.imageViewHighPriorityCheck.isHidden = true
                        case .closed, .hidden, .deactivated:
                            break
                    }
                }
            }
        }
    }

    @IBOutlet private var imageViewHighPriorityCheck: UIImageView! {
        didSet {
            self.configureButtonActionCheck(self.imageViewHighPriorityCheck)
            self.imageViewHighPriorityCheck.isHidden = (self.showState != .highPriority)
        }
    }

    @IBOutlet private var imageViewHighPriorityCancel: UIImageView! {
        didSet {
            self.configureButtonActionCancel(self.imageViewHighPriorityCancel)
            self.imageViewHighPriorityCancel.isHidden = (DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh == false)
        }
    }

    @IBOutlet private var buttonSelfDestruct: UIButton! {
        didSet {
            self.buttonSelfDestruct.accessibilityIdentifier = "chat.button.enable_selfdestruction"
            self.buttonSelfDestruct.accessibilityLabel = DPAGLocalizedString("chat.button.enable_selfdestruction.accessibility.label")
            self.configureButtonAction(self.buttonSelfDestruct)

            if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false {
                self.buttonSelfDestruct.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestruct]
                self.buttonSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestructContrast]
            } else {
                self.buttonSelfDestruct.backgroundColor = self.backgroundColorButtonUnselected
                self.buttonSelfDestruct.tintColor = self.tintColorButtonUnselected
            }

            self.buttonSelfDestruct.setImage(DPAGImageProvider.shared[.kImageChatSelfdestruct], for: .normal)

            self.buttonSelfDestruct.addTargetClosure { [weak self] _ in

                guard let strongSelf = self else { return }

                strongSelf.viewActionLabel.isHidden = false

                if strongSelf.showState != .selfDestruct, DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false {
                    strongSelf.buttonSelfDestruct.backgroundColor = strongSelf.backgroundColorButtonUnselected
                    strongSelf.buttonSelfDestruct.tintColor = strongSelf.tintColorButtonUnselected
                    strongSelf.imageViewSelfDestructCancel.isHidden = true
                    strongSelf.imageViewSelfDestructCheck.isHidden = true

                    DPAGSendMessageViewOptions.sharedInstance.switchSelfDestruction()

                    strongSelf.labelAction.text = DPAGLocalizedString("chat.sendOptions.selfDestruct.unselected")

                    strongSelf.updateButtonTextsWithSendOptions()
                } else {
                    strongSelf.delegate?.sendOptionSelected(sendOption: .selfDestruct)

                    strongSelf.labelAction.text = (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false) ? DPAGLocalizedString("chat.sendOptions.selfDestruct.selected") : DPAGLocalizedString("chat.sendOptions.selfDestruct.unselected")

                    strongSelf.updateButtonTextsWithSendOptions()

                    switch strongSelf.showState {
                        case .selfDestruct:
                            let sendTimeEnabled = (DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false)
                            if sendTimeEnabled {
                                strongSelf.showState = .sendTimed
                                strongSelf.buttonSendTimed.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayed]
                                strongSelf.buttonSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayedContrast]
                                strongSelf.imageViewSendTimedCancel.isHidden = true
                                strongSelf.imageViewSendTimedCheck.isHidden = false
                            } else {
                                strongSelf.showState = .opened
                            }
                            strongSelf.buttonSelfDestruct.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonSelfDestruct.tintColor = strongSelf.tintColorButtonUnselected
                            strongSelf.imageViewSelfDestructCancel.isHidden = true
                            strongSelf.imageViewSelfDestructCheck.isHidden = true
                        case .opened:
                            strongSelf.showState = .selfDestruct
                            strongSelf.buttonSelfDestruct.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestruct]
                            strongSelf.buttonSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestructContrast]
                            strongSelf.imageViewSelfDestructCancel.isHidden = true
                            strongSelf.imageViewSelfDestructCheck.isHidden = false
                        case .highPriority:
                            strongSelf.showState = .selfDestruct
                            strongSelf.buttonSelfDestruct.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestruct]
                            strongSelf.buttonSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestructContrast]
                            strongSelf.imageViewSelfDestructCancel.isHidden = true
                            strongSelf.imageViewSelfDestructCheck.isHidden = false
                            strongSelf.imageViewHighPriorityCancel.isHidden = false
                            strongSelf.imageViewHighPriorityCheck.isHidden = true
                            strongSelf.buttonHighPriority.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonHighPriority.tintColor = strongSelf.tintColorButtonUnselected
                        case .sendTimed:
                            strongSelf.showState = .selfDestruct
                            strongSelf.buttonSelfDestruct.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestruct]
                            strongSelf.buttonSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestructContrast]
                            strongSelf.imageViewSelfDestructCancel.isHidden = true
                            strongSelf.imageViewSelfDestructCheck.isHidden = false
                            strongSelf.imageViewSendTimedCancel.isHidden = false
                            strongSelf.imageViewSendTimedCheck.isHidden = true
                            strongSelf.buttonSendTimed.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonSendTimed.tintColor = strongSelf.tintColorButtonUnselected
                        case .closed, .hidden, .deactivated:
                            break
                    }
                }
            }
        }
    }

    @IBOutlet private var imageViewSelfDestructCheck: UIImageView! {
        didSet {
            self.configureButtonActionCheck(self.imageViewSelfDestructCheck)
            self.imageViewSelfDestructCheck.isHidden = (self.showState != .selfDestruct)
        }
    }

    @IBOutlet private var imageViewSelfDestructCancel: UIImageView! {
        didSet {
            self.configureButtonActionCancel(self.imageViewSelfDestructCancel)
            self.imageViewSelfDestructCancel.isHidden = ((DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false) == false)
        }
    }

    @IBOutlet private var buttonSendTimed: UIButton! {
        didSet {
            self.buttonSendTimed.accessibilityIdentifier = "chat.button.enable_sendTimed"
            self.buttonSendTimed.accessibilityLabel = DPAGLocalizedString("chat.button.enable_sendTimed.accessibility.label")
            self.configureButtonAction(self.buttonSendTimed)
            self.buttonSendTimed.setImage(DPAGImageProvider.shared[.kImageChatSendTimed], for: .normal)
            self.buttonSendTimed.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.viewActionLabel.isHidden = false

                if strongSelf.showState != .sendTimed, DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false {
                    strongSelf.buttonSendTimed.backgroundColor = strongSelf.backgroundColorButtonUnselected
                    strongSelf.buttonSendTimed.tintColor = strongSelf.tintColorButtonUnselected
                    strongSelf.imageViewSendTimedCancel.isHidden = true
                    strongSelf.imageViewSendTimedCheck.isHidden = true
                    DPAGSendMessageViewOptions.sharedInstance.switchSendTimed()
                    strongSelf.labelAction.text = DPAGLocalizedString("chat.sendOptions.sendTimed.selected")
                    strongSelf.updateButtonTextsWithSendOptions()
                } else {
                    strongSelf.delegate?.sendOptionSelected(sendOption: .sendTimed)
                    strongSelf.labelAction.text = (DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false) ? DPAGLocalizedString("chat.sendOptions.sendTimed.selected") : DPAGLocalizedString("chat.sendOptions.sendTimed.unselected")
                    strongSelf.updateButtonTextsWithSendOptions()
                    switch strongSelf.showState {
                        case .sendTimed:
                            let selfDestructionEnabled = (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false)
                            if selfDestructionEnabled {
                                strongSelf.showState = .selfDestruct
                                strongSelf.buttonSelfDestruct.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestruct]
                                strongSelf.buttonSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSelfdestructContrast]
                                strongSelf.imageViewSelfDestructCancel.isHidden = true
                                strongSelf.imageViewSelfDestructCheck.isHidden = false
                            } else {
                                strongSelf.showState = .opened
                            }
                            strongSelf.buttonSendTimed.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonSendTimed.tintColor = strongSelf.tintColorButtonUnselected
                            strongSelf.imageViewSendTimedCancel.isHidden = true
                            strongSelf.imageViewSendTimedCheck.isHidden = true
                        case .opened:
                            strongSelf.showState = .sendTimed
                            strongSelf.buttonSendTimed.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayed]
                            strongSelf.buttonSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayedContrast]
                            strongSelf.imageViewSendTimedCancel.isHidden = true
                            strongSelf.imageViewSendTimedCheck.isHidden = false
                        case .highPriority:
                            strongSelf.showState = .sendTimed
                            strongSelf.buttonSendTimed.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayed]
                            strongSelf.buttonSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayedContrast]
                            strongSelf.imageViewSendTimedCancel.isHidden = true
                            strongSelf.imageViewSendTimedCheck.isHidden = false
                            strongSelf.imageViewHighPriorityCancel.isHidden = false
                            strongSelf.imageViewHighPriorityCheck.isHidden = true
                            strongSelf.buttonHighPriority.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonHighPriority.tintColor = strongSelf.tintColorButtonUnselected
                        case .selfDestruct:
                            strongSelf.showState = .sendTimed
                            strongSelf.buttonSendTimed.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayed]
                            strongSelf.buttonSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionSendDelayedContrast]
                            strongSelf.imageViewSendTimedCancel.isHidden = true
                            strongSelf.imageViewSendTimedCheck.isHidden = false
                            strongSelf.imageViewSelfDestructCancel.isHidden = false
                            strongSelf.imageViewSelfDestructCheck.isHidden = true
                            strongSelf.buttonSelfDestruct.backgroundColor = strongSelf.backgroundColorButtonUnselected
                            strongSelf.buttonSelfDestruct.tintColor = strongSelf.tintColorButtonUnselected
                        case .closed, .hidden, .deactivated:
                            break
                    }
                }
            }
        }
    }

    @IBOutlet private var imageViewSendTimedCheck: UIImageView! {
        didSet {
            self.configureButtonActionCheck(self.imageViewSendTimedCheck)
            self.imageViewSendTimedCheck.isHidden = (self.showState != .sendTimed)
        }
    }

    @IBOutlet private var imageViewSendTimedCancel: UIImageView! {
        didSet {
            self.configureButtonActionCancel(self.imageViewSendTimedCancel)
            self.imageViewSendTimedCancel.isHidden = ((DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false) == false)
        }
    }

    @IBOutlet private var buttonShowHide: UIButton! {
        didSet {
            self.buttonShowHide.accessibilityIdentifier = "chat.button.showSendOptions"
            self.configureButtonAction(self.buttonShowHide)
            self.buttonShowHide.setImage(DPAGImageProvider.shared[.kImageChatSendOptions], for: .normal)
            self.buttonShowHide.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                if strongSelf.showState == .closed {
                    strongSelf.delegate?.sendOptionSelected(sendOption: .opened)
                    strongSelf.open()
                } else {
                    strongSelf.delegate?.sendOptionSelected(sendOption: .closed)
                    strongSelf.close()
                }
            }
        }
    }

    @IBOutlet private var viewSendOptionValues: UIView! {
        didSet {
            self.viewSendOptionValues.isHidden = true
        }
    }

    @IBOutlet private var imageViewSendOptionValuesBackground: UIImageView! {
        didSet {
            let size = self.imageViewSendOptionValuesBackground.frame.size
            let rect = CGRect(origin: .zero, size: size)
            let radius: CGFloat = 8
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: radius, height: radius)).addClip()
                DPAGColorProvider.shared[.messageSendOptionsSelectedBackground].setFill()
                context.fill(rect)
            }
            let imageResizable = image.resizableImage(withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: 0, right: radius), resizingMode: .stretch)
            self.imageViewSendOptionValuesBackground.image = imageResizable
        }
    }

    @IBOutlet private var imageViewHighPriority: UIImageView! {
        didSet {
            self.imageViewHighPriority.image = DPAGImageProvider.shared[.kImagePriority]
            self.imageViewHighPriority.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
            self.imageViewHighPriority.isHidden = true
        }
    }

    @IBOutlet private var imageViewSelfDestruct: UIImageView! {
        didSet {
            self.imageViewSelfDestruct.image = DPAGImageProvider.shared[.kImageChatSelfdestruct]
            self.imageViewSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
            self.imageViewSelfDestruct.isHidden = true
        }
    }

    @IBOutlet private var labelSelfDestruct: UILabel! {
        didSet {
            self.labelSelfDestruct.font = UIFont.kFontFootnote
            self.labelSelfDestruct.textColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
            self.labelSelfDestruct.text = nil
        }
    }

    @IBOutlet private var imageViewSendTimed: UIImageView! {
        didSet {
            self.imageViewSendTimed.image = DPAGImageProvider.shared[.kImageChatSendTimed]
            self.imageViewSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
            self.imageViewSendTimed.isHidden = true
        }
    }

    @IBOutlet private var labelSendTimed: UILabel! {
        didSet {
            self.labelSendTimed.font = UIFont.kFontFootnote
            self.labelSendTimed.textColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
            self.labelSendTimed.text = nil
        }
    }

    private func configureButtonAction(_ btn: UIButton) {
        btn.setTitle(nil, for: .normal)
        btn.layer.cornerRadius = btn.frame.width / 2
        btn.backgroundColor = self.backgroundColorButtonUnselected
        btn.tintColor = self.tintColorButtonUnselected
    }

    private func configureButtonActionCancel(_ imageView: UIImageView) {
        imageView.image = DPAGImageProvider.shared[.kImageClose]
        imageView.layer.cornerRadius = imageView.frame.width / 2
        imageView.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionCancel]
        imageView.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionCancelContrast]
    }

    private func configureButtonActionCheck(_ imageView: UIImageView) {
        imageView.image = DPAGImageProvider.shared[.kImageChatCellOverlayCheck]
        imageView.layer.cornerRadius = imageView.frame.height / 2
        imageView.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsActionCheck]
        imageView.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionCheckContrast]
    }

    private func open() {
        self.showState = .opened
        self.constraintActionHighPriorityTrailing.constant = 8 + self.viewActionShowHide.frame.width
        if DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil {
            self.constraintActionSelfDestructTrailing.constant = 8 + self.viewActionShowHide.frame.width
            self.constraintActionSendTimedTrailing.constant = 8 + self.viewActionShowHide.frame.width
        }
        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: {
            self.viewActionHighPriority.alpha = 1
            if DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil {
                self.viewActionSendTimed.alpha = 1
                self.viewActionSelfDestruct.alpha = 1
            }
            self.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsOverlayBackground]
            self.buttonShowHide.backgroundColor = self.backgroundColorButtonUnselected
            self.buttonShowHide.tintColor = self.tintColorButtonUnselected
            self.buttonShowHide.setImage(DPAGImageProvider.shared[.kImageClose], for: .normal)
            self.viewSendOptionValues.isHidden = false
            self.viewActions.superview?.layoutIfNeeded()
        }, completion: { _ in
        })
    }

    func close() {
        self.showState = .closed
        self.constraintActionHighPriorityTrailing.constant = 0
        self.constraintActionSelfDestructTrailing.constant = 0
        self.constraintActionSendTimedTrailing.constant = 0
        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: {
            self.viewActionLabel.isHidden = true
            self.viewActionSendTimed.alpha = 0
            self.viewActionHighPriority.alpha = 0
            self.viewActionSelfDestruct.alpha = 0
            self.backgroundColor = .clear
            if DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh || (DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false) || (DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false) {
                self.buttonShowHide.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsAction]
                self.buttonShowHide.tintColor = DPAGColorProvider.shared[.messageSendOptionsActionContrast]
                self.viewSendOptionValues.isHidden = false
                if DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh {
                    self.imageViewHighPriorityCancel.isHidden = false
                    self.imageViewHighPriorityCheck.isHidden = true
                    self.buttonHighPriority.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonHighPriority.tintColor = self.tintColorButtonUnselected
                }
                if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false {
                    self.imageViewSelfDestructCancel.isHidden = false
                    self.imageViewSelfDestructCheck.isHidden = true
                    self.buttonSelfDestruct.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonSelfDestruct.tintColor = self.tintColorButtonUnselected
                }
                if DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false {
                    self.imageViewSendTimedCancel.isHidden = false
                    self.imageViewSendTimedCheck.isHidden = true
                    self.buttonSendTimed.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonSendTimed.tintColor = self.tintColorButtonUnselected
                }
            } else {
                self.buttonShowHide.backgroundColor = self.backgroundColorButtonUnselected
                self.buttonShowHide.tintColor = self.tintColorButtonUnselected
                self.viewSendOptionValues.isHidden = true
            }
            self.buttonShowHide.setImage(DPAGImageProvider.shared[.kImageChatSendOptions], for: .normal)
            self.viewActions.superview?.layoutIfNeeded()

        }, completion: { _ in
        })
    }

    func deactivate() {
        switch self.showState {
            case .closed, .deactivated, .hidden:
                break
            case .highPriority, .selfDestruct, .sendTimed, .opened:
                if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false {
                    self.buttonSelfDestruct.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonSelfDestruct.tintColor = self.tintColorButtonUnselected
                    self.imageViewSelfDestructCancel.isHidden = false
                    self.imageViewSelfDestructCheck.isHidden = true
                }
                if DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false {
                    self.buttonSendTimed.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonSendTimed.tintColor = self.tintColorButtonUnselected
                    self.imageViewSendTimedCancel.isHidden = false
                    self.imageViewSendTimedCheck.isHidden = true
                }
                if DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh {
                    self.buttonHighPriority.backgroundColor = self.backgroundColorButtonUnselected
                    self.buttonHighPriority.tintColor = self.tintColorButtonUnselected
                    self.imageViewHighPriorityCancel.isHidden = false
                    self.imageViewHighPriorityCheck.isHidden = true
                }
                self.showState = .opened
        }
    }

    func reset() {
        self.close()
        self.showState = .hidden
        self.updateButtonTextsWithSendOptions()
        self.viewActions.isHidden = true
        self.viewActionLabel.isHidden = true
        self.viewSendOptionValues.isHidden = true
        self.imageViewHighPriorityCheck.isHidden = true
        self.imageViewSelfDestructCheck.isHidden = true
        self.imageViewSendTimedCheck.isHidden = true
        self.imageViewHighPriorityCancel.isHidden = true
        self.imageViewSelfDestructCancel.isHidden = true
        self.imageViewSendTimedCancel.isHidden = true
        self.buttonHighPriority.backgroundColor = self.backgroundColorButtonUnselected
        self.buttonHighPriority.tintColor = self.tintColorButtonUnselected
        self.buttonSelfDestruct.backgroundColor = self.backgroundColorButtonUnselected
        self.buttonSelfDestruct.tintColor = self.tintColorButtonUnselected
        self.buttonSendTimed.backgroundColor = self.backgroundColorButtonUnselected
        self.buttonSendTimed.tintColor = self.tintColorButtonUnselected
    }

    func show() {
        switch self.showState {
            case .hidden:
                self.viewActions.isHidden = false
                self.viewActionLabel.isHidden = true
                self.viewSendOptionValues.isHidden = true
                self.showState = .closed
            case .closed, .highPriority, .opened, .selfDestruct, .sendTimed, .deactivated:
                break
        }
    }

    func updateButtonTextsWithSendOptions() {
        if DPAGSendMessageViewOptions.sharedInstance.selfDestructionEnabled ?? false {
            self.imageViewSelfDestruct.isHidden = false
            self.labelSelfDestruct.text = DPAGSendMessageViewOptions.sharedInstance.timerLabelDestructionCell
        } else {
            self.imageViewSelfDestruct.isHidden = true
            self.labelSelfDestruct.text = nil
        }

        if DPAGSendMessageViewOptions.sharedInstance.sendTimeEnabled ?? false {
            self.imageViewSendTimed.isHidden = false
            self.labelSendTimed.text = DPAGSendMessageViewOptions.sharedInstance.timerLabelSendTimeCell
        } else {
            self.imageViewSendTimed.isHidden = true
            self.labelSendTimed.text = nil
        }

        if DPAGSendMessageViewOptions.sharedInstance.messagePriorityHigh {
            self.imageViewHighPriority.isHidden = false
        } else {
            self.imageViewHighPriority.isHidden = true
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewActionLabel.backgroundColor = DPAGColorProvider.shared[.messageSendOptionsAction]
                self.labelAction.textColor = DPAGColorProvider.shared[.messageSendOptionsActionContrast]
                self.imageViewHighPriority.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
                self.imageViewSelfDestruct.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
                self.labelSelfDestruct.textColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
                self.imageViewSendTimed.tintColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
                self.labelSendTimed.textColor = DPAGColorProvider.shared[.messageSendOptionsSelectedBackgroundContrast]
                self.configureButtonActionCancel(self.imageViewHighPriorityCancel)
                self.configureButtonActionCancel(self.imageViewSelfDestructCancel)
                self.configureButtonActionCancel(self.imageViewSendTimedCancel)
                self.configureButtonActionCheck(self.imageViewHighPriorityCheck)
                self.configureButtonActionCheck(self.imageViewSelfDestructCheck)
                self.configureButtonActionCheck(self.imageViewSendTimedCheck)
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
