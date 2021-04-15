//
//  DPAGMessageReceived.swift
//  SIMSmeCore
//
//  Created by RBU on 08.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public class DPAGAesKeyDecrypted: NSObject {
    let aesKey: String
    let iv: String

    public init(aesKey: String, iv: String) {
        self.aesKey = aesKey
        self.iv = iv

        super.init()
    }

    public var dict: [AnyHashable: Any] {
        ["key": self.aesKey, "iv": self.iv]
    }
}

public enum DPAGMessageContentType: Int {
    case plain,
        image,
        video,
        location,
        contact,
        voiceRec,
        file,
        oooStatusMessage,
        textRSS,
        avCallInvitation,
        controlMsgNG

    static func contentType(for typeIn: String?) -> DPAGMessageContentType {
        guard var type = typeIn else {
            return .plain
        }

        type = type.replacingOccurrences(of: "/selfdest", with: "")

        let contentType: DPAGMessageContentType

        switch type {
        case DPAGStrings.JSON.Message.ContentType.PLAIN:
            contentType = .plain

        case DPAGStrings.JSON.Message.ContentType.IMAGE:
            contentType = .image

        case DPAGStrings.JSON.Message.ContentType.VIDEO:
            contentType = .video

        case DPAGStrings.JSON.Message.ContentType.LOCATION:
            contentType = .location

        case DPAGStrings.JSON.Message.ContentType.CONTACT:
            contentType = .contact

        case DPAGStrings.JSON.Message.ContentType.VOICEREC:
            contentType = .voiceRec

        case DPAGStrings.JSON.Message.ContentType.FILE:
            contentType = .file

        case DPAGStrings.JSON.Message.ContentType.OOO_STATUS_MESSAGE:
            contentType = .oooStatusMessage

        case DPAGStrings.JSON.Message.ContentType.TEXT_RSS:
            contentType = .textRSS

        case DPAGStrings.JSON.Message.ContentType.AV_CALL_INVITATION:
            contentType = .avCallInvitation
            
        case DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG:
            contentType = .controlMsgNG
        
        default:
            DPAGLog("setting contentType to plain for unknown '\(type)'", level: .error)
            contentType = .plain
        }

        return contentType
    }

    public var stringRepresentation: String {
        let contentTypeString: String

        switch self {
        case .plain:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.PLAIN
        case .image:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.IMAGE
        case .video:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.VIDEO
        case .location:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.LOCATION
        case .contact:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.CONTACT
        case .voiceRec:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.VOICEREC
        case .file:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.FILE
        case .oooStatusMessage:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.OOO_STATUS_MESSAGE
        case .textRSS:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.TEXT_RSS
        case .avCallInvitation:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.AV_CALL_INVITATION
        case .controlMsgNG:
            contentTypeString = DPAGStrings.JSON.Message.ContentType.CONTROL_MSG_NG
        }
        return contentTypeString
    }
}

public class DPAGCitationContent {
    public let fromGuid: String
    public let toGuid: String
    public let msgGuid: String
    public let nickName: String?
    public let dateSend: Date
    public let contentType: DPAGMessageContentType

    public let content: String?
    public let contentDesc: String?

    init?(dict: [AnyHashable: Any]) {
        guard let fromGuid = dict[DPAGStrings.JSON.MessageCitation.FROM_GUID] as? String, let toGuid = dict[DPAGStrings.JSON.MessageCitation.TO_GUID] as? String, let msgGuid = dict[DPAGStrings.JSON.MessageCitation.MSG_GUID] as? String else { return nil }
        guard let dateSendStr = dict[SIMS_DATESEND] as? String, let dateSend = DPAGFormatter.dateServer.date(from: dateSendStr) else { return nil }
        guard let contentTypeStr = dict[DPAGStrings.JSON.MessageCitation.CONTENT_TYPE] as? String else { return nil }

        self.fromGuid = fromGuid
        self.toGuid = toGuid
        self.msgGuid = msgGuid
        self.nickName = dict[DPAGStrings.JSON.MessageCitation.NICKNAME] as? String
        self.dateSend = dateSend
        self.contentType = DPAGMessageContentType.contentType(for: contentTypeStr)
        self.content = dict[DPAGStrings.JSON.MessageCitation.CONTENT] as? String
        self.contentDesc = dict[DPAGStrings.JSON.MessageCitation.CONTENT_DESCRIPTION] as? String
    }
}

struct DPAGMessageDictionary {
    private(set) var content: String?
    private(set) var contentDescription: String?
    private(set) var contentType: String = DPAGStrings.JSON.Message.ContentType.PLAIN
    private(set) var destructionCountDown: Int?
    private(set) var destructionDate: Date?
    private(set) var imagePreviewData: Data?
    private(set) var citationContent: DPAGCitationContent?

    private(set) var phone: String?
    private(set) var nick: String?
    private(set) var profilKey: String?

    private(set) var channelSection: String?

    private(set) var vcardAccountID: String?
    private(set) var vcardAccountGuid: String?

    private(set) var additionalData = DPAGMessageDictionaryAdditionalData()

    private(set) var unknownContent: [AnyHashable: Any] = [:]

    fileprivate static var formatter: DateFormatter = {
        let df = DateFormatter()

        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZ"

        return df
    }()

