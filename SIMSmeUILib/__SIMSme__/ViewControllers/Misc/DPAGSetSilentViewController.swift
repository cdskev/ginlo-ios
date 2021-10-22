//
//  DPAGSetSilentViewController.swift
// ginlo
//
//  Created by Yves Hetzer on 20.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGSetSilentViewController: UIViewController {
    @IBOutlet private var viewLabelSilentActive: UIView! {
        didSet {
            self.viewLabelSilentActive.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
        }
    }

    @IBOutlet private var labelSilentActive: UILabel! {
        didSet {
            self.labelSilentActive.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
        }
    }

    @IBOutlet private var labelSilentTimeLeft: UILabel! {
        didSet {
            self.labelSilentTimeLeft.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var labelSilentHeader: UILabel! {
        didSet {
            self.labelSilentHeader.text = DPAGLocalizedString("chat.setsilent.labelSilentHeader")
            self.labelSilentHeader.textColor = DPAGColorProvider.shared[.labelText]
        }
    }

    @IBOutlet private var viewLabelSilentTimeLeft: UIView! {
        didSet {}
    }

    @IBOutlet private var btnOption15: UIButton! {
        didSet {
            self.btnOption15.setTitle(DPAGLocalizedString("chat.setsilent.btnOption15"), for: .normal)
            self.btnOption15.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
        }
    }

    @IBOutlet private var btnOption60: UIButton! {
        didSet {
            self.btnOption60.setTitle(DPAGLocalizedString("chat.setsilent.btnOption60"), for: .normal)
            self.btnOption60.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
        }
    }

    @IBOutlet private var btnOption480: UIButton! {
        didSet {
            self.btnOption480.setTitle(DPAGLocalizedString("chat.setsilent.btnOption480"), for: .normal)
            self.btnOption480.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
        }
    }

    @IBOutlet private var btnOption1440: UIButton! {
        didSet {
            self.btnOption1440.setTitle(DPAGLocalizedString("chat.setsilent.btnOption1440"), for: .normal)
            self.btnOption1440.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
        }
    }

    @IBOutlet var btnOptionInfinite: UIButton! {
        didSet {
            self.btnOptionInfinite.setTitle(DPAGLocalizedString("chat.setsilent.btnOptionPermanent"), for: .normal)
            self.btnOptionInfinite.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
            self.btnOptionInfinite.isHidden = true
        }
    }

    @IBOutlet private var btnResetSilent: UIButton! {
        didSet {
            self.btnResetSilent.setTitle(DPAGLocalizedString("chat.setsilent.btnResetSilent"), for: .normal)
            self.btnResetSilent.configureButtonDestructive()
        }
    }

    @IBOutlet private var labelSilentFooter: UILabel! {
        didSet {
            self.labelSilentFooter.text = DPAGLocalizedString("chat.setsilent.labelSilentFooter")
            self.labelSilentFooter.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSilentFooter.font = UIFont.kFontFootnote
        }
    }

    private weak var setSilentHelper: SetSilentHelper?
    private var silentStateObservation: NSKeyValueObservation?

    init(setSilentHelper: SetSilentHelper?) {
        self.setSilentHelper = setSilentHelper
        super.init(nibName: "DPAGSetSilentViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.silentStateObservation?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("chat.setsilent.title")
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        if setSilentHelper?.hasOptionInfinite ?? false {
            self.btnOptionInfinite.isHidden = false
        }
        self.updateWithNewSilentState()
        self.setupSetSilentHelper()
    }

    @IBAction private func handleOption15(_: Any) {
        self.setSilent(15)
    }

    @IBAction private func handleOption60(_: Any) {
        self.setSilent(60)
    }

    @IBAction private func handleOption480(_: Any) {
        self.setSilent(480)
    }

    @IBAction private func handleButtonOption1440(_: Any) {
        self.setSilent(1_440)
    }

    @IBAction private func handleOptionInfinite(_: Any) {
        self.setSilent(-1)
    }

    private func setupSetSilentHelper() {
        guard let setSilentHelper = self.setSilentHelper else { return }
        self.silentStateObservation = setSilentHelper.observe(\.silentStateChange, options: [.new]) { [weak self] _, _ in
            self?.performBlockOnMainThread {
                self?.updateWithNewSilentState()
            }
        }
    }

    private func setSilent(_ minutes: Int) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
            self.setSilentHelper?.setSilentTill(minutes, response: responseBlock)
        }
    }

    @IBAction private func handleReset(_: Any) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    if let errorMessage = errorMessage {
                        self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                    } else {
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            }
            self.setSilentHelper?.resetSilentTill(response: responseBlock)
        }
    }

    @objc
    private func updateWithNewSilentState() {
        guard let silentState = self.setSilentHelper?.currentSilentState else { return }
        switch silentState {
            case .none:
                self.setupForInactiveSilent()
            case let .date(date):
                self.setupForSilentTill(date: date)
            case .permanent:
                self.setupForPermanentSilent()
        }
    }

    private func setupForInactiveSilent() {
        self.viewLabelSilentTimeLeft.isHidden = true
        self.btnResetSilent.isHidden = true
        self.labelSilentActive.text = DPAGLocalizedString("chat.setsilent.labelSilentInactive")
        self.viewLabelSilentActive.backgroundColor = DPAGColorProvider.shared[.muteInactive]
    }

    private func setupForSilentTill(date: Date) {
        self.viewLabelSilentTimeLeft.isHidden = false
        self.btnResetSilent.isHidden = false
        self.labelSilentActive.text = DPAGLocalizedString("chat.setsilent.labelSilentActive")
        self.viewLabelSilentActive.backgroundColor = DPAGColorProvider.shared[.muteActive]
        let silentTimeFormatter = SilentTimeFormatter()
        self.labelSilentTimeLeft.text = silentTimeFormatter.format(date: date)
    }

    private func setupForPermanentSilent() {
        self.viewLabelSilentTimeLeft.isHidden = false
        self.btnResetSilent.isHidden = false
        self.labelSilentActive.text = DPAGLocalizedString("chat.setsilent.labelSilentActive")
        self.viewLabelSilentActive.backgroundColor = DPAGColorProvider.shared[.muteActive]
        self.labelSilentTimeLeft.text = DPAGLocalizedString("chat.setsilent.btnOptionPermanent")
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.viewLabelSilentActive.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
                self.labelSilentActive.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
                self.labelSilentTimeLeft.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSilentHeader.textColor = DPAGColorProvider.shared[.labelText]
                self.btnOption15.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnOption60.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnOption480.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnOption480.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnOption1440.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.btnOptionInfinite.configureButton(backgroundColor: .clear, textColor: DPAGColorProvider.shared[.buttonTintNoBackground])
                self.labelSilentFooter.textColor = DPAGColorProvider.shared[.labelText]
                self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
                updateWithNewSilentState()
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
