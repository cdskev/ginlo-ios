//
//  DPAGOutOfOfficeStatusViewController.swift
//  SIMSme
//
//  Created by Yves Hetzer on 23.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGOutOfOfficeStatusViewController: DPAGViewControllerWithKeyboard, DPAGOutOfOfficeStatusViewControllerProtocol, UIGestureRecognizerDelegate {
    private static let MAXLENGTH_OOO_STATUS = 140

    weak var delegate: DPAGStatusPickerTableViewControllerDelegate?

    @IBOutlet private var labelHeader: UILabel! {
        didSet {
            self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
            self.labelHeader.text = DPAGLocalizedString("profile.oooStatus.labelHeader")
        }
    }

    @IBOutlet private var labelOooSwitch: UILabel! {
        didSet {
            self.labelOooSwitch.textColor = DPAGColorProvider.shared[.labelText]
            self.labelOooSwitch.text = DPAGLocalizedString("profile.oooStatus.labelOooSwitch")
        }
    }

    @IBOutlet private var labelOooDate: UILabel! {
        didSet {
            self.labelOooDate.textColor = DPAGColorProvider.shared[.labelText]
            self.labelOooDate.text = DPAGLocalizedString("profile.oooStatus.labelOooDate")
        }
    }

    @IBOutlet private var labelFooter: UILabel! {
        didSet {
            self.labelFooter.textColor = DPAGColorProvider.shared[.labelText]
            self.labelFooter.text = DPAGLocalizedString("profile.oooStatus.labelFooter")
        }
    }

    @IBOutlet private var labelFooterCharacter: UILabel! {
        didSet {
            self.labelFooterCharacter.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelOooDateValue: UILabel! {
        didSet {
            self.labelOooDateValue.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var viewSeparator1: UIView! {
        didSet {
            self.viewSeparator1.backgroundColor = DPAGColorProvider.shared[.tableSeparator]
        }
    }

    @IBOutlet private var viewSeparator2: UIView! {
        didSet {
            self.viewSeparator2.backgroundColor = DPAGColorProvider.shared[.tableSeparator]
        }
    }

    @IBOutlet private var viewOooDate: UIView! {
        didSet {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapDatepicker))

            tap.delegate = self
            self.viewOooDate.addGestureRecognizer(tap)
        }
    }

    @IBOutlet private var viewOooStatus: UIView!
    @IBOutlet private var viewLabelFooter: UIView!

    @IBOutlet private var viewDatePickerOoDate: UIView! {
        didSet {
            self.viewDatePickerOoDate.isHidden = true
        }
    }

    @IBOutlet private var datePickerOoDate: UIDatePicker! {
        didSet {
            self.datePickerOoDate.minimumDate = Date()
            self.datePickerOoDate.minuteInterval = 15

            self.datePickerOoDate.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
            self.datePickerOoDate.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
            self.datePickerOoDate.tintColor = DPAGColorProvider.shared[.datePickerText]

            // self.datePickerOoDate.sendAction(Selector(("setHighlightsToday:")), to: nil, for: nil)
            self.datePickerOoDate.date = Date()
            self.datePickerOoDate.addTargetClosure { [weak self] _ in

                self?.oooDate = self?.datePickerOoDate.date
                self?.updateValues()
            }
        }
    }

    @IBOutlet private var scrollView: UIScrollView!

    @IBOutlet private var textOooStatus: UITextView! {
        didSet {
            self.textOooStatus.delegate = self
        }
    }

    @IBOutlet private var switchOooEnabled: UISwitch! {
        didSet {}
    }

    private var oooDate: Date?
    private var oooEnabled: Bool = false
    private var oooText: String?

    init() {
        super.init(nibName: "DPAGOutOfOfficeStatusViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setLeftBarButtonItem(title: DPAGLocalizedString("res.cancel"), action: #selector(cancel))
        self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(handleSetButtonPressed), accessibilityLabelIdentifier: DPAGLocalizedString("navigation.done"))

        UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColorWorkaround = DPAGColorProvider.shared[.datePickerText]

        self.title = DPAGLocalizedString("profile.oooStatus.title")

        if let guid = DPAGApplicationFacade.cache.account?.guid, let contact = DPAGApplicationFacade.cache.contact(for: guid) {
            self.oooEnabled = contact.oooStatusState == "ooo"
            self.oooText = contact.oooStatusText
            if let date = contact.oooStatusValid {
                self.oooDate = DPAGFormatter.dateServer.date(from: date)
            }
            if self.oooText == nil {
                self.oooText = DPAGLocalizedString("profile.oooStatus.default")
            }
        }

        self.updateValues()
        self.setup()
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelHeader.textColor = DPAGColorProvider.shared[.labelText]
                self.labelOooSwitch.textColor = DPAGColorProvider.shared[.labelText]
                self.labelOooDate.textColor = DPAGColorProvider.shared[.labelText]
                self.labelFooter.textColor = DPAGColorProvider.shared[.labelText]
                self.labelFooterCharacter.textColor = DPAGColorProvider.shared[.labelText]
                self.labelOooDateValue.textColor = DPAGColorProvider.shared[.labelText]
                self.viewSeparator1.backgroundColor = DPAGColorProvider.shared[.tableSeparator]
                self.viewSeparator2.backgroundColor = DPAGColorProvider.shared[.tableSeparator]
                self.datePickerOoDate.setValue(DPAGColorProvider.shared[.datePickerText], forKey: "textColor")
                self.datePickerOoDate.setValue(DPAGColorProvider.shared[.datePickerText], forKeyPath: "textColor")
                self.datePickerOoDate.tintColor = DPAGColorProvider.shared[.datePickerText]
                UILabel.appearance(whenContainedInInstancesOf: [UIDatePicker.self]).textColorWorkaround = DPAGColorProvider.shared[.datePickerText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func setup() {
        var constraints: [NSLayoutConstraint] = []

        let oldPicker = self.datePickerOoDate
        let newPicker = UIDatePicker(frame: .zero)

        oldPicker?.removeFromSuperview()
        self.viewDatePickerOoDate.addSubview(newPicker)

        newPicker.datePickerMode = .dateAndTime
        newPicker.translatesAutoresizingMaskIntoConstraints = false

        constraints += self.viewDatePickerOoDate.constraintsFill(subview: newPicker)
        self.datePickerOoDate = newPicker

        NSLayoutConstraint.activate(constraints)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        DPAGUIHelper.setupAppAppearance()
    }

    @objc
    private func cancel() {
        // self.textFieldStatusText?.resignFirstResponder()

        self.dismiss(animated: true, completion: nil)
    }

    @objc
    private func handleSetButtonPressed() {
        if self.oooEnabled, let oooDate = self.oooDate, oooDate.isInPast {
            showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "profile.oooStatus.oooDate.mustBeInFuture"))
            return
        }

        if self.oooEnabled, self.oooDate == nil {
            showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "profile.oooStatus.oooDate.mustBeSet"))
            return
        }

        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in

            let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in

                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    if let strongSelf = self {
                        if let errorMessage = errorMessage {
                            strongSelf.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                        } else {
                            strongSelf.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            }

            var oooStateValid: String? = ""

            if let oooDate = self.oooDate {
                oooStateValid = DPAGFormatter.dateServer.string(from: oooDate)
            }

            var oooStateOld = DPAGLocalizedString("profile.oooStatus.oldState.active")

            if self.oooEnabled {
                if let oooDate = self.oooDate {
                    oooStateOld = String(format: DPAGLocalizedString("profile.oooStatus.oldState.oooWithDate"), oooDate.dateLabel)

                } else {
                    oooStateOld = DPAGLocalizedString("profile.oooStatus.oldState.ooo")
                }
            }
            self.performBlockOnMainThread {
                self.delegate?.updateStatusMessage(oooStateOld)
            }
            DPAGApplicationFacade.statusWorker.updateStatus(oooStateOld, broadCast: false)

            if self.oooEnabled {
                DPAGApplicationFacade.statusWorker.updateStatus(oooStateOld, oooState: "ooo", oooStatusText: self.oooText, oooStateValid: oooStateValid, completion: responseBlock)
            } else {
                DPAGApplicationFacade.statusWorker.updateStatus(oooStateOld, oooState: "available", oooStatusText: nil, oooStateValid: nil, completion: responseBlock)
            }
        }
    }

    @objc
    private func handleTapDatepicker(sender _: UITapGestureRecognizer? = nil) {
        guard self.oooEnabled else { return }

        // Datepicker anzeigen / Verstecken
        self.viewDatePickerOoDate.isHidden = !self.viewDatePickerOoDate.isHidden

        if self.viewDatePickerOoDate.isHidden == false {
            self.textOooStatus.resignFirstResponder()
            if let oooDate = self.oooDate {
                self.datePickerOoDate.date = oooDate
            }
        }

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

            guard let strongSelf = self else { return }

            strongSelf.viewDatePickerOoDate.superview?.layoutIfNeeded()
        }
    }

    private func updateValues() {
        if let oooDate = self.oooDate {
            self.labelOooDateValue.text = oooDate.dateLabel + " " + oooDate.timeLabel
        } else {
            self.labelOooDateValue.text = DPAGLocalizedString("profile.oooStatus.labelOooDateValue.empty")
        }

        if self.oooEnabled == false {
            self.textOooStatus.resignFirstResponder()
            self.viewDatePickerOoDate.isHidden = true
            self.viewOooDate.alpha = 0.2
            self.viewOooStatus.alpha = 0.2
            self.viewLabelFooter.alpha = 0.2
            self.textOooStatus.isUserInteractionEnabled = false
            self.switchOooEnabled.isOn = false
        } else {
            self.viewOooDate.alpha = 1.0
            self.viewOooStatus.alpha = 1.0
            self.viewLabelFooter.alpha = 1.0
            self.textOooStatus.isUserInteractionEnabled = true
            self.switchOooEnabled.isOn = true
        }

        self.textOooStatus.text = self.oooText

        if let oooText = self.oooText {
            self.labelFooterCharacter.text = String(format: DPAGLocalizedString("profile.oooStatus.labelFooterCharacter"), String(oooText.count), String(DPAGOutOfOfficeStatusViewController.MAXLENGTH_OOO_STATUS))
        } else {
            self.labelFooterCharacter.text = String(format: DPAGLocalizedString("profile.oooStatus.labelFooterCharacter"), "0", String(DPAGOutOfOfficeStatusViewController.MAXLENGTH_OOO_STATUS))
        }
    }

    @objc
    private func handleProfileInputDoneTapped() {
        self.textOooStatus.resignFirstResponder()
    }

    @IBAction private func handleOooEnabledChanged(_: Any) {
        self.oooEnabled = self.switchOooEnabled.isOn
        self.updateValues()
    }

    // MARK: - UIKeyboard handling

    override func handleViewTapped(_: Any?) {
        self.textOooStatus.resignFirstResponder()
    }

    override func handleKeyboardWillHide(_ aNotification: Notification) {
        self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(handleSetButtonPressed), accessibilityLabelIdentifier: DPAGLocalizedString("navigation.done"))

        super.handleKeyboardWillHide(aNotification, scrollView: self.scrollView)

        self.oooText = self.textOooStatus.text
    }

    override func handleKeyboardWillShow(_ aNotification: Notification) {
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(handleProfileInputDoneTapped), accessibilityLabelIdentifier: "navigation.done")

        self.viewDatePickerOoDate.isHidden = true
        super.handleKeyboardWillShow(aNotification, scrollView: self.scrollView, viewVisible: self.textOooStatus)
    }
}

// MARK: - UITextViewDelegate

extension DPAGOutOfOfficeStatusViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let currentText = (textView.text as NSString?) else {
            return true
        }
        var retVal = true

        let resultedString = currentText.replacingCharacters(in: range, with: text)

        var resultedStringNew: String = resultedString

        if resultedString.count >= DPAGOutOfOfficeStatusViewController.MAXLENGTH_OOO_STATUS {
            resultedStringNew = String(resultedString[..<resultedString.index(resultedString.startIndex, offsetBy: DPAGOutOfOfficeStatusViewController.MAXLENGTH_OOO_STATUS)])
            textView.text = resultedStringNew
            retVal = false
        }

        self.labelFooterCharacter.text = String(format: DPAGLocalizedString("profile.oooStatus.labelFooterCharacter"), String(resultedStringNew.count), String(DPAGOutOfOfficeStatusViewController.MAXLENGTH_OOO_STATUS))
        return retVal
    }
}