    init(dict: [String: Any]) {
        dict.forEach { key, obj in

            switch key {
            case DPAGStrings.JSON.Message.CONTENT_TYPE:
                self.contentType = obj is NSNull ? DPAGStrings.JSON.Message.ContentType.PLAIN : ((obj as? String) ?? DPAGStrings.JSON.Message.ContentType.PLAIN)
            case DPAGStrings.JSON.Message.CONTENT_TYPE_2:
                self.contentType = obj is NSNull ? DPAGStrings.JSON.Message.ContentType.PLAIN : ((obj as? String) ?? DPAGStrings.JSON.Message.ContentType.PLAIN)
            case DPAGStrings.JSON.Message.DESTRUCTION_DATE:
                if obj is NSNull {
                    self.destructionDate = Date()
                } else if let destructionDateStr = obj as? String, let destructionDate = DPAGMessageDictionary.formatter.date(from: destructionDateStr) {
                    self.destructionDate = destructionDate
                }
            case DPAGStrings.JSON.Message.DESTRUCTION_COUNTDOWN:
                if obj is NSNull {
                    self.destructionCountDown = 1
                } else if let num = obj as? NSNumber {
                    self.destructionCountDown = num.intValue
                } else if let destructionCountdownStr = obj as? String, let destructionCountdown = Int(destructionCountdownStr) {
                    self.destructionCountDown = destructionCountdown
                }
            case DPAGStrings.JSON.Message.PHONE:
                self.phone = obj as? String
            case DPAGStrings.JSON.Message.NICKNAME:
                self.nick = obj as? String
            case DPAGStrings.JSON.Message.CONTENT:
                self.content = obj as? String
            case DPAGStrings.JSON.Message.CONTENT_DESCRIPTION:
                self.contentDescription = obj as? String
            case DPAGStrings.JSON.Message.VCARDACCOUNTGUID:
                self.vcardAccountGuid = obj as? String
            case DPAGStrings.JSON.Message.VCARDACCOUNTID:
                self.vcardAccountID = obj as? String
            case DPAGStrings.JSON.Message.ACCOUNT_PROFIL_KEY:
                self.profilKey = obj as? String
            case DPAGStrings.JSON.Message.AdditionalData.FILE_NAME:
                self.additionalData.fileName = obj as? String
            case DPAGStrings.JSON.Message.AdditionalData.FILE_SIZE:
                self.additionalData.fileSize = obj as? String
                self.additionalData.fileSizeNum = obj as? NSNumber
            case DPAGStrings.JSON.Message.AdditionalData.FILE_TYPE:
                self.additionalData.fileType = obj as? String
            case DPAGStrings.JSON.Message.AdditionalData.ENCODING_VERSION:
                self.additionalData.encodingVersion = obj as? String
                self.additionalData.encodingVersionNum = (obj as? NSNumber)?.intValue
            case DPAGStrings.JSON.Message.IMAGE_PREVIEW:
                if let previewDict = obj as? [AnyHashable: Any], let previewContent = previewDict[DPAGStrings.JSON.Message.ImagePreview.CONTENT] as? String {
                    let imageData = Data(base64Encoded: previewContent, options: .ignoreUnknownCharacters)

                    self.imagePreviewData = imageData
                }
            case DPAGStrings.JSON.Channel.SECTION:
                self.channelSection = obj as? String
            case "citation":
                if let citationDict = obj as? [AnyHashable: Any] {
                    self.citationContent = DPAGCitationContent(dict: citationDict)
                }
            default:
                self.unknownContent[key] = obj
            }
        }
    }
}

struct DPAGMessageReceivedListItem: Decodable {
    let messageConfirmSend: DPAGMessageReceivedConfirmTimedMessageSend?
    let messagePrivate: DPAGMessageReceivedPrivate?
    let messagePrivateInternal: DPAGMessageReceivedPrivateInternal?
    let messageInternal: DPAGMessageReceivedInternal?
    let messageGroup: DPAGMessageReceivedGroup?
    let messageGroupInvitation: DPAGMessageReceivedGroupInvitation?
    let messageChannel: DPAGMessageReceivedChannel?
    let messageService: DPAGMessageReceivedService?

    enum CodingKeys: String, CodingKey {
        case messageConfirmSend = "ConfirmMessageSend"
        case messagePrivate = "PrivateMessage"
        case messagePrivateInternal = "PrivateInternalMessage"
        case messageInternal = "InternalMessage"
        case messageGroup = "GroupMessage"
        case messageGroupInvitation = "GroupInvMessage"
        case messageChannel = "ChannelMessage"
        case messageService = "ServiceMessage"
    }
}

enum DPAGMessageReceivedError: Error {
    case errSignatureNotFound
    case errToDictNotFound
    case errFromDictNotFound
    case errGroupInvitationNotDecryptable
    case errGroupInvitationContentMissing
    case errSignatureNotValid
}

enum DPAGMessageReceivedType {
    case unknown,
        `private`,
        group,
        groupInvitation,
        privateInternal,
        `internal`,
        confirmTimedMessageSent,
        channel
}

class DPAGMessageReceivedBase: DPAGMessageReceivedCore {
    struct TempDeviceInfo: Decodable {
        let guid: String
        let key: String
        let key2: String?
    }

    fileprivate struct ToDict: Decodable {
        let key: String
        let key2: String?
        let tempDevice: TempDeviceInfo?
    }

    fileprivate struct FromDict: Decodable {
        let key: String
        let key2: String?
        let tempDevice: TempDeviceInfo?
    }

    struct AccountInfo {
        let accountGuid: String
        let encAesKey: String
        let encAesKey2: String?
        let tempDevice: TempDeviceInfo?
    }

    let data: String

    let dateSend: Date

    let senderId: String?
    let features: String?
    let attachments: [String]?
    let dateDownloaded: String?

    let pushInfo: String?

    private enum CodingKeys: String, CodingKey {
        case data
        case dateSend = "datesend"
        case senderId
        case features
        case attachments = "attachment"
        case dateDownloaded = "datedownloaded"
        case attachmentGuids
        case pushInfo
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.data = try container.decode(String.self, forKey: .data)

        guard let dateSend = DPAGFormatter.date.date(from: try container.decode(String.self, forKey: .dateSend)) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date format")

            throw DecodingError.typeMismatch(Date.self, context)
        }

        self.dateSend = dateSend

        self.senderId = try container.decodeIfPresent(String.self, forKey: .senderId)
        self.features = try container.decodeIfPresent(String.self, forKey: .dateDownloaded)
        self.dateDownloaded = try container.decodeIfPresent(String.self, forKey: .dateDownloaded)

        self.pushInfo = try container.decodeIfPresent(String.self, forKey: .pushInfo)

