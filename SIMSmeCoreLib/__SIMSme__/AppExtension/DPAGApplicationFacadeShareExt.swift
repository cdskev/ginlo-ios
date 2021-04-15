//
//  DPAGApplicationFacade.swift
//  SIMSme
//
//  Created by RBU on 04/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public class DPAGApplicationFacadeShareExt: NSObject {
    private static let _preferences: DPAGPreferencesShareExtProtocol = DPAGPreferencesShareExt()
    private static let _cache: DPAGCacheShareExtProtocol = DPAGCacheShareExt()
    private static let _messageModelFactory: DPAGMessageModelFactoryShareExtProtocol = DPAGMessageModelFactoryShareExt()
    private static let _server: DPAGServerWorkerShareExtProtocol = DPAGServerWorkerShareExt()
    private static let _service: DPAGHttpServiceShareExtProtocol = DPAGHttpServiceShareExt()
    private static let _sendMessageWorker: DPAGSendMessageWorkerShareExtProtocol = DPAGSendMessageWorkerShareExt()
    private static let _contactsWorker: DPAGContactsWorkerProtocol = DPAGContactsWorker()
    public class var preferences: DPAGPreferencesShareExtProtocol { _preferences }
    public class var cache: DPAGCacheShareExtProtocol { _cache }
    class var messageFactory: DPAGMessageModelFactoryShareExtProtocol { _messageModelFactory }
    public class var server: DPAGServerWorkerShareExtProtocol { _server }
    class var service: DPAGHttpServiceShareExtProtocol { _service }
    public class var sendMessageWorker: DPAGSendMessageWorkerShareExtProtocol { _sendMessageWorker }
    public class var contactsWorker: DPAGContactsWorkerProtocol { _contactsWorker }
}
