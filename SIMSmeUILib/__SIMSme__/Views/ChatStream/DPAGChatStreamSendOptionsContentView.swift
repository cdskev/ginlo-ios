//
//  DPAGChatStreamSelfDestructionView.swift
//  SIMSme
//
//  Created by RBU on 29/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGChatStreamSendOptionsContentView: UIView, DPAGChatStreamSendOptionsContentViewProtocol {
    @IBOutlet private var constraintViewLeading: NSLayoutConstraint!
    @IBOutlet private var constraintViewTrailing: NSLayoutConstraint!
    @IBOutlet private var viewSelfDestruction: UIView! {
        didSet {
            self.viewSelfDestruction.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var viewHeaderSelfDestruction: DPAGStackViewContentView!
    @IBOutlet private var headerSelfDestruction: UILabel! {
        didSet {
            self.headerSelfDestruction.font = UIFont.kFontSubheadline
            self.headerSelfDestruction.textColor = DPAGColorProvider.shared[.messageSendOptionsTint]
            self.headerSelfDestruction.text = DPAGLocalizedString("chat.button.selfdestruction.label")
        }
    }

    @IBOutlet private var viewSendTimed: UIView! {
        didSet {
            self.viewSendTimed.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    @IBOutlet private var viewHeaderSendTimed: DPAGStackViewContentView!
    @IBOutlet private var headerSendTimed: UILabel! {
        didSet {
            self.headerSendTimed.font = UIFont.kFontSubheadline
            self.headerSendTimed.textColor = DPAGColorProvider.shared[.messageSendOptionsTint]
            self.headerSendTimed.text = " "
        }
    }

    @IBOutlet private var constraintViewSelfDestructionLeading: NSLayoutConstraint!
    @IBOutlet private var constraintViewSelfDestructionTrailing: NSLayoutConstraint!
    @IBOutlet private var viewSelfDestructionDate: UIView!
    @IBOutlet private var viewSelfDestructionCountDown: UIView!

    @IBOutlet private var pickerSelfDestructionDate: UIDatePicker! {
        didSet {
            self.pickerSelfDestructionDate.addTargetClosure { [weak self] datePicker in
                DPAGSendMessageViewOptions.sharedInstance.dateSelfDestruction = datePicker.date
                self?.delegate?.sendOptionsChanged()
            }
            self.pickerSelfDestructionDate.accessibilityIdentifier = "pickerSelfDestructionDate"
            self.pickerSelfDestructionDate.backgroundColor = DPAGColorProvider.shared[.keyboard]
            self.pickerSelfDestructionDate.tintColor = DPAGColorProvider.shared[.keyboardContrast]
            self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.keyboardContrast], forKey: "textColor")
            self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.keyboardContrast], forKeyPath: "textColor")
            if #available(iOS 14, *) {
                self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
                self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
                self.pickerSelfDestructionDate.tintColor = DPAGColorProvider.shared[.datePickerText]
                self.pickerSelfDestructionDate.preferredDatePickerStyle = .compact
            }
        }
    }

    @IBOutlet private var pickerSelfDestructionCountDown: UIPickerView! {
        didSet {
            self.pickerSelfDestructionCountDown.delegate = self
            self.pickerSelfDestructionCountDown.dataSource = self
            self.pickerSelfDestructionCountDown.showsSelectionIndicator = true
            self.pickerSelfDestructionCountDown.accessibilityIdentifier = "pickerSelfDestructionCountDown"
            self.pickerSelfDestructionCountDown.backgroundColor = DPAGColorProvider.shared[.keyboard]
            self.pickerSelfDestructionCountDown.tintColor = DPAGColorProvider.shared[.keyboardContrast]
        }
    }

    @IBOutlet private var labelSelfDestructionCountDown: UILabel! {
        didSet {
            self.labelSelfDestructionCountDown.textColor = DPAGColorProvider.shared[.keyboardContrast]
        }
    }

    @IBOutlet private var viewSelfDestructionSelect: DPAGStackViewContentView!
    @IBOutlet private var buttonSelfDestructCountDown: UIButton! {
        didSet {
            self.buttonSelfDestructCountDown.accessibilityIdentifier = "chats.selfDestruction.countdown.title"
            self.buttonSelfDestructCountDown.setTitle(DPAGLocalizedString("chats.selfDestruction.countdown.title"), for: .normal)
            self.buttonSelfDestructCountDown.addTargetClosure { [weak self] buttonSelfDestructCountDown in
                buttonSelfDestructCountDown.isSelected = !buttonSelfDestructCountDown.isSelected
                DPAGSendMessageViewOptions.sharedInstance.switchSelfDestructionToCountDown(true)
                self?.configure()
                self?.delegate?.sendOptionsChanged()
            }
            self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.messageSendOptionsTint], for: .normal)
            self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .selected)
            self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .highlighted)
            self.buttonSelfDestructCountDown.titleLabel?.font = UIFont.kFontCalloutBold
            let retValNormal = self.segControlImageUnselected(button: self.buttonSelfDestructCountDown, left: false)
            let retValSelected = self.segControlImageSelected(button: self.buttonSelfDestructCountDown, left: true)
            self.buttonSelfDestructCountDown.setBackgroundImage(retValNormal, for: .normal)
            self.buttonSelfDestructCountDown.setBackgroundImage(retValSelected, for: .selected)
            self.buttonSelfDestructCountDown.setBackgroundImage(retValSelected, for: .highlighted)
            self.buttonSelfDestructCountDown.showsTouchWhenHighlighted = false
        }
    }

    @IBOutlet private var buttonSelfDestructDate: UIButton! {
        didSet {
            self.buttonSelfDestructDate.accessibilityIdentifier = "chats.selfDestruction.date.title"
            self.buttonSelfDestructDate.setTitle(DPAGLocalizedString("chats.selfDestruction.date.title"), for: .normal)
            self.buttonSelfDestructDate.addTargetClosure { [weak self] buttonSelfDestructDate in
                buttonSelfDestructDate.isSelected = !buttonSelfDestructDate.isSelected
                DPAGSendMessageViewOptions.sharedInstance.switchSelfDestructionToCountDown(false)
                self?.configure()
                self?.delegate?.sendOptionsChanged()
            }
            self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.messageSendOptionsTint], for: .normal)
            self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .selected)
            self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .highlighted)
            self.buttonSelfDestructDate.titleLabel?.font = UIFont.kFontCalloutBold
            let retValNormal = self.segControlImageUnselected(button: self.buttonSelfDestructDate, left: true)
            let retValSelected = self.segControlImageSelected(button: self.buttonSelfDestructDate, left: false)
            self.buttonSelfDestructDate.setBackgroundImage(retValNormal, for: .normal)
            self.buttonSelfDestructDate.setBackgroundImage(retValSelected, for: .selected)
            self.buttonSelfDestructDate.setBackgroundImage(retValSelected, for: .highlighted)
            self.buttonSelfDestructDate.showsTouchWhenHighlighted = false
        }
    }

    @IBOutlet private var viewSendTimedHeader: DPAGStackViewContentView!
    @IBOutlet private var imageViewSendTimedHeaderBackground: UIImageView! {
        didSet {
            let size = self.imageViewSendTimedHeaderBackground.frame.size
            let rect = CGRect(origin: .zero, size: size)
            let radius: CGFloat = 16
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: radius, height: radius)).addClip()
                DPAGColorProvider.shared[.keyboard].setFill()
                context.fill(rect)
            }
            let imageResizable = image.resizableImage(withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: 0, right: radius), resizingMode: .stretch)
            self.imageViewSendTimedHeaderBackground.image = imageResizable
        }
    }

    @IBOutlet private var labelSendTimedHeader: UILabel! {
        didSet {
            self.labelSendTimedHeader.font = UIFont.kFontCalloutBold
            self.labelSendTimedHeader.textColor = DPAGColorProvider.shared[.keyboardContrast]
            self.labelSendTimedHeader.text = DPAGLocalizedString("chat.button.sendTime.label")
        }
    }

    @IBOutlet private var viewSendTimedPicker: DPAGStackViewContentView!
    @IBOutlet private var pickerDateToSend: UIDatePicker! {
        didSet {
            self.pickerDateToSend.addTargetClosure { [weak self] datePicker in
                DPAGSendMessageViewOptions.sharedInstance.dateToBeSend = datePicker.date
                self?.delegate?.sendOptionsChanged()
            }
            self.pickerDateToSend.accessibilityIdentifier = "pickerDateToSend"
            self.pickerDateToSend.backgroundColor = DPAGColorProvider.shared[.keyboard]
            self.pickerDateToSend.tintColor = DPAGColorProvider.shared[.keyboardContrast]
            self.pickerDateToSend.setValue(DPAGColorProvider.shared[.keyboardContrast], forKey: "textColor")
            self.pickerDateToSend.setValue(DPAGColorProvider.shared[.keyboardContrast], forKeyPath: "textColor")
            if #available(iOS 14, *) {
                self.pickerDateToSend.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
                self.pickerDateToSend.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
                self.pickerDateToSend.tintColor = DPAGColorProvider.shared[.datePickerText]
                self.pickerDateToSend.preferredDatePickerStyle = .compact
            }
        }
    }

    weak var delegate: DPAGChatStreamSendOptionsContentViewDelegate?

    func reset() {
        self.pickerDateToSend.minimumDate = nil
        self.pickerDateToSend.maximumDate = nil
        self.pickerSelfDestructionDate.minimumDate = nil
        self.pickerSelfDestructionDate.maximumDate = nil
        DPAGSendMessageViewOptions.sharedInstance.reset()
        self.delegate?.sendOptionsChanged()
        self.configure()
    }

    func setup() {
        var constraints: [NSLayoutConstraint] = []
        let oldSelfDestructPicker = self.pickerSelfDestructionDate
        let newSelfDestructPicker = UIDatePicker(frame: .zero)
        oldSelfDestructPicker?.removeFromSuperview()
        self.viewSelfDestructionDate.addSubview(newSelfDestructPicker)
        newSelfDestructPicker.datePickerMode = .dateAndTime
        newSelfDestructPicker.translatesAutoresizingMaskIntoConstraints = false
        constraints += self.viewSelfDestructionDate.constraintsFill(subview: newSelfDestructPicker)
        self.pickerSelfDestructionDate = newSelfDestructPicker
        let oldSendTimedPicker = self.pickerDateToSend
        let newSendTimedPicker = UIDatePicker(frame: .zero)
        oldSendTimedPicker?.removeFromSuperview()
        self.viewSendTimedPicker.addSubview(newSendTimedPicker)
        newSendTimedPicker.datePickerMode = .dateAndTime
        newSendTimedPicker.translatesAutoresizingMaskIntoConstraints = false
        constraints += self.viewSendTimedPicker.constraintsFill(subview: newSendTimedPicker)
        self.pickerDateToSend = newSendTimedPicker
        constraints += [
            newSelfDestructPicker.constraintHeight(220),
            newSendTimedPicker.constraintHeight(220)
        ]
        NSLayoutConstraint.activate(constraints)
        self.clipsToBounds = true
    }

    private var needsPickerSelfDestructionDateColorUpdate = true
    private var needsPickerSendTimedColorUpdate = true

    func configure() {
        switch DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode {
            case .selfDestructCountDown:
                self.viewSelfDestruction.isHidden = false
                NSLayoutConstraint.deactivate([self.constraintViewTrailing, self.constraintViewSelfDestructionTrailing])
                NSLayoutConstraint.activate([self.constraintViewLeading, self.constraintViewSelfDestructionLeading])
                self.buttonSelfDestructCountDown.isSelected = true
                self.buttonSelfDestructDate.isSelected = false
                if let count = DPAGSendMessageViewOptions.sharedInstance.countDownSelfDestruction {
                    self.pickerSelfDestructionCountDown.selectRow(Int(count) - 1, inComponent: 0, animated: false)
                    if count > 1 {
                        self.labelSelfDestructionCountDown?.text = DPAGLocalizedString("chats_selfdestruction_countdown_seconds")
                    } else {
                        self.labelSelfDestructionCountDown?.text = DPAGLocalizedString("chats_selfdestruction_countdown_second")
                    }
                }
            case .selfDestructDate:
                self.viewSelfDestruction.isHidden = false
                NSLayoutConstraint.deactivate([self.constraintViewTrailing, self.constraintViewSelfDestructionLeading])
                NSLayoutConstraint.activate([self.constraintViewLeading, self.constraintViewSelfDestructionTrailing])
                self.buttonSelfDestructCountDown.isSelected = false
                self.buttonSelfDestructDate.isSelected = true
                if let date = DPAGSendMessageViewOptions.sharedInstance.dateSelfDestruction {
                    self.pickerSelfDestructionDate.setDate(date, animated: false)
                    self.pickerSelfDestructionDate.minimumDate = Date().addingMinutes(1)
                    self.pickerSelfDestructionDate.maximumDate = self.pickerSelfDestructionDate.minimumDate?.addingDays(366)
                }
                if self.needsPickerSelfDestructionDateColorUpdate {
                    self.needsPickerSelfDestructionDateColorUpdate = false
                    for label in self.pickerSelfDestructionDate.subviews(of: UILabel.self) {
                        label.textColor = DPAGColorProvider.shared[.keyboardContrast]
                        label.setNeedsDisplay()
                    }
                }
            case .sendTime:
                self.viewSendTimed.isHidden = false
                NSLayoutConstraint.deactivate([self.constraintViewLeading])
                NSLayoutConstraint.activate([self.constraintViewTrailing])
                if let date = DPAGSendMessageViewOptions.sharedInstance.dateToBeSend {
                    self.pickerDateToSend.setDate(date, animated: false)
                    self.pickerDateToSend.minimumDate = Date().addingMinutes(1)
                    self.pickerDateToSend.maximumDate = self.pickerDateToSend.minimumDate?.addingDays(366)
                }
                if self.needsPickerSendTimedColorUpdate {
                    self.needsPickerSendTimedColorUpdate = false
                    for label in self.pickerDateToSend.subviews(of: UILabel.self) {
                        label.textColor = DPAGColorProvider.shared[.keyboardContrast]
                        label.setNeedsDisplay()
                    }
                }
            case .highPriority, .unknown:
                break
        }
    }

    func completeConfigure() {
        switch DPAGSendMessageViewOptions.sharedInstance.sendOptionsViewMode {
            case .selfDestructCountDown:
                self.viewSendTimed.isHidden = true
            case .selfDestructDate:
                self.viewSendTimed.isHidden = true
            case .sendTime:
                self.viewSelfDestruction.isHidden = true
            case .highPriority, .unknown:
                break
        }
    }

    private func segControlImageSelected(button: UIButton, left: Bool) -> UIImage {
        let size = CGSize(width: button.frame.width, height: button.frame.height)
        let rectSelected = CGRect(origin: .zero, size: size)
        let radiusSelected: CGFloat = 16
        let imageSelected = UIGraphicsImageRenderer(size: size).image { context in
            let corners: UIRectCorner = left ? [.topRight] : [.topLeft]
            UIBezierPath(roundedRect: rectSelected, byRoundingCorners: corners, cornerRadii: CGSize(width: radiusSelected, height: radiusSelected)).addClip()
            DPAGColorProvider.shared[.keyboard].setFill()
            context.fill(rectSelected)
        }
        let insets = left ? UIEdgeInsets(top: radiusSelected, left: 0, bottom: 0, right: radiusSelected) : UIEdgeInsets(top: radiusSelected, left: radiusSelected, bottom: 0, right: 0)
        let imageSelectedResizable = imageSelected.resizableImage(withCapInsets: insets, resizingMode: .stretch)
        return imageSelectedResizable
    }

    private func segControlImageUnselected(button: UIButton, left: Bool) -> UIImage {
        let size = CGSize(width: button.frame.width, height: button.frame.height)
        let radiusNormal: CGFloat = 8
        let rectNormal = CGRect(origin: CGPoint(x: 0, y: size.height - radiusNormal), size: CGSize(width: size.width, height: radiusNormal))
        let imageNormal = UIGraphicsImageRenderer(size: size).image { context in
            let corners: UIRectCorner = left ? [.topRight] : [.topLeft]
            UIBezierPath(roundedRect: rectNormal, byRoundingCorners: corners, cornerRadii: CGSize(width: radiusNormal, height: radiusNormal)).addClip()
            DPAGColorProvider.shared[.keyboard].setFill()
            context.fill(rectNormal)
        }
        let insets = left ? UIEdgeInsets(top: 0, left: 0, bottom: radiusNormal, right: radiusNormal) : UIEdgeInsets(top: 0, left: radiusNormal, bottom: radiusNormal, right: 0)
        let imageNormalResizable = imageNormal.resizableImage(withCapInsets: insets, resizingMode: .stretch)
        return imageNormalResizable
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewSelfDestruction.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                self.headerSelfDestruction.textColor = DPAGColorProvider.shared[.messageSendOptionsTint]
                self.viewSendTimed.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                self.headerSendTimed.textColor = DPAGColorProvider.shared[.messageSendOptionsTint]
                self.pickerSelfDestructionDate.backgroundColor = DPAGColorProvider.shared[.keyboard]
                self.pickerSelfDestructionDate.tintColor = DPAGColorProvider.shared[.keyboardContrast]
                self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.keyboardContrast], forKey: "textColor")
                self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.keyboardContrast], forKeyPath: "textColor")
                if #available(iOS 14, *) {
                    self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
                    self.pickerSelfDestructionDate.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
                    self.pickerSelfDestructionDate.tintColor = DPAGColorProvider.shared[.datePickerText]
                }
                self.pickerSelfDestructionCountDown.backgroundColor = DPAGColorProvider.shared[.keyboard]
                self.pickerSelfDestructionCountDown.tintColor = DPAGColorProvider.shared[.keyboardContrast]
                self.labelSelfDestructionCountDown.textColor = DPAGColorProvider.shared[.keyboardContrast]
                self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.messageSendOptionsTint], for: .normal)
                self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .selected)
                self.buttonSelfDestructCountDown.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .highlighted)
                self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.messageSendOptionsTint], for: .normal)
                self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .selected)
                self.buttonSelfDestructDate.setTitleColor(DPAGColorProvider.shared[.keyboardContrast], for: .highlighted)
                self.labelSendTimedHeader.textColor = DPAGColorProvider.shared[.keyboardContrast]
                self.pickerDateToSend.backgroundColor = DPAGColorProvider.shared[.keyboard]
                self.pickerDateToSend.tintColor = DPAGColorProvider.shared[.keyboardContrast]
                self.pickerDateToSend.setValue(DPAGColorProvider.shared[.keyboardContrast], forKey: "textColor")
                self.pickerDateToSend.setValue(DPAGColorProvider.shared[.keyboardContrast], forKeyPath: "textColor")
                if #available(iOS 14, *) {
                    self.pickerDateToSend.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
                    self.pickerDateToSend.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
                    self.pickerDateToSend.tintColor = DPAGColorProvider.shared[.datePickerText]
                }
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

}

extension DPAGChatStreamSendOptionsContentView: UIPickerViewDataSource {
    func numberOfComponents(in _: UIPickerView) -> Int {
        1
    }

    func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        60
    }
}

extension DPAGChatStreamSendOptionsContentView: UIPickerViewDelegate {
    func pickerView(_: UIPickerView, attributedTitleForRow row: Int, forComponent _: Int) -> NSAttributedString? {
        NSAttributedString(string: "\(row + 1)", attributes: [.foregroundColor: DPAGColorProvider.shared[.keyboardContrast]])
    }

    func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        DPAGSendMessageViewOptions.sharedInstance.countDownSelfDestruction = TimeInterval(row + 1)
        if row > 0 {
            self.labelSelfDestructionCountDown?.text = DPAGLocalizedString("chats_selfdestruction_countdown_seconds")
        } else {
            self.labelSelfDestructionCountDown?.text = DPAGLocalizedString("chats_selfdestruction_countdown_second")
        }
        self.delegate?.sendOptionsChanged()
    }
}