        let attachments = try container.decodeIfPresent([String].self, forKey: .attachments)

        if let attachments = attachments, self.senderId != nil {
            if AppConfig.isShareExtension {
                self.attachments = attachments
            } else if AppConfig.isNotificationExtension {
                self.attachments = attachments
            } else {
                var attachmentGuids: [String] = []

                for attachment in attachments {
                    if attachment.hasSuffix("}") {
                        attachmentGuids.append(attachment)
                    } else {
                        let attachmentArrayGuids: [String]? = try container.decodeIfPresent([String].self, forKey: .attachmentGuids)

                        var guid: String? = attachmentArrayGuids?.first
                        if guid == nil {
                            guid = DPAGFunctionsGlobal.uuid(prefix: .none)
                        }
                        if let guid = guid {
                            DPAGAttachmentWorker.saveEncryptedAttachment(attachment, forGuid: guid)

                            attachmentGuids.append(guid)
                        }
                    }
                }
                self.attachments = attachmentGuids
            }
        } else {
            self.attachments = attachments
        }

        try super.init(from: decoder)
    }
}

class DPAGMessageReceivedCore: Decodable {
    let guid: String

    var messageType: DPAGMessageReceivedType = .unknown

    private enum CodingKeys: String, CodingKey {
        case guid
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.guid = try container.decode(String.self, forKey: .guid)
    }
}

class DPAGMessageReceivedPrivate: DPAGMessageReceivedBase {
    let toAccountInfo: AccountInfo
    let fromAccountInfo: AccountInfo

    let aesKey2IV: String?

    let dataSignature: DPAGMessageSignaturePrivate?
    let dataSignature256: DPAGMessageSignaturePrivate?
    let dataSignatureTemp256: DPAGMessageSignaturePrivate?

    let messagePriorityHigh: Bool

    let contentTyp: String?

    private enum CodingKeys: String, CodingKey {
        case to
        case from
        case key2IV = "key2-iv"
        case signature
        case signature256 = "signature-sha256"
        case signatureTemp256 = "signature-temp256"
        case messageType
        case importance
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let toDicts = try container.decode([[String: ToDict]].self, forKey: .to)

        guard let toDict = toDicts.first, let toAccountGuid = toDict.keys.first, let toKeyDict = toDict[toAccountGuid] else {
            throw DPAGMessageReceivedError.errToDictNotFound
        }

        self.toAccountInfo = AccountInfo(accountGuid: toAccountGuid, encAesKey: toKeyDict.key, encAesKey2: toKeyDict.key2, tempDevice: toKeyDict.tempDevice)

        let fromDict = try container.decode([String: FromDict].self, forKey: .from)

        if let fromAccountGuid = fromDict.keys.first, let fromKeyDict = fromDict[fromAccountGuid] {
            self.fromAccountInfo = AccountInfo(accountGuid: fromAccountGuid, encAesKey: fromKeyDict.key, encAesKey2: fromKeyDict.key2, tempDevice: fromKeyDict.tempDevice)
        } else {
            throw DPAGMessageReceivedError.errFromDictNotFound
        }

        self.aesKey2IV = try container.decodeIfPresent(String.self, forKey: .key2IV)

        if let dataSignature = try? container.decodeIfPresent(DPAGMessageSignaturePrivate.self, forKey: .signature) {
            self.dataSignature = dataSignature
        } else {
            self.dataSignature = nil
        }
        if let dataSignature256 = try? container.decodeIfPresent(DPAGMessageSignaturePrivate.self, forKey: .signature256) {
            self.dataSignature256 = dataSignature256
        } else {
            self.dataSignature256 = nil
        }
        if let dataSignatureTemp256 = try? container.decodeIfPresent(DPAGMessageSignaturePrivate.self, forKey: .signatureTemp256) {
            self.dataSignatureTemp256 = dataSignatureTemp256
        } else {
            self.dataSignatureTemp256 = nil
        }

        self.contentTyp = try container.decodeIfPresent(String.self, forKey: .messageType)

        self.messagePriorityHigh = (try container.decodeIfPresent(String.self, forKey: .importance)) == "high"

        try super.init(from: decoder)

        self.messageType = .private
    }
}

class DPAGMessageReceivedPrivateInternal: DPAGMessageReceivedCore {
    private struct ToDict: Decodable {
        let key: String
    }

    private struct FromDict: Decodable {
        let key: String
    }

    struct AccountInfo {
        let accountGuid: String
        let encAesKey: String
    }

    let data: String

    let dateSend: Date

    let toAccountInfo: AccountInfo
    let fromAccountInfo: AccountInfo

    private enum CodingKeys: String, CodingKey {
        case guid
        case data
        case dateSend = "datesend"
        case to
        case from
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.data = try container.decode(String.self, forKey: .data)

        guard let dateSend = DPAGFormatter.date.date(from: try container.decode(String.self, forKey: .dateSend)) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date format")

            throw DecodingError.typeMismatch(Date.self, context)
        }

        self.dateSend = dateSend

        let toDicts = try container.decode([[String: ToDict]].self, forKey: .to)

        guard let toDict = toDicts.first, let toAccountGuid = toDict.keys.first, let toKeyDict = toDict[toAccountGuid] else {
            throw DPAGMessageReceivedError.errToDictNotFound
        }

        self.toAccountInfo = AccountInfo(accountGuid: toAccountGuid, encAesKey: toKeyDict.key)

        let fromDict = try container.decode([String: FromDict].self, forKey: .from)

        if let fromAccountGuid = fromDict.keys.first, let fromKeyDict = fromDict[fromAccountGuid] {
            self.fromAccountInfo = AccountInfo(accountGuid: fromAccountGuid, encAesKey: fromKeyDict.key)
        } else {
            throw DPAGMessageReceivedError.errFromDictNotFound
        }

        try super.init(from: decoder)

