//
//  DPAGAccountIDSelectorView.swift
//  SIMSmeUIViewsLib
//
//  Created by RBU on 08.08.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGAccountIDSelectorViewProtocol: AnyObject {
    var delegate: DPAGAccountIDSelectorViewDelegate? { get set }

    var preferredDataSelectionIndex: DPAGAccountIDSelectorView.DataSelectionType { get }
    var preferredCountryIndex: Int { get }

    var textFieldActive: UITextField? { get }

    var labelCountryCodeValue: UILabel! { get }
    var labelCountryCode: UILabel! { get }
    var labelPhone: UILabel! { get }

    var textFieldPhone: DPAGTextField! { get }
    var textFieldEmail: DPAGTextField! { get }
    var textFieldAccountID: DPAGTextField! { get }

    func removeDataPicker(completion: DPAGCompletion?)
    func removeCountryPicker(completion: DPAGCompletion?)

    func updateCountryInfo(index: Int)
    func updateDataSelection(index: DPAGAccountIDSelectorView.DataSelectionType, withStack: Bool)

    func enabledPhoneOnly()
}

public protocol DPAGAccountIDSelectorViewDelegate: UITextFieldDelegate {
    var labelPhoneNumberSelection: String { get }
    var labelEMailAddressSelection: String { get }
    var labelSIMSmeIDSelection: String { get }

    var labelPhoneNumberPicker: String { get }
    var labelEMailAddressPicker: String { get }
    var labelSIMSmeIDPicker: String { get }

    func accountIDSelectorViewWillShowDataSelection()
    func accountIDSelectorViewWillHideDataSelection()
    func accountIDSelectorViewWillShowCountryCodeSelection()
    func accountIDSelectorViewWillHideCountryCodeSelection()

    func accountIDSelectorViewDidSelect()
}

@IBDesignable
public class DPAGAccountIDSelectorView: DPAGStackViewContentView, NibFileOwnerLoadable, DPAGAccountIDSelectorViewProtocol {
    public enum DataSelectionType: Int, CaseCountable {
        case phoneNum,
            emailAddress,
            simsmeID
    }

    @IBInspectable var showAccountID: Bool = true

    public weak var delegate: DPAGAccountIDSelectorViewDelegate?

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadNibContent()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        self.buttonDataSelection.addSubview(self.imageViewDataSelection)

        NSLayoutConstraint.activate([
            self.buttonDataSelection.topAnchor.constraint(equalTo: self.imageViewDataSelection.topAnchor),
            self.buttonDataSelection.bottomAnchor.constraint(equalTo: self.imageViewDataSelection.bottomAnchor),
            self.buttonDataSelection.trailingAnchor.constraint(equalTo: self.imageViewDataSelection.trailingAnchor)
        ])

        self.buttonCountryCode.addSubview(self.imageViewCountryCode)

        NSLayoutConstraint.activate([
            self.buttonCountryCode.topAnchor.constraint(equalTo: self.imageViewCountryCode.topAnchor),
            self.buttonCountryCode.bottomAnchor.constraint(equalTo: self.imageViewCountryCode.bottomAnchor),
            self.buttonCountryCode.trailingAnchor.constraint(equalTo: self.imageViewCountryCode.trailingAnchor)
        ])

        self.pickerDataSelection.isHidden = true
        self.textFieldEmail.isHidden = true
        self.textFieldAccountID.isHidden = true
        self.pickerCountryCode.isHidden = true

        self.determineUserPreferredSettings()

        if AppConfig.buildConfigurationMode == .DEBUG {
            self.updateCountryInfo(index: 0)
        }

        self.updateDataSelection(index: .phoneNum, withStack: false)
    }

    override public func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        self.loadNibContent()

