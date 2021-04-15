//
//  SharingHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 28.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

class SharingHelper {
    func showSharing(fromViewController viewController: UIViewController?, items: [Any], sourceView: UIView? = nil, sourceRect: CGRect? = nil, barButtonItem: UIBarButtonItem? = nil) {
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if barButtonItem != nil || sourceRect != nil || sourceView != nil, let presenter = activityController.popoverPresentationController {
            if let barButtonItem = barButtonItem {
                presenter.barButtonItem = barButtonItem
            } else if let sourceView = sourceView {
                presenter.sourceView = sourceView
            } else if let sourceRect = sourceRect {
                presenter.sourceRect = sourceRect
            }
            presenter.permittedArrowDirections = [UIPopoverArrowDirection.up, UIPopoverArrowDirection.down]
        }
        viewController?.present(activityController, animated: true, completion: nil)
    }

    func showSharingForInvitation(fromViewController viewController: UIViewController?, sourceView: UIView? = nil, sourceRect: CGRect? = nil, barButtonItem: UIBarButtonItem? = nil) {
        let message = String(format: DPAGLocalizedString("contacts.smsMessageBody"), DPAGMandant.default.name, DPAGMandant.default.name)
        let urlString = DPAGLocalizedString("contacts.invitationUrlString")
        let messageBody = String(format: message, urlString)
        self.showSharing(fromViewController: viewController, items: [messageBody], sourceView: sourceView, sourceRect: sourceRect, barButtonItem: barButtonItem)
    }
}