        self.messageType = .privateInternal
    }

    private var _contentDecrypted: DPAGMessageReceivedPrivateInternalDecrypted?
    var contentDecrypted: DPAGMessageReceivedPrivateInternalDecrypted? {
        if let contentAlreadyDecrypted = _contentDecrypted {
            return contentAlreadyDecrypted
        }

        guard let decryptedContentObject = DPAGApplicationFacade.messageCryptoWorker.decryptPrivateInternalMessage(data: self.data, encAesKey: self.toAccountInfo.encAesKey) else {
            return nil
        }

        guard let contentDecrypted = DPAGMessageReceivedPrivateInternalDecrypted(messageDict: decryptedContentObject) else {
            return nil
        }

        _contentDecrypted = contentDecrypted

        return contentDecrypted
    }
}

class DPAGMessageReceivedPrivateInternalDecrypted {
    let contentValue: Any?
    let contentType: String
    let contentDict: [AnyHashable: Any]?

    let messageDict: DPAGMessageDictionary

    init?(messageDict: DPAGMessageDictionary) {
        self.messageDict = messageDict

        if let contentString = messageDict.content, let contentData = contentString.data(using: .utf8) {
            var jsonData: [AnyHashable: Any]?

            do {
                jsonData = try JSONSerialization.jsonObject(with: contentData, options: .allowFragments) as? [AnyHashable: Any]
            } catch {
                return nil
            }

            guard let jsonDataDict = jsonData else { return nil }

            guard let contentValue = jsonDataDict[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.CONTENT], let contentType = (jsonDataDict[DPAGStrings.Server.MessageReceivedPrivateInternalDecrypted.Response.CONTENT_TYPE] ?? messageDict.contentType) as? String else {
                return nil
            }

            self.contentValue = contentValue
            self.contentType = contentType
            self.contentDict = jsonDataDict
        } else {
            self.contentType = messageDict.contentType
            self.contentValue = nil
            self.contentDict = nil
        }
    }
}

struct DPAGMessageReceivedRecipient: Decodable {
    let contactGuid: String
    let sendsReadConfirmation: String
    var dateRead: String?
    var dateDownloaded: String?

    private enum CodingKeys: String, CodingKey {
        case item = "Receiver"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let item = try container.decode(DPAGMessageReceivedRecipientItem.self, forKey: .item)

        self.contactGuid = item.contactGuid
        self.sendsReadConfirmation = item.sendsReadConfirmation
        self.dateRead = item.dateRead
        self.dateDownloaded = item.dateDownloaded
    }

    struct DPAGMessageReceivedRecipientItem: Decodable {
        let contactGuid: String
        let sendsReadConfirmation: String
        let dateRead: String?
        let dateDownloaded: String?

        private enum CodingKeys: String, CodingKey {
            case contactGuid = "guid",
                sendsReadConfirmation,
                dateRead,
                dateDownloaded
        }
    }
}

class DPAGMessageReceivedGroup: DPAGMessageReceivedBase {
    let toAccountGuid: String

    let fromAccountInfo: AccountInfo

    let contentTyp: String?

    let dataSignature: DPAGMessageSignatureGroup?
    let dataSignature256: DPAGMessageSignatureGroup?
    let dataSignatureTemp256: DPAGMessageSignatureGroup?

    let recipients: [DPAGMessageReceivedRecipient]?

    let messagePriorityHigh: Bool

    private enum CodingKeys: String, CodingKey {
        case to
        case from
        case key2IV = "key2-iv"
        case signature
        case signature256 = "signature-sha256"
        case signatureTemp256 = "signature-temp256"
        case messageType
        case importance
        case receiver
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.toAccountGuid = try container.decode(String.self, forKey: .to)

        self.contentTyp = try container.decodeIfPresent(String.self, forKey: .messageType)

        let fromDict = try container.decode([String: FromDict].self, forKey: .from)

        if let fromAccountGuid = fromDict.keys.first, let fromKeyDict = fromDict[fromAccountGuid] {
            self.fromAccountInfo = AccountInfo(accountGuid: fromAccountGuid, encAesKey: fromKeyDict.key, encAesKey2: fromKeyDict.key2, tempDevice: fromKeyDict.tempDevice)
        } else {
            throw DPAGMessageReceivedError.errFromDictNotFound
        }

        if let dataSignature = try? container.decodeIfPresent(DPAGMessageSignatureGroup.self, forKey: .signature) {
            self.dataSignature = dataSignature

            if let dataSignature256 = try? container.decodeIfPresent(DPAGMessageSignatureGroup.self, forKey: .signature256) {
                self.dataSignature256 = dataSignature256
            } else {
                self.dataSignature256 = nil
            }

            if let dataSignatureTemp256 = try? container.decodeIfPresent(DPAGMessageSignatureGroup.self, forKey: .signatureTemp256) {
                self.dataSignatureTemp256 = dataSignatureTemp256
            } else {
                self.dataSignatureTemp256 = nil
            }
        } else {
            guard self.contentTyp == DPAGMessageContentType.textRSS.stringRepresentation else {
                throw DPAGMessageReceivedError.errSignatureNotFound
            }

            self.dataSignature = nil
            self.dataSignature256 = nil
            self.dataSignatureTemp256 = nil
        }

        self.recipients = try container.decodeIfPresent([DPAGMessageReceivedRecipient].self, forKey: .receiver)

        self.messagePriorityHigh = (try container.decodeIfPresent(String.self, forKey: .importance)) == "high"

        try super.init(from: decoder)

        self.messageType = .group
    }
}

class DPAGMessageReceivedChannel: DPAGMessageReceivedBase {
    let toAccountGuid: String

    private enum CodingKeys: String, CodingKey {
        case to
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.toAccountGuid = try container.decode(String.self, forKey: .to)

        try super.init(from: decoder)

        self.messageType = .channel
    }
}

class DPAGMessageReceivedService: DPAGMessageReceivedChannel {}

class DPAGMessageReceivedConfirmTimedMessageSend: DPAGMessageReceivedCore {
    let dateSend: Date

    let fromGuid: String
    let toGuid: String
    let sendGuid: String