//        self.labelCitationFrom?.text = "from"
//        self.labelCitationContent?.text = "Content"
    }

    @IBOutlet private var stackViewAll: UIStackView!

    @IBOutlet private var viewDataSelection: UIView!
    @IBOutlet private var buttonDataSelection: UIButton! {
        didSet {
            self.buttonDataSelection.accessibilityIdentifier = "buttonDataSelection"
            self.buttonDataSelection.layer.cornerRadius = 2.0
            self.buttonDataSelection.backgroundColor = UIColor.clear
            self.buttonDataSelection.addTargetClosure { [weak self] _ in

                guard let strongSelf = self else { return }

                strongSelf.resignFirstResponder()

                strongSelf.removeCountryPicker { [weak self] in

                    guard let strongSelf = self else { return }

                    if strongSelf.pickerDataSelection.isHidden == false {
                        strongSelf.removeDataPicker(completion: nil)
                        return
                    }

                    strongSelf.pickerDataSelection.isHidden = false
                    strongSelf.pickerDataSelection.selectRow(strongSelf.preferredDataSelectionIndex.rawValue, inComponent: 0, animated: false)
                    strongSelf.delegate?.accountIDSelectorViewWillShowDataSelection()

                    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.pickerDataSelection.superview?.layoutIfNeeded()
                    }
                }
            }
            self.buttonDataSelection.titleLabel?.font = UIFont.kFontCallout
            self.buttonDataSelection.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        }
    }

    @IBOutlet private var imageViewDataSelection: UIImageView! {
        didSet {
            self.imageViewDataSelection.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var pickerDataSelection: UIPickerView! {
        didSet {
            self.pickerDataSelection.dataSource = self
            self.pickerDataSelection.delegate = self
            self.pickerDataSelection.accessibilityIdentifier = "pickerDataSelection"
            self.pickerDataSelection.isHidden = true
        }
    }

    @IBOutlet private var stackViewDataSelection: UIStackView!
    @IBOutlet private var viewPhoneNum: UIView!
    @IBOutlet private var stackViewPhoneNum: UIStackView!
    @IBOutlet public private(set) var labelCountryCode: UILabel! {
        didSet {
            self.labelCountryCode.text = DPAGLocalizedString("registration.label.countryLabel")
            self.labelCountryCode.configureLabelForTextField()
        }
    }

    @IBOutlet private var viewCountryCode: UIView!
    @IBOutlet private var buttonCountryCode: UIButton! {
        didSet {
            self.buttonCountryCode.accessibilityIdentifier = "buttonCountryCode"
            self.buttonCountryCode.layer.cornerRadius = 2.0
            self.buttonCountryCode.backgroundColor = UIColor.clear
            self.buttonCountryCode.addTargetClosure { [weak self] _ in

                guard let strongSelf = self else { return }

                strongSelf.resignFirstResponder()
                strongSelf.removeDataPicker { [weak self] in

                    guard let strongSelf = self else { return }

                    if strongSelf.pickerCountryCode.isHidden == false {
                        strongSelf.removeCountryPicker(completion: nil)
                        return
                    }

                    strongSelf.pickerCountryCode.isHidden = false
                    strongSelf.pickerCountryCode.selectRow(strongSelf.preferredCountryIndex, inComponent: 0, animated: false)
                    strongSelf.delegate?.accountIDSelectorViewWillShowCountryCodeSelection()

                    UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration)) { [weak self] in

                        guard let strongSelf = self else { return }

                        strongSelf.pickerCountryCode.superview?.layoutIfNeeded()
                    }
                }
            }
            self.buttonCountryCode.titleLabel?.font = UIFont.kFontCallout
            self.buttonCountryCode.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        }
    }

    @IBOutlet private var imageViewCountryCode: UIImageView! {
        didSet {
            self.imageViewCountryCode.image = UIImage.drillDownImage
        }
    }

    @IBOutlet private var pickerCountryCode: UIPickerView! {
        didSet {
            self.pickerCountryCode.dataSource = self
            self.pickerCountryCode.delegate = self
            self.pickerCountryCode.accessibilityIdentifier = "pickerCountryCode"
            self.pickerCountryCode.isHidden = true
        }
    }

    @IBOutlet public private(set) var labelPhone: UILabel! {
        didSet {
            self.labelPhone.text = DPAGLocalizedString("registration.subline.phoneAndCountryCode")
            self.labelPhone.configureLabelForTextField()
        }
    }

    @IBOutlet private var stackViewPhone: UIStackView!
    @IBOutlet public private(set) var labelCountryCodeValue: UILabel! {
        didSet {
            self.labelCountryCodeValue.font = UIFont.kFontCallout
            self.labelCountryCodeValue.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet public private(set) var textFieldPhone: DPAGTextField! {
        didSet {
            self.textFieldPhone.accessibilityIdentifier = "textFieldPhone"
            self.textFieldPhone.configureDefault()
            self.textFieldPhone.delegate = self
            self.textFieldPhone.keyboardType = .phonePad
            self.textFieldPhone.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.input.phone.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldPhone.accessibilityLabel = DPAGLocalizedString("registration.subline.phoneAndCountryCode")
        }
    }

    @IBOutlet public private(set) var textFieldEmail: DPAGTextField! {
        didSet {
            self.textFieldEmail.accessibilityIdentifier = "textFieldEmail"
            self.textFieldEmail.configureDefault()
            self.textFieldEmail.delegate = self
            self.textFieldEmail.keyboardType = .emailAddress
            self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.createDevice.inputDataLabelEmail"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldEmail.isHidden = true
        }
    }

    @IBOutlet public private(set) var textFieldAccountID: DPAGTextField! {
        didSet {
            self.textFieldAccountID.accessibilityIdentifier = "textFieldAccountID"
            self.textFieldAccountID.configureDefault()
            self.textFieldAccountID.delegate = self
            self.textFieldAccountID.keyboardType = .asciiCapable
            self.textFieldAccountID.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            self.textFieldAccountID.isHidden = true
        }
    }

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.buttonDataSelection.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
                self.buttonCountryCode.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
                self.labelCountryCodeValue.textColor = DPAGColorProvider.shared[.labelText]
                self.textFieldPhone.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.input.phone.placeholder"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.textFieldEmail.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.createDevice.inputDataLabelEmail"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
                self.textFieldAccountID.attributedPlaceholder = NSAttributedString(string: DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID"), attributes: [.foregroundColor: DPAGColorProvider.shared[.placeholder]])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    public private(set) var preferredDataSelectionIndex: DataSelectionType = .phoneNum
    public private(set) var preferredCountryIndex = -1

    public private(set) var textFieldActive: UITextField?

    @discardableResult
    override public func resignFirstResponder() -> Bool {
        self.textFieldPhone.resignFirstResponder()
        self.textFieldEmail.resignFirstResponder()
        self.textFieldAccountID.resignFirstResponder()
        self.textFieldActive = nil
        return super.resignFirstResponder()
    }

    private func determineUserPreferredSettings() {
        let locale = Locale.current
        let iso = (locale as NSLocale).object(forKey: NSLocale.Key.countryCode) as? String
        self.updateCountryInfo(index: DPAGCountryCodes.sharedInstance.indexForIso(iso))
    }

    public func updateCountryInfo(index: Int) {
        if index >= 0 {
            self.preferredCountryIndex = index
            let country = DPAGCountryCodes.sharedInstance.countries[index]
            self.labelCountryCodeValue.text = country.code
            self.buttonCountryCode.setTitle(country.name, for: .normal)
        }
    }

    public func updateDataSelection(index: DataSelectionType, withStack: Bool) {
        self.preferredDataSelectionIndex = index
        var inputViewAdd: UIView
        var inputViewsRemove: [UIView]
        switch index {
            case .phoneNum:
                self.buttonDataSelection.setTitle(self.delegate?.labelPhoneNumberSelection ?? DPAGLocalizedString("registration.createDevice.inputDataLabelPhoneNumber.label"), for: .normal)
                inputViewAdd = self.viewPhoneNum
                inputViewsRemove = [self.textFieldAccountID, self.textFieldEmail]
            case .emailAddress:
                self.buttonDataSelection.setTitle(self.delegate?.labelEMailAddressSelection ?? DPAGLocalizedString("registration.createDevice.inputDataLabelEmail.label"), for: .normal)
                inputViewAdd = self.textFieldEmail
                inputViewsRemove = [self.viewPhoneNum, self.textFieldAccountID]
            case .simsmeID:
                self.buttonDataSelection.setTitle(self.delegate?.labelSIMSmeIDSelection ?? DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID.label"), for: .normal)
                inputViewAdd = self.textFieldAccountID
                inputViewsRemove = [self.viewPhoneNum, self.textFieldEmail]
        }
        if withStack, inputViewAdd.isHidden {
            inputViewAdd.isHidden = false
            for view in inputViewsRemove {
                view.isHidden = true
            }
            self.stackViewDataSelection.layoutIfNeeded()
            self.removeDataPicker { [weak self, weak inputViewAdd] in
                self?.delegate?.accountIDSelectorViewDidSelect()
                inputViewAdd?.becomeFirstResponder()
            }
        }
    }

    public func removeDataPicker(completion: DPAGCompletion?) {
        if self.pickerDataSelection.isHidden {
            completion?()
            return
        }

        self.delegate?.accountIDSelectorViewWillHideDataSelection()

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

            self?.pickerDataSelection.alpha = 0
        }, completion: { [weak self] _ in

            UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                self?.pickerDataSelection.isHidden = true
                self?.pickerDataSelection.superview?.layoutIfNeeded()
            }, completion: { [weak self] _ in
                self?.pickerDataSelection.alpha = 1
                completion?()
            })
        })
    }

    public func removeCountryPicker(completion: DPAGCompletion?) {
        if self.pickerCountryCode.isHidden {
            completion?()
            return
        }

        self.delegate?.accountIDSelectorViewWillHideCountryCodeSelection()

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

            self?.pickerCountryCode.alpha = 0
        }, completion: { [weak self] _ in

            UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                self?.pickerCountryCode.isHidden = true
                self?.pickerCountryCode.superview?.layoutIfNeeded()
            }, completion: { [weak self] _ in
                self?.pickerCountryCode.alpha = 1
                completion?()
            })
        })
    }

    public func enabledPhoneOnly() {
        self.viewDataSelection.isHidden = true
    }
}

