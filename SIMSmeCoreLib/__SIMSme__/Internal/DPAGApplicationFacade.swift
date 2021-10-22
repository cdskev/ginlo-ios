//
//  DPAGApplicationFacade.swift
// ginlo
//
//  Created by RBU on 04/11/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MagicalRecord

public class DPAGApplicationFacade: NSObject {
    public static var isResetingAccount = false

    private static var _couplingWorker: DPAGCouplingWorkerProtocol = DPAGCouplingWorker.sharedInstance
    private static var _backupWorker: DPAGBackupWorkerProtocol = DPAGBackupWorker.sharedInstance

    private static var _persistance: DPAGPersistanceProtocol = DPAGPersistance()
    private static var _server: DPAGServerWorkerProtocol = DPAGServerWorker()
    private static var _service: DPAGHttpServiceProtocol = DPAGHttpService()
    private static var _model: DPAGSimsMeModelProtocol = DPAGSimsMeModel()
    private static var _contactFactory: DPAGContactModelFactoryProtocol = DPAGContactModelFactory()
    private static var _messageFactory: DPAGMessageModelFactoryProtocol = DPAGMessageModelFactory()
    private static var _preferences = DPAGMDMPreferences()
    private static var _cache = DPAGCache()
    private static var _sharedContainer = DPAGSharedContainer()
    private static var _sharedContainerSending = DPAGSharedContainerSending()
    private static var _statusWorker: DPAGStatusWorkerProtocol = DPAGStatusWorker()
    private static var _sendMessageWorker: DPAGSendMessageWorkerProtocol = DPAGSendMessageWorker()
    private static var _companyAdressbook: DPAGCompanyAdressbookWorkerProtocol = DPAGCompanyAdressbookWorker()
    private static var _contactsWorker: DPAGContactsWorkerProtocol = DPAGContactsWorker()
    private static var _migrationWorker: DPAGMigrationWorkerProtocol = DPAGMigrationWorker()
    private static var _updateKnownContactsWorker: DPAGUpdateKnownContactsWorkerProtocol = DPAGUpdateKnownContactsWorker()
    private static var _devicesWorker: DPAGDevicesWorkerProtocol = DPAGDevicesWorker()
    private static var _chatRoomWorker: DPAGChatRoomWorkerProtocol = DPAGChatRoomWorker()
    private static var _feedWorker: DPAGFeedWorkerProtocol = DPAGFeedWorker()
    private static var _accountManager: DPAGAccountManagerProtocol = DPAGAccountManager()
    private static var _messageWorker: DPAGMessageWorkerProtocol = DPAGMessageWorker()
    private static var _messageCryptoWorker: DPAGMessageCryptoWorkerProtocol = DPAGMessageCryptoWorker()
    private static var _receiveMessagesWorker: DPAGReceiveMessagesWorkerProtocol = DPAGReceiveMessagesWorker()
    private static var _automaticRegistrationWorker: DPAGAutomaticRegistrationWorkerProtocol = DPAGAutomaticRegistrationWorker()
    private static var _requestWorker: DPAGRequestWorkerProtocol = DPAGRequestWorker()
    private static var _profileWorker: DPAGProfileWorkerProtocol = DPAGProfileWorker()
    private static var _mediaWorker: DPAGMediaWorkerProtocol = DPAGMediaWorker()

    public static var runtimeConfig = DPAGRuntimeConfig()

    public class func reset() {
        _couplingWorker = DPAGCouplingWorker.sharedInstance
        _backupWorker = DPAGBackupWorker.sharedInstance

        // _preferences = DPAGMDMPreferences()

        _preferences.reset()
        _preferences.setDefaults()

        _persistance = DPAGPersistance()
        _service = DPAGHttpService()
        _server = DPAGServerWorker()
        _model = DPAGSimsMeModel()
        _contactFactory = DPAGContactModelFactory()
        _messageFactory = DPAGMessageModelFactory()
        _cache = DPAGCache()
        _sharedContainer = DPAGSharedContainer()
        _sharedContainerSending = DPAGSharedContainerSending()
        _cache.initFetchedResultsController()