    let notSent: [String]?
    let recipients: [DPAGMessageReceivedRecipient]?

    private enum CodingKeys: String, CodingKey {
        case dateSend = "datesend",
            fromGuid = "from",
            toGuid = "to",
            sendGuid,
            notSent = "not-send",
            recipients = "receiver"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let dateSend = DPAGFormatter.date.date(from: try container.decode(String.self, forKey: .dateSend)) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date format")

            throw DecodingError.typeMismatch(Date.self, context)
        }

        self.dateSend = dateSend

        self.fromGuid = try container.decode(String.self, forKey: .fromGuid)
        self.toGuid = try container.decode(String.self, forKey: .toGuid)
        self.sendGuid = try container.decode(String.self, forKey: .sendGuid)

        self.notSent = try container.decodeIfPresent([String].self, forKey: .notSent)
        self.recipients = try container.decodeIfPresent([DPAGMessageReceivedRecipient].self, forKey: .recipients)

        try super.init(from: decoder)

        self.messageType = .confirmTimedMessageSent
    }
}

struct DPAGMessageReceivedInternalData: Decodable {}

class DPAGMessageReceivedInternal: DPAGMessageReceivedCore {
    enum MessageType {
        case unknown
        case confirmDownload
    }

    let from: String
    let to: String
    let dateSend: Date
    let features: String?

    private enum CodingKeys: String, CodingKey {
        case guid,
            dateSend = "datesend",
            from,
            to,
            features,
            data
    }

    struct ConfirmDownload: Decodable {
        let guids: [String]

        private enum CodingKeys: String, CodingKey {
            case guids = "confirmDownloaded-V1"
        }
    }

    struct ConfirmRead: Decodable {
        let guids: [String]

        private enum CodingKeys: String, CodingKey {
            case guids = "confirmRead-V1"
        }
    }

    struct ConfirmDeleted: Decodable {
        let guids: [String]

        private enum CodingKeys: String, CodingKey {
            case guids = "confirmDeleted-V1"
        }
    }

    struct ConfirmMessageSend: Decodable {
        let item: ConfirmMessageSendItem

        private enum CodingKeys: String, CodingKey {
            case item = "ConfirmMessageSend"
        }

        struct ConfirmMessageSendItem: Decodable {
            let guid: String
            let dateSent: String

            var attachmentGuids: [String]?
            var notSent: [String]?
            var recipients: [DPAGMessageReceivedRecipient]?

            private enum CodingKeys: String, CodingKey {
                case guid,
                    attachmentGuids = "attachments",
                    dateSent = "datesend",
                    notSent = "not-send",
                    recipients = "receiver"
            }
        }
    }

    struct AccountRegistration: Decodable {
        let item: AccountRegistrationItem

        private enum CodingKeys: String, CodingKey {
            case item = "alertAccountRegistration-V1"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(AccountRegistrationItem.self, forKey: .item)
        }

        struct AccountRegistrationItem: Decodable {
            let guid: String
            let accountGuid: String
        }
    }