extension DPAGAccountIDSelectorView: UITextFieldDelegate {
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.textFieldActive = textField
        self.delegate?.textFieldDidBeginEditing?(textField)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        self.delegate?.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) ?? true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.delegate?.textFieldShouldReturn?(textField) ?? true
    }
}

extension DPAGAccountIDSelectorView: UIPickerViewDataSource {
    public func numberOfComponents(in _: UIPickerView) -> Int {
        1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        if pickerView == self.pickerCountryCode {
            return DPAGCountryCodes.sharedInstance.countries.count
        }

        return self.showAccountID ? 3 : 2
    }

    public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent _: Int) -> NSAttributedString? {
        if pickerView == self.pickerCountryCode {
            let name = DPAGCountryCodes.sharedInstance.countries[row].name

            return NSAttributedString(string: name ?? "?", attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]])
        }

        let retVal: String

        switch row {
        case 0:
            retVal = self.delegate?.labelPhoneNumberPicker ?? DPAGLocalizedString("registration.createDevice.inputDataLabelPhoneNumber")
        case 1:
            retVal = self.delegate?.labelEMailAddressPicker ?? DPAGLocalizedString("registration.createDevice.inputDataLabelEmail")
        default:
            retVal = self.delegate?.labelSIMSmeIDPicker ?? DPAGLocalizedString("registration.createDevice.inputDataLabelAccountID")
        }

        return NSAttributedString(string: retVal, attributes: [.foregroundColor: DPAGColorProvider.shared[.labelText]])
    }
}

extension DPAGAccountIDSelectorView: UIPickerViewDelegate {
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        if pickerView == self.pickerCountryCode {
            self.updateCountryInfo(index: row)
            return
        }
        self.updateDataSelection(index: DataSelectionType.forIndex(row), withStack: true)
    }
}
