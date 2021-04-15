//
//  DPAGSystemChat.swift
//  SIMSme
//
//  Created by RBU on 28/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import UIKit

struct DPAGSystemChat {
    private init() {}

    private static let kSystemChatPublicKey = "<RSAKeyValue><Modulus>AIRtqFV9UXduW2VFPtw/q7E9jT/0XQb1Wv7hBxpVKpVUxtFI4vpZHNEC6G6S5b8O/XlTNFAusQIFw3+DL55oT5CAVerK7HxtWzlOoccjL0FOECIYTgdio3gXSeqPiAIJIZRxou+HU/5D7fTAxVd9WLUOq9OzDyzgv4K1/oFDFPugBhO3iG+441tA2Pyozh2ujRJeg1zdEEIQoyjFP75biZ5Uga4X729Lv8BESQpnVcRa3CW8OJZ6RVA7N4C8wDQ3gmhM50QFkRxGe2m55+l2o7mJi0VKsqwmyWdcUwFJ5uJkK1BwM4ob9KyDgdxnXUm8MaRtCrPMaV+pwnGfxEh0lJc=</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>"

    @discardableResult
    static func systemChat(in localContext: NSManagedObjectContext) -> SIMSContactIndexEntry? {
        if let systemChat = SIMSContactIndexEntry.findFirst(byGuid: DPAGConstantsGlobal.kSystemChatAccountGuid, in: localContext) {
            return systemChat
        }

        if let systemChat = DPAGApplicationFacade.contactFactory.newModel(accountGuid: DPAGConstantsGlobal.kSystemChatAccountGuid, publicKey: DPAGSystemChat.kSystemChatPublicKey, in: localContext) {
            systemChat.confidenceState = .high
            systemChat[.IS_CONFIRMED] = true
            systemChat.stream?.isConfirmed = true
            systemChat.stream?.lastMessageDate = Date()

            if let image = DPAGImageProvider.shared[.kImageChatSystemLogo] {
                let imageDataStr = image.pngData()?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)

                systemChat[.IMAGE_DATA] = imageDataStr
            }
        }
        return nil
    }

    static func isSystemChat(_ stream: SIMSMessageStream?) -> Bool {
        if let privateStream = stream as? SIMSStream, let contactGuid = privateStream.contactIndexEntry?.guid {
            return contactGuid == DPAGConstantsGlobal.kSystemChatAccountGuid
        }
        return false
    }
}