    struct GroupRemoved: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "removeChatRoom-V1"
        }
    }

    struct ChannelRemoved: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "removeChannel-V1"
        }
    }

    struct ProfilInfoChanged: Decodable {
        let accountGuid: String

        private enum CodingKeys: String, CodingKey {
            case accountGuid = "profilInfoChanged-V1"
        }
    }

    struct GroupInfoChanged: Decodable {
        let groupGuid: String

        private enum CodingKeys: String, CodingKey {
            case groupGuid = "groupInfoChanged-V1"
        }
    }

    struct GroupOwnerChanged: Decodable {
        let item: GroupOwnerChangedItem

        private enum CodingKeys: String, CodingKey {
            case item = "changeOwner-V1"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(GroupOwnerChangedItem.self, forKey: .item)
        }

        struct GroupOwnerChangedItem: Decodable {
            let roomGuid: String
            let accountGuid: String
        }
    }

    class GroupMessageContent: Decodable {
        let roomGuid: String
        let guids: [String]
        let senderGuid: String
        let senderNick: String?

        private enum CodingKeys: String, CodingKey {
            case roomGuid = "GroupGuid"
            case guids = "Content"
            case senderGuid = "SenderGuid"
            case senderNick = "NickName"
        }
    }

    struct GroupMembersNew: Decodable {
        let item: GroupMembersNewItem

        private enum CodingKeys: String, CodingKey {
            case item = "model/newmember"
            case items = "model/newmembers"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let item = try container.decodeIfPresent(GroupMembersNewItem.self, forKey: .items) {
                self.item = item
            } else {
                self.item = try container.decode(GroupMembersNewItem.self, forKey: .item)
            }
        }

        class GroupMembersNewItem: GroupMessageContent {}
    }

    struct GroupMembersRemoved: Decodable {
        let item: GroupMembersRemovedItem

        private enum CodingKeys: String, CodingKey {
            case item = "model/removedmembers"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(GroupMembersRemovedItem.self, forKey: .item)
        }

        class GroupMembersRemovedItem: GroupMessageContent {}
    }

    struct GroupMembersInvited: Decodable {
        let item: GroupMembersInvitedItem

        private enum CodingKeys: String, CodingKey {
            case item = "model/invitemembers"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(GroupMembersInvitedItem.self, forKey: .item)
        }

        class GroupMembersInvitedItem: GroupMessageContent {}
    }

    struct GroupMembersAdminGranted: Decodable {
        let item: GroupMembersAdminGrantedItem

        private enum CodingKeys: String, CodingKey {
            case item = "model/newadmins"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(GroupMembersAdminGrantedItem.self, forKey: .item)
        }

        class GroupMembersAdminGrantedItem: GroupMessageContent {}
    }

    struct GroupMembersAdminRevoked: Decodable {
        let item: GroupMembersAdminRevokedItem

        private enum CodingKeys: String, CodingKey {
            case item = "model/revokeadmins"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(GroupMembersAdminRevokedItem.self, forKey: .item)
        }

        class GroupMembersAdminRevokedItem: GroupMessageContent {}
    }

    struct ConfigVersionChanged: Decodable {
        let configDetails: [String: String?]?

        private enum CodingKeys: String, CodingKey {
            case objectKey = "configVersions-V1"
            case configDetails
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            _ = try container.decode(String.self, forKey: .objectKey)
            self.configDetails = try container.decodeIfPresent([String: String?].self, forKey: .configDetails)
        }
    }

    struct DeviceCreated: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "device/created-V1"
        }
    }

    struct DeviceRemoved: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "device/removed-V1"
        }
    }

    struct PhoneNumberRevoked: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "model/revokePhone"
        }
    }

    struct EmailAddressRevoked: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "model/revokeEmailAddress"
        }
    }

    struct ChatDeleted: Decodable {
        let guid: String

        private enum CodingKeys: String, CodingKey {
            case guid = "confirmChatDeleted-V1"
        }
    }

    struct UpdateAccountId: Decodable {
        let accountId: String

        private enum CodingKeys: String, CodingKey {
            case accountId = "account/updateAccountID"
        }
    }

    struct OooMessage: Decodable {
        let item: OooMessageItem

        private enum CodingKeys: String, CodingKey {
            case item = "account/oooStatus"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.item = try container.decode(OooMessageItem.self, forKey: .item)
        }

        struct OooMessageItem: Decodable {
            let statusText: String?
            let statusTextIV: String?
            let statusState: String?
            let statusValid: String?
        }
    }

    let confirmDownload: ConfirmDownload?
    let confirmRead: ConfirmRead?
    let confirmDeleted: ConfirmDeleted?
    let accountRegistration: AccountRegistration.AccountRegistrationItem?
    let groupRemoved: GroupRemoved?
    let channelRemoved: ChannelRemoved?
    let profilInfoChanged: ProfilInfoChanged?
    let groupInfoChanged: GroupInfoChanged?
    let groupOwnerChanged: GroupOwnerChanged.GroupOwnerChangedItem?
    let groupMembersNew: GroupMembersNew.GroupMembersNewItem?
    let groupMembersRemoved: GroupMembersRemoved.GroupMembersRemovedItem?
    let groupMembersInvited: GroupMembersInvited.GroupMembersInvitedItem?
    let groupMembersAdminGranted: GroupMembersAdminGranted.GroupMembersAdminGrantedItem?
    let groupMembersAdminRevoked: GroupMembersAdminRevoked.GroupMembersAdminRevokedItem?
    let configVersionChanged: ConfigVersionChanged?
    let confirmMessageSend: ConfirmMessageSend.ConfirmMessageSendItem?
    let deviceCreated: DeviceCreated?
    let deviceRemoved: DeviceRemoved?
    let phoneNumberRevoked: PhoneNumberRevoked?
    let emailAddressRevoked: EmailAddressRevoked?
    let chatDeleted: ChatDeleted?
    let updateAccountId: UpdateAccountId?
    let oooMessage: OooMessage.OooMessageItem?

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.from = try container.decodeIfPresent(String.self, forKey: .from) ?? DPAGConstantsGlobal.kSystemChatAccountGuid
        self.to = try container.decode(String.self, forKey: .to)

        guard let dateSend = DPAGFormatter.date.date(from: try container.decode(String.self, forKey: .dateSend)) else {
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date format")

            throw DecodingError.typeMismatch(Date.self, context)
        }

        self.dateSend = dateSend

        self.features = try container.decodeIfPresent(String.self, forKey: .features)

        self.confirmDownload = container.decodeIfPresentNoThrow(ConfirmDownload.self, forKey: .data)
        self.confirmRead = container.decodeIfPresentNoThrow(ConfirmRead.self, forKey: .data)
        self.confirmDeleted = container.decodeIfPresentNoThrow(ConfirmDeleted.self, forKey: .data)

        self.accountRegistration = container.decodeIfPresentNoThrow(AccountRegistration.self, forKey: .data)?.item

        self.groupRemoved = container.decodeIfPresentNoThrow(GroupRemoved.self, forKey: .data)
        self.channelRemoved = container.decodeIfPresentNoThrow(ChannelRemoved.self, forKey: .data)

        self.profilInfoChanged = container.decodeIfPresentNoThrow(ProfilInfoChanged.self, forKey: .data)
        self.groupInfoChanged = container.decodeIfPresentNoThrow(GroupInfoChanged.self, forKey: .data)

        self.groupOwnerChanged = container.decodeIfPresentNoThrow(GroupOwnerChanged.self, forKey: .data)?.item

        self.groupMembersNew = container.decodeIfPresentNoThrow(GroupMembersNew.self, forKey: .data)?.item

        self.groupMembersRemoved = container.decodeIfPresentNoThrow(GroupMembersRemoved.self, forKey: .data)?.item

        self.groupMembersInvited = container.decodeIfPresentNoThrow(GroupMembersInvited.self, forKey: .data)?.item

        self.groupMembersAdminGranted = container.decodeIfPresentNoThrow(GroupMembersAdminGranted.self, forKey: .data)?.item

        self.groupMembersAdminRevoked = container.decodeIfPresentNoThrow(GroupMembersAdminRevoked.self, forKey: .data)?.item

        self.configVersionChanged = container.decodeIfPresentNoThrow(ConfigVersionChanged.self, forKey: .data)

        self.confirmMessageSend = container.decodeIfPresentNoThrow(ConfirmMessageSend.self, forKey: .data)?.item

        self.deviceCreated = container.decodeIfPresentNoThrow(DeviceCreated.self, forKey: .data)
        self.deviceRemoved = container.decodeIfPresentNoThrow(DeviceRemoved.self, forKey: .data)

        self.phoneNumberRevoked = container.decodeIfPresentNoThrow(PhoneNumberRevoked.self, forKey: .data)
        self.emailAddressRevoked = container.decodeIfPresentNoThrow(EmailAddressRevoked.self, forKey: .data)

        self.chatDeleted = container.decodeIfPresentNoThrow(ChatDeleted.self, forKey: .data)
        self.updateAccountId = container.decodeIfPresentNoThrow(UpdateAccountId.self, forKey: .data)

        self.oooMessage = container.decodeIfPresentNoThrow(OooMessage.self, forKey: .data)?.item

        try super.init(from: decoder)

        self.messageType = .internal
    }
}

