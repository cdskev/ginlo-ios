//
//  SharingHelper.swift
//  SIMSmeUILib
//
//  Created by Evgenii Kononenko on 28.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore
import ZXingObjC

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
    var invitationMessage = DPAGLocalizedString("contacts.smsMessageBody")
    var items: [Any] = []

    if let account = DPAGApplicationFacade.cache.account, let qrCodeLink = DPAGApplicationFacade.contactsWorker.qrCodeContent(account: account, version: .v3) {
      do {
        if let image = try self.createQrCode(qrCodeLink, size: CGSize(width: 400, height: 400)) {
          invitationMessage = String(format: invitationMessage, qrCodeLink)
          items.append(invitationMessage)
          items.append(image)
        }
      } catch {
        invitationMessage = String(format: invitationMessage, DPAGLocalizedString("contacts.invitationUrlString"))
        items.append(invitationMessage)
      }
    } else {
      invitationMessage = String(format: invitationMessage, DPAGLocalizedString("contacts.invitationUrlString"))
      items.append(invitationMessage)
    }
    self.showSharing(fromViewController: viewController, items: items, sourceView: sourceView, sourceRect: sourceRect, barButtonItem: barButtonItem)
  }
  
  private func createQrCode(_ qrContent: String, size: CGSize) throws -> UIImage? {
    let writer: ZXMultiFormatWriter = ZXMultiFormatWriter()
    let result: ZXBitMatrix = try writer.encode(qrContent, format: kBarcodeFormatQRCode, width: Int32(size.width), height: Int32(size.height))
    if let image = ZXImage(matrix: result).cgimage {
      let retValImage = UIImage(cgImage: image)
      return retValImage
    }
    return nil
  }
    
}
