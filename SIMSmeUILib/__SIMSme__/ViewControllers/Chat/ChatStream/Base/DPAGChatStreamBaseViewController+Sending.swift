//
//  DPAG.swift
//  SIMSme
//
//  Created by RBU on 12/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreLocation
import SIMSmeCore
import UIKit

extension DPAGChatBaseViewController: DPAGSendAVViewControllerDelegate, DPAGSendLocationViewControllerDelegate {
    func sendLocationViewController(_: UIViewController & DPAGShowLocationViewControllerDelegate, selectedLocation location: CLLocation, mapSnapshot image: UIImage, address: String) {
        self.sendLocationWithWorker(location, mapSnapshot: image, address: address, sendMessageOptions: self.inputController?.getSendOptions())
    }

    func sendLocationWithWorker(_ location: CLLocation, mapSnapshot image: UIImage, address: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()

        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in

            DPAGApplicationFacade.sendMessageWorker.sendLocation(image, sendMessageOptions: sendOptions, latitude: location, address: address, toRecipients: recipients, response: responseBlock)
        }
    }

    func sendVoiceRec(_ recData: Data?, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        guard let recData = recData, recData.count > 0 else {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "send.voicerec.export.failed"))
            return
        }

        self.sendVoiceDataWithWorker(recData, sendMessageOptions: sendOptions)
    }

    func sendVoiceDataWithWorker(_ recData: Data, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
        let duration = self.inputVoiceController?.audioDuration ?? 0

        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in

            DPAGApplicationFacade.sendMessageWorker.sendVoiceRec(recData, duration: duration, sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock)
            DPAGHelperEx.clearTempFolderFiles(withExtension: "m4a")
        }
    }

    func sendObjects(with _: DPAGSendAVViewControllerProtocol, media mediaArray: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()
        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in
            DPAGApplicationFacade.sendMessageWorker.sendMedias(mediaArray, sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock)
        }
        self.performBlockOnMainThread { [weak self] in
            self?.inputController?.textView?.text = ""
        }
    }

    func sendFileWithWorker(_ fileURL: URL, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()

        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in

            DPAGApplicationFacade.sendMessageWorker.sendFile(fileURL, sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock)
        }
    }

    func sendMediaWithWorker(_ media: DPAGMediaResource, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()

        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in

            DPAGApplicationFacade.sendMessageWorker.sendMedias([media], sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock)
        }
    }

    func sendVCardWithData(_ data: Data, accountGuid: String?, accountID: String?) {
        self.sendVCardDataWithWorker(data, sendMessageOptions: self.inputController?.getSendOptions(), accountGuid: accountGuid, accountID: accountID)
    }

    func sendVCardDataWithWorker(_ data: Data, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?, accountGuid: String?, accountID: String?) {
        let responseBlock = self.sendingDelegate?.sendMessageResponseBlock()

        DPAGChatHelper.sendMessageWithDelegate(self.sendingDelegate) { recipients in

            DPAGApplicationFacade.sendMessageWorker.sendVCard(data, sendMessageOptions: sendOptions, toRecipients: recipients, response: responseBlock, accountGuid: accountGuid, accountID: accountID)
        }
    }

    func resendMessage(msgGuid message: String) {
        DPAGApplicationFacade.sendMessageWorker.resendMessage(msgGuid: message, responseBlock: self.sendingDelegate?.sendMessageResponseBlock())
    }
}