struct DPAGMessageReceivedGroupInvitationDecrypted {
    let groupName: String
    let groupGuid: String
    let groupAesKey: String?
    let groupType: DPAGGroupType

    let groupImageEncoded: String?
}

class DPAGMessageReceivedGroupInvitation: DPAGMessageReceivedPrivate {
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)

        self.messageType = .groupInvitation
    }

    private var _contentDecrypted: DPAGMessageReceivedGroupInvitationDecrypted?

    func contentDecrypted() throws -> DPAGMessageReceivedGroupInvitationDecrypted {
        if let contentAlreadyDecrypted = _contentDecrypted {
            return contentAlreadyDecrypted
        }
        var toAccountDecAesKey = try DPAGApplicationFacade.messageCryptoWorker.decryptAesKey(self.toAccountInfo.encAesKey)
        guard let dataDecrypted = DPAGApplicationFacade.messageCryptoWorker.decryptMessageDict(self.data, encAesKey: self.toAccountInfo.encAesKey, encAesKey2: nil, aesKeyIV: nil) else {
            throw DPAGMessageReceivedError.errGroupInvitationNotDecryptable
        }
        var groupImageEncoded = dataDecrypted.unknownContent[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_IMAGE] as? String
        var groupType: DPAGGroupType = .default
        let groupGuid: String
        let groupName: String
        if let groupGuidData = dataDecrypted.unknownContent[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_GUID] as? String, let groupNameData = dataDecrypted.unknownContent[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_NAME] as? String {
            groupGuid = groupGuidData
            groupName = groupNameData
        } else if let encryptedData = dataDecrypted.unknownContent[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.ENCRYPTED_DATA] as? String, let encryptedIV = dataDecrypted.unknownContent[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.ENCRYPTED_IV] as? String, let account = DPAGApplicationFacade.cache.account, let aesKey = account.aesKeyCompany {
            let dataStr = try CryptoHelperDecrypter.decryptCompanyEncryptedString(encryptedString: encryptedData, iv: encryptedIV, aesKey: aesKey)
            guard let data = dataStr.data(using: .utf8), let dict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] else {
                throw DPAGMessageReceivedError.errGroupInvitationContentMissing
            }
            guard let groupGuidData = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_GUID] as? String, let groupNameData = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_NAME] as? String, let groupAesKey = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_AES_KEY] as? String else {
                throw DPAGMessageReceivedError.errGroupInvitationContentMissing
            }
            groupGuid = groupGuidData
            groupName = groupNameData
            let aesKeyDict = ["key": groupAesKey, "iv": "ivDummy", "timestamp": CryptoHelper.newDateInDLFormat()]
            let aesKeyXML = XMLWriter.xmlString(from: aesKeyDict)
            toAccountDecAesKey = aesKeyXML
            groupImageEncoded = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_IMAGE] as? String
            var groupTypeStr: String = ""
            if let groupTypeS = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.ROOM_TYPE] as? String {
                groupTypeStr = groupTypeS
            } else if let groupTypeS = dict[DPAGStrings.Server.MessageReceivedGroupInvitation.Response.GROUP_TYPE] as? String {
                groupTypeStr = groupTypeS
            }
            switch groupTypeStr {
                case "ManagedRoom":
                    groupType = .managed
                case "RestrictedRoom":
                    groupType = .restricted
                case "AnnouncementRoom":
                    groupType = .announcement
                default:
                    groupType = .default
            }
        } else {
            throw DPAGMessageReceivedError.errGroupInvitationContentMissing
        }
        let contentDecrypted = DPAGMessageReceivedGroupInvitationDecrypted(groupName: groupName, groupGuid: groupGuid, groupAesKey: toAccountDecAesKey, groupType: groupType, groupImageEncoded: groupImageEncoded)
        _contentDecrypted = contentDecrypted
        return contentDecrypted
    }
}

enum DPAGMessageSignature {
    class HashesBase: Codable {
        let data: String

        let toGuid: String
        let fromGuid: String

        let toHash: String

        let fromHash: String

        let attachmentHash: String?

        private struct CodingKeys: CodingKey {
            var stringValue: String
            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int?
            init?(intValue _: Int) { nil }
        }

        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            var dataC, toGuidC, fromGuidC, toHashC, fromHashC, attachmentHashC: String?

            for codingKey in container.allKeys {
                let key = codingKey.stringValue
                let value = try container.decodeIfPresent(String.self, forKey: codingKey)

                switch key {
                case "data":
                    dataC = value
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/key"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/key"):
                    break
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/guid"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/guid"):
                    break
                case _ where key.hasPrefix("to/") && key.hasSuffix("/key"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/key"):
                    break
                case _ where key.hasPrefix("to/"):
                    toHashC = value
                    toGuidC = String(key.suffix(from: key.index(key.startIndex, offsetBy: 3)))
                case _ where key.hasPrefix("from/"):
                    fromHashC = value
                    fromGuidC = String(key.suffix(from: key.index(key.startIndex, offsetBy: 5)))
                case _ where key.hasPrefix("attachment/"):
                    attachmentHashC = value
                default:
                    break
                }
            }

            guard let data = dataC, let toGuid = toGuidC, let fromGuid = fromGuidC, let toHash = toHashC, let fromHash = fromHashC else {
                throw DPAGMessageReceivedError.errSignatureNotValid
            }

