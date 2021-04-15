//
//  DPAGSupportViewController.swift
//  SIMSmeUISettingsLib
//
//  Created by Adnan Zildzic on 11.04.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MessageUI
import SIMSmeCore
import UIKit

class DPAGSupportViewController: DPAGViewControllerBackground {
    @IBOutlet var CustomerCareTitleLabel: InfoLabel!
    @IBOutlet var CustomerCareLabel: InfoSubLabel!
    @IBOutlet var CustomerCareEmailButton: UIButton!
    @IBOutlet var SendLogFileTitleLabel: InfoLabel!
    @IBOutlet var SendLogFileLabel: InfoSubLabel!
    @IBOutlet var SendLogFileButton: UIButton!
    @IBOutlet var SendLogFileNoteLabel: InfoSubLabel!

    private let sendEmailHelper = SendEmailHelper()

    init() {
        super.init(nibName: "DPAGSupportViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.support")
        setupViews()
    }

    @IBAction private func sendEmailToSupport(_: Any) {
        sendEmail()
    }

    @IBAction private func sendLogToSupport(_: Any) {
        guard let logsData = DPAGFunctionsGlobal.getLogs() else { return }
        sendEmail(subject: DPAGLocalizedString("settings.support.logs.send.emailSubjectPrivate"), attachment: logsData)
    }

    private func setupViews() {
        CustomerCareTitleLabel.text = DPAGLocalizedString("settings.support.customerCareSection")
        CustomerCareLabel.text = DPAGLocalizedString("settings.support.customerCare.hint")
        let sendEmailButtonTitle = NSAttributedString(string: DPAGLocalizedString("settings.support.customerCare.hint.email"), attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        CustomerCareEmailButton.setAttributedTitle(sendEmailButtonTitle, for: .normal)
        SendLogFileTitleLabel.text = DPAGLocalizedString("settings.support.logsSection")
        SendLogFileLabel.text = DPAGLocalizedString("settings.support.logs.hint")
        SendLogFileNoteLabel.text = DPAGLocalizedString("settings.support.logs.send.note")
        let sendLogButtonTitle = NSAttributedString(string: DPAGLocalizedString("settings.support.logs.send"), attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        SendLogFileButton.setAttributedTitle(sendLogButtonTitle, for: .normal)
    }

    private func sendEmail(subject: String? = nil, attachment: Data? = nil) {
        let emailAttachment = SendEmailAtttachment.getLogAttachment(data: attachment)
        self.sendEmailHelper.showSendingEmail(fromViewController: self.navigationController, recepients: [DPAGLocalizedString("settings.support.customerCare.hint.email")], subject: subject, attachment: emailAttachment)
    }
}
