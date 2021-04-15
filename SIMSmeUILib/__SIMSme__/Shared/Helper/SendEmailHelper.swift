//
//  SendEmailHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 14.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MessageUI
import SIMSmeCore
import UIKit

struct SendEmailAtttachment {
    var data: Data
    var mimeType: String
    var fileName: String

    static func logFilename() -> String {
        var logFilenameAsDate: String = ""
        let bundle = Bundle.main
        let tz = TimeZone(abbreviation: "UTC")
        let options: ISO8601DateFormatter.Options = [.withFullDate, .withFullTime]
        if let tz = tz {
            logFilenameAsDate = ISO8601DateFormatter.string(from: Date(), timeZone: tz, formatOptions: options).replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: "/", with: "-") + ".log.txt"
        } else {
            logFilenameAsDate = ISO8601DateFormatter.string(from: Date(), timeZone: TimeZone.current, formatOptions: options).replacingOccurrences(of: ":", with: "-").replacingOccurrences(of: "/", with: "-") + ".log.txt"
        }
        if let appBinary = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return appBinary + "_" + logFilenameAsDate
        }
        return logFilenameAsDate
    }
    
    static func getLogAttachment(data: Data?) -> SendEmailAtttachment? {
        guard let data = data else {
            return nil
        }
        return SendEmailAtttachment(data: data, mimeType: "txt", fileName: logFilename())
    }
}

class SendEmailHelper: NSObject {
    func showSendingEmail(fromViewController viewController: UIViewController?, recepients: [String]? = nil, subject: String? = nil, messageBody: String? = nil, attachment: SendEmailAtttachment? = nil, delegate: MFMailComposeViewControllerDelegate? = nil) {
        if DPAGMailComposeViewController.canSendMail() == false {
            return
        }
        let mailComposeViewController = DPAGMailComposeViewController()
        mailComposeViewController.mailComposeDelegate = delegate ?? self
        mailComposeViewController.setToRecipients(recepients)
        if let subject = subject {
            mailComposeViewController.setSubject(subject)
        }
        if let messageBody = messageBody {
            mailComposeViewController.setMessageBody(messageBody, isHTML: false)
        }
        if let attachment = attachment {
            mailComposeViewController.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        }
        viewController?.present(mailComposeViewController, animated: true, completion: nil)
    }
}

extension SendEmailHelper: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith _: MFMailComposeResult, error _: Error?) {
        controller.dismiss(animated: true)
    }
}