            self.data = data
            self.toGuid = toGuid
            self.fromGuid = fromGuid
            self.toHash = toHash
            self.fromHash = fromHash
            self.attachmentHash = attachmentHashC
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            if let key = CodingKeys(stringValue: "data") {
                try container.encode(self.data, forKey: key)
            }
            if let key = CodingKeys(stringValue: "to/" + self.toGuid) {
                try container.encode(self.toHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid) {
                try container.encode(self.fromHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "attachment/0") {
                try container.encodeIfPresent(self.attachmentHash, forKey: key)
            }
        }
    }

    class HashesPrivate: HashesBase {
        let toKeyHash: String
        let toTempDeviceGuid: String?
        let toTempDeviceKeyHash: String?

        let fromKeyHash: String
        let fromTempDeviceGuid: String?
        let fromTempDeviceKeyHash: String?

        private struct CodingKeys: CodingKey {
            var stringValue: String
            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int?
            init?(intValue _: Int) {
                nil
            }
        }

        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            var toKeyHashC, fromKeyHashC, toTempDeviceGuidC, fromTempDeviceGuidC, toTempDeviceKeyHashC, fromTempDeviceKeyHashC: String?

            for codingKey in container.allKeys {
                let key = codingKey.stringValue
                let value = try container.decodeIfPresent(String.self, forKey: codingKey)

                switch key {
                case "data":
                    break
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/key"):
                    toTempDeviceKeyHashC = value
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/key"):
                    fromTempDeviceKeyHashC = value
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/guid"):
                    toTempDeviceGuidC = value
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/guid"):
                    fromTempDeviceGuidC = value
                case _ where key.hasPrefix("to/") && key.hasSuffix("/key"):
                    toKeyHashC = value
                case _ where key.hasPrefix("from/") && key.hasSuffix("/key"):
                    fromKeyHashC = value
                case _ where key.hasPrefix("to/"):
                    break
                case _ where key.hasPrefix("from/"):
                    break
                case _ where key.hasPrefix("attachment/"):
                    break
                default:
                    break
                }
            }

            guard let toKeyHash = toKeyHashC, let fromKeyHash = fromKeyHashC else {
                throw DPAGMessageReceivedError.errSignatureNotValid
            }

            self.toKeyHash = toKeyHash
            self.fromKeyHash = fromKeyHash
            self.toTempDeviceGuid = toTempDeviceGuidC
            self.fromTempDeviceGuid = fromTempDeviceGuidC
            self.toTempDeviceKeyHash = toTempDeviceKeyHashC
            self.fromTempDeviceKeyHash = fromTempDeviceKeyHashC

            try super.init(from: decoder)
        }

        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)

            var container = encoder.container(keyedBy: CodingKeys.self)

            if let key = CodingKeys(stringValue: "to/" + self.toGuid + "/key") {
                try container.encode(self.toKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/key") {
                try container.encode(self.fromKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "to/" + self.toGuid + "/tempDevice/key") {
                try container.encodeIfPresent(self.toTempDeviceKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/tempDevice/key") {
                try container.encodeIfPresent(self.fromTempDeviceKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "to/" + self.toGuid + "/tempDevice/guid") {
                try container.encodeIfPresent(self.toTempDeviceGuid, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/tempDevice/guid") {
                try container.encodeIfPresent(self.fromTempDeviceGuid, forKey: key)
            }
        }
    }

    class HashesGroup: HashesBase {
        let fromKeyHash: String?
        let fromTempDeviceGuid: String?
        let fromTempDeviceKeyHash: String?

        private struct CodingKeys: CodingKey {
            var stringValue: String
            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int?
            init?(intValue _: Int) {
                nil
            }
        }

        required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            var fromKeyHashC, fromTempDeviceGuidC, fromTempDeviceKeyHashC: String?

            for codingKey in container.allKeys {
                let key = codingKey.stringValue
                let value = try container.decodeIfPresent(String.self, forKey: codingKey)

                switch key {
                case "data":
                    break
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/key"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/key"):
                    fromTempDeviceKeyHashC = value
                case _ where key.hasPrefix("to/") && key.hasSuffix("/tempDevice/guid"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/tempDevice/guid"):
                    fromTempDeviceGuidC = value
                case _ where key.hasPrefix("to/") && key.hasSuffix("/key"):
                    break
                case _ where key.hasPrefix("from/") && key.hasSuffix("/key"):
                    fromKeyHashC = value
                case _ where key.hasPrefix("to/"):
                    break
                case _ where key.hasPrefix("from/"):
                    break
                case _ where key.hasPrefix("attachment/"):
                    break
                default:
                    break
                }
            }

            self.fromKeyHash = fromKeyHashC
            self.fromTempDeviceGuid = fromTempDeviceGuidC
            self.fromTempDeviceKeyHash = fromTempDeviceKeyHashC

            try super.init(from: decoder)
        }

        override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)

            var container = encoder.container(keyedBy: CodingKeys.self)

            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/key") {
                try container.encode(self.fromKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/tempDevice/key") {
                try container.encodeIfPresent(self.fromTempDeviceKeyHash, forKey: key)
            }
            if let key = CodingKeys(stringValue: "from/" + self.fromGuid + "/tempDevice/guid") {
                try container.encodeIfPresent(self.fromTempDeviceGuid, forKey: key)
            }
        }
    }
}

struct DPAGMessageSignaturePrivate: Codable {
    let signature: String
    let signatureTempDevice: String?
    let hashes: DPAGMessageSignature.HashesPrivate

    private enum CodingKeys: String, CodingKey {
        case signature,
            signatureTempDevice = "signature-tempdevice",
            hashes
    }
}

struct DPAGMessageSignatureGroup: Codable {
    let signature: String
    let signatureTempDevice: String?
    let hashes: DPAGMessageSignature.HashesGroup

    private enum CodingKeys: String, CodingKey {
        case signature,
            signatureTempDevice = "signature-tempdevice",
            hashes
    }
}

extension KeyedDecodingContainer {
    func decodeIfPresentNoThrow<T>(_ type: T.Type, forKey key: K) -> T? where T: Decodable {
        if let data = try? self.decodeIfPresent(type, forKey: key) {
            return data
        }
        return nil
    }
}
