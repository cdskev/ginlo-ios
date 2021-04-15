//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUI {
    private init() {}

    static func viewChatListTestVoucher() -> (UIView & DPAGChatListTestVoucherInfoViewProtocol) { DPAGChatListTestVoucherInfoView() }
    static func viewChatStreamSectionNib() -> UINib { UINib(nibName: "DPAGChatStreamSectionHeaderView", bundle: Bundle(for: DPAGChatStreamSectionHeaderView.self)) }
    static func viewChatStreamSendOptionsContent() -> (UIView & DPAGChatStreamSendOptionsContentViewProtocol)? { UINib(nibName: "DPAGChatStreamSendOptionsContentView", bundle: Bundle(for: DPAGChatStreamSendOptionsContentView.self)).instantiate(withOwner: nil, options: nil).first as? DPAGChatStreamSendOptionsContentView }
    static func viewChatStreamSendOptions() -> (UIView & DPAGChatStreamSendOptionsViewProtocol)? { UINib(nibName: "DPAGChatStreamSendOptionsView", bundle: Bundle(for: DPAGChatStreamSendOptionsView.self)).instantiate(withOwner: nil, options: nil).first as? DPAGChatStreamSendOptionsView }
    static func cellChatInfoContactNib() -> UINib { UINib(nibName: "DPAGChatInfoContactTableViewCell", bundle: Bundle(for: DPAGChatInfoContactTableViewCell.self)) }
    static func cellChannelDetailsDesciptionNib() -> UINib { UINib(nibName: "DPAGChannelDetailsDesciptionTableViewCell", bundle: Bundle(for: DPAGChannelDetailsDesciptionTableViewCell.self)) }
    static func subscribeChannelCellNib() -> UINib { UINib(nibName: "SubscribeChannelCell", bundle: Bundle(for: SubscribeChannelCell.self)) }
    static func cellChannelNib() -> UINib { UINib(nibName: "DPAGChannelCell", bundle: Bundle(for: DPAGChannelCell.self)) }
    static func cellChatContactConfirmNib() -> UINib { UINib(nibName: "DPAGChatContactConfirmCell", bundle: Bundle(for: DPAGChatContactConfirmCell.self)) }
    static func cellChatContactNib() -> UINib { UINib(nibName: "DPAGChatContactCell", bundle: Bundle(for: DPAGChatContactCell.self)) }
    static func cellChatGroupNib() -> UINib { UINib(nibName: "DPAGChatGroupCell", bundle: Bundle(for: DPAGChatGroupCell.self)) }
    static func cellChatGroupConfirmNib() -> UINib { UINib(nibName: "DPAGChatGroupConfirmInvitationCell", bundle: Bundle(for: DPAGChatGroupConfirmInvitationCell.self)) }
    static func cellServiceNib() -> UINib { UINib(nibName: "DPAGServiceCell", bundle: Bundle(for: DPAGServiceCell.self)) }
    static func cellMediaSendingNib() -> UINib { UINib(nibName: "DPAGMediaSendingCollectionViewCell", bundle: Bundle(for: DPAGMediaSendingCollectionViewCell.self)) }
    static func cellMessageContactLeftNib() -> UINib { UINib(nibName: "DPAGContactMessageLeftCell", bundle: Bundle(for: DPAGContactMessageLeftCell.self)) }
    static func cellMessageContactRightNib() -> UINib { UINib(nibName: "DPAGContactMessageRightCell", bundle: Bundle(for: DPAGContactMessageRightCell.self)) }
    static func cellMessageDestructionLeftNib() -> UINib { UINib(nibName: "DPAGDestructionMessageLeftCell", bundle: Bundle(for: DPAGDestructionMessageLeftCell.self)) }
    static func cellMessageFileLeftNib() -> UINib { UINib(nibName: "DPAGFileMessageLeftCell", bundle: Bundle(for: DPAGFileMessageLeftCell.self)) }
    static func cellMessageFileRightNib() -> UINib { UINib(nibName: "DPAGFileMessageRightCell", bundle: Bundle(for: DPAGFileMessageRightCell.self)) }
    static func cellMessageImageLeftNib() -> UINib { UINib(nibName: "DPAGImageMessageLeftCell", bundle: Bundle(for: DPAGImageMessageLeftCell.self)) }
    static func cellMessageImageRightNib() -> UINib { UINib(nibName: "DPAGImageMessageRightCell", bundle: Bundle(for: DPAGImageMessageRightCell.self)) }
    static func cellMessageLocationLeftNib() -> UINib { UINib(nibName: "DPAGLocationMessageLeftCell", bundle: Bundle(for: DPAGLocationMessageLeftCell.self)) }
    static func cellMessageLocationRightNib() -> UINib { UINib(nibName: "DPAGLocationMessageRightCell", bundle: Bundle(for: DPAGLocationMessageRightCell.self)) }
    static func cellMessageSimpleLeftNib() -> UINib { UINib(nibName: "DPAGSimpleMessageLeftCell", bundle: Bundle(for: DPAGSimpleMessageLeftCell.self)) }
    static func cellMessageSimpleRightNib() -> UINib { UINib(nibName: "DPAGSimpleMessageRightCell", bundle: Bundle(for: DPAGSimpleMessageRightCell.self)) }
    static func cellMessageSystemNib() -> UINib { UINib(nibName: "DPAGSystemMessageCell", bundle: Bundle(for: DPAGSystemMessageCell.self)) }
    static func cellMessageVideoLeftNib() -> UINib { UINib(nibName: "DPAGVideoMessageLeftCell", bundle: Bundle(for: DPAGVideoMessageLeftCell.self)) }
    static func cellMessageVideoRightNib() -> UINib { UINib(nibName: "DPAGVideoMessageRightCell", bundle: Bundle(for: DPAGVideoMessageRightCell.self)) }
    static func cellMessageVoiceLeftNib() -> UINib { UINib(nibName: "DPAGVoiceMessageLeftCell", bundle: Bundle(for: DPAGVoiceMessageLeftCell.self)) }
    static func cellMessageVoiceRightNib() -> UINib { UINib(nibName: "DPAGVoiceMessageRightCell", bundle: Bundle(for: DPAGVoiceMessageRightCell.self)) }
    static func cellMessageImageChannelLeftNib() -> UINib { UINib(nibName: "DPAGImageMessageChannelLeftCell", bundle: Bundle(for: DPAGImageMessageChannelLeftCell.self)) }
    static func cellMessageSimpleChannelLeftNib() -> UINib { UINib(nibName: "DPAGSimpleMessageChannelLeftCell", bundle: Bundle(for: DPAGSimpleMessageChannelLeftCell.self)) }
    static func cellMessageSimpleServiceLeftNib() -> UINib { UINib(nibName: "DPAGSimpleMessageServiceLeftCell", bundle: Bundle(for: DPAGSimpleMessageChannelLeftCell.self)) }
    static func cellMessageTextWithImagePreviewChannelLeftNib() -> UINib { UINib(nibName: "DPAGTextMessageWithImagePreviewChannelLeftCell", bundle: Bundle(for: DPAGTextMessageWithImagePreviewChannelLeftCell.self)) }
    static func viewChatStreamCitationContent() -> (UIView & DPAGChatStreamCitationViewProtocol)? { UINib(nibName: "DPAGChatStreamCitationView", bundle: Bundle(for: DPAGChatStreamCitationView.self)).instantiate(withOwner: nil, options: nil).first as? (UIView & DPAGChatStreamCitationViewProtocol) }
    public static let urlHandler: DPAGUrlHandlerProtocol = DPAGUrlHandler.sharedInstance
    static let newMessageNotifier: DPAGNewMessageNotifierProtocol = DPAGNewMessageNotifier.sharedInstance
    public static func notificationStateUpdateWorker() -> DPAGNotificationStateUpdateWorkerProtocol { DPAGNotificationStateUpdateWorker() }
    static func statusBarNotificationDisplay() -> DPAGStatusBarNotificationDisplayProtocol { DPAGStatusBarNotificationDisplay() }
    static func channelCategoryVC() -> UIViewController & DPAGChannelCategoriesViewControllerProtocol { DPAGChannelCategoryViewController() }
    static func channelDetailsVC(channelGuid: String, category: DPAGChannelCategory?) -> UIViewController? { DPAGChannelDetailsViewController(channelGuid: channelGuid, category: category) }
    static func channelSubscribeVC() -> (UIViewController & DPAGSubscribeChannelViewControllerProtocol) { DPAGSubscribeChannelViewController() }
    static func serviceSubscribeVC() -> (UIViewController & DPAGSubscribeServiceViewControllerProtocol) { DPAGSubscribeServiceViewController() }
    static func chatsListVC() -> UIViewController & DPAGChatsListViewControllerProtocol & DPAGNewChatDelegate { DPAGChatsListViewController() }
    static func channelStreamVC(stream streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol)? { DPAGChannelStreamViewController(stream: streamGuid, streamState: streamState) }
    static func serviceStreamVC(stream streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol)? { DPAGServiceStreamViewController(stream: streamGuid, streamState: streamState) }
    static func chatStreamVC(stream streamGuid: String, streamState: DPAGChatStreamState, startChatWithUnconfirmedContact: Bool = true) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol) { DPAGChatStreamViewController(stream: streamGuid, streamState: streamState, startChatWithUnconfirmedContact: startChatWithUnconfirmedContact) }
    static func chatNoStreamVC(text: String?) -> (UIViewController & DPAGChatBaseViewControllerProtocol) { DPAGChatNoStreamViewController(text: text) }
    static func chatGroupStreamVC(stream streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol) { DPAGGroupChatStreamViewController(stream: streamGuid, streamState: streamState) }
    static func chatTimedMessagesStreamVC(streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol) { DPAGChatStreamTimedMessagesPrivateViewController(streamGuid: streamGuid, streamState: streamState) }
    static func chatGroupTimedMessagesStreamVC(streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGChatStreamBaseViewControllerProtocol) { DPAGChatStreamTimedMessagesGroupViewController(streamGuid: streamGuid, streamState: streamState) }
    static func inputVoiceVC() -> UIViewController & DPAGAudioRecordDelegate & DPAGAudioPlayDelegate & DPAGChatStreamInputVoiceViewControllerProtocol { DPAGChatStreamInputVoiceViewController() }
    static func inputMediaVC(nibName: String, bundle: Bundle) -> (UIViewController & DPAGChatStreamInputMediaViewControllerProtocol) { DPAGChatStreamInputMediaViewController(nibName: nibName, bundle: bundle) }
    static func locationInfoVC() -> UIViewController & DPAGLocationInfoViewControllerProtocol { DPAGLocationInfoViewController() }
    static func locationSendVC() -> UIViewController & DPAGSendLocationViewControllerProtocol { DPAGSendLocationViewController() }
    static func imageOrVideoSendVC(mediaSourceType: DPAGSendObjectMediaSourceType, mediaResources: [DPAGMediaResource], sendDelegate: DPAGSendAVViewControllerDelegate?, enableMultiSelection: Bool, enableAdd: Bool = true) -> (UIViewController & DPAGSendAVViewControllerProtocol) { DPAGSendAVViewController(mediaSourceType: mediaSourceType, mediaResources: mediaResources, sendDelegate: sendDelegate, enableMultiSelection: enableMultiSelection, enableAdd: enableAdd) }
    static func messageReceiverInfoPrivateVC(decMessage: DPAGDecryptedMessage, streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGMessageReceiverInfoPrivateViewControllerProtocol) { DPAGMessageReceiverInfoPrivateViewController(decMessage: decMessage, streamGuid: streamGuid, streamState: streamState) }
    static func messageReceiverInfoGroupVC(decMessage: DPAGDecryptedMessage, streamGuid: String, streamState: DPAGChatStreamState) -> (UIViewController & DPAGMessageReceiverInfoGroupViewControllerProtocol) { DPAGMessageReceiverInfoGroupViewController(decMessage: decMessage, streamGuid: streamGuid, streamState: streamState) }
    static func textDestructionShowVC(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String) -> (UIViewController & DPAGShowDestructionTextViewControllerProtocol) { DPAGShowDestructionTextViewController(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid) }
    static func imageShowVC(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String, mediaResource: DPAGMediaResource) -> (UIViewController & DPAGShowImageViewControllerProtocol) { DPAGShowImageViewController(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid, mediaResource: mediaResource) }
    static func locationShowVC() -> UIViewController & DPAGShowLocationViewControllerProtocol { DPAGShowLocationViewController() }
    static func videoShowVC(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String, mediaResource: DPAGMediaResource) -> (UIViewController & DPAGShowVideoViewControllerProtocol) { DPAGShowVideoViewController(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid, mediaResource: mediaResource) }
    static func voiceRecShowVC(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String) -> (UIViewController & DPAGShowVoiceRecViewControllerProtocol) { DPAGShowVoiceRecViewController(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid) }
    static func groupNewVC(delegate: DPAGNewGroupDelegate?) -> (UIViewController) { DPAGNewGroupViewController(delegate: delegate) }
    static func groupNewAnnouncementGroupVC(delegate: DPAGNewGroupDelegate?) -> (UIViewController) { DPAGNewAnnouncementGroupViewController(delegate: delegate) }
    static func groupEditVC(groupGuid: String) -> (UIViewController) { DPAGAdministrateGroupViewController(groupGuid: groupGuid) }
    public static func launchMigrationVC() -> (UIViewController) { DPAGLaunchScreenMigrationViewController() }
    static func channelSearchResultsVC(delegate: DPAGChannelSearchResultsViewControllerDelegate) -> UIViewController & DPAGChannelSearchResultsViewControllerProtocol { DPAGChannelSearchResultsViewController(delegate: delegate) }
    static func chatsListSearchResultsVC(delegate: DPAGChatsListSearchResultsViewDelegate) -> UIViewController & DPAGChatsListViewSearchResultsViewControllerProtocol { DPAGChatsListViewSearchResultsViewController(delegate: delegate) }

    // IMPLEMENT MIGRATION USING THIS STUFF...
    //        guard DPAGApplicationFacade.preferences.migrationVersion == .versionCurrent else {
    //            return DPAGMigrationBaseViewController()
    //        }
    static func migrationVC() -> (UIViewController & DPAGMigrationViewControllerProtocol)? { nil }
}