        _statusWorker = DPAGStatusWorker()
        _sendMessageWorker = DPAGSendMessageWorker()

        _companyAdressbook = DPAGCompanyAdressbookWorker()
        _contactsWorker = DPAGContactsWorker()
        _migrationWorker = DPAGMigrationWorker()
        _updateKnownContactsWorker = DPAGUpdateKnownContactsWorker()
        _devicesWorker = DPAGDevicesWorker()
        _chatRoomWorker = DPAGChatRoomWorker()
        _feedWorker = DPAGFeedWorker()
        _accountManager = DPAGAccountManager()
        _messageWorker = DPAGMessageWorker()
        _messageCryptoWorker = DPAGMessageCryptoWorker()
        _receiveMessagesWorker = DPAGReceiveMessagesWorker()
        _automaticRegistrationWorker = DPAGAutomaticRegistrationWorker()
        _requestWorker = DPAGRequestWorker()
        _profileWorker = DPAGProfileWorker()
        _mediaWorker = DPAGMediaWorker()

        DPAGCryptoHelper.resetAccountCrypto()
    }

    class var persistance: DPAGPersistanceProtocol { _persistance }
    class var server: DPAGServerWorkerProtocol { _server }
    class var service: DPAGHttpServiceProtocol { _service }
    public class var model: DPAGSimsMeModelProtocol { _model }
    class var contactFactory: DPAGContactModelFactoryProtocol { _contactFactory }
    class var messageFactory: DPAGMessageModelFactoryProtocol { _messageFactory }
    public class var preferences: DPAGMDMPreferences { _preferences }
    public class var cache: DPAGCache { _cache }
    public class var sharedContainer: DPAGSharedContainer { _sharedContainer }
    public class var sharedContainerSending: DPAGSharedContainerSending { _sharedContainerSending }
    public class var statusWorker: DPAGStatusWorkerProtocol { _statusWorker }
    public class var sendMessageWorker: DPAGSendMessageWorkerProtocol { _sendMessageWorker }
    public class var backupWorker: DPAGBackupWorkerProtocol { _backupWorker }
    public class var companyAdressbook: DPAGCompanyAdressbookWorkerProtocol { _companyAdressbook }
    public class var contactsWorker: DPAGContactsWorkerProtocol { _contactsWorker }
    public class var couplingWorker: DPAGCouplingWorkerProtocol { _couplingWorker }
    public class var migrationWorker: DPAGMigrationWorkerProtocol { _migrationWorker }
    public class var updateKnownContactsWorker: DPAGUpdateKnownContactsWorkerProtocol { _updateKnownContactsWorker }
    public class var devicesWorker: DPAGDevicesWorkerProtocol { _devicesWorker }
    public class var chatRoomWorker: DPAGChatRoomWorkerProtocol { _chatRoomWorker }
    public class var feedWorker: DPAGFeedWorkerProtocol { _feedWorker }
    public class var accountManager: DPAGAccountManagerProtocol { _accountManager }
    public class var messageWorker: DPAGMessageWorkerProtocol { _messageWorker }
    class var messageCryptoWorker: DPAGMessageCryptoWorkerProtocol { _messageCryptoWorker }
    public class var receiveMessagesWorker: DPAGReceiveMessagesWorkerProtocol { _receiveMessagesWorker }
    public class var automaticRegistrationWorker: DPAGAutomaticRegistrationWorkerProtocol { _automaticRegistrationWorker }
    public class var requestWorker: DPAGRequestWorkerProtocol { _requestWorker }
    public class var profileWorker: DPAGProfileWorkerProtocol { _profileWorker }
    public class var mediaWorker: DPAGMediaWorkerProtocol { _mediaWorker }

    public class func setupModel() {
        MagicalRecord.setupCoreDataStack(withAutoMigratingSqliteStoreNamed: FILEHELPER_FILE_NAME_DATABASE)
        DPAGApplicationFacade.messageWorker.migrateIllegalMessageSendingStates()
    }

    public class func cleanupModel() {
        MagicalRecord.cleanUp()
    }
}
