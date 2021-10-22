//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGNavigationControllerProtocol: AnyObject {
    var transitioningDelegateZooming: UIViewControllerTransitioningDelegate? { get set }

    func resetNavigationBarStyle()
    func copyNavigationBarStyle(navVCSrc: UINavigationController?)
    func copyToolBarStyle(navVCSrc: UINavigationController?)
}

public protocol DPAGNavigationControllerStatusBarStyleSetter: AnyObject {}

public protocol DPAGObjectsSelectionBaseViewControllerProtocol: AnyObject {
    func configureSearchBar()
}

public protocol DPAGModalViewControllerProtocol: AnyObject {}

public protocol DPAGReceiverSelectionViewControllerProtocol: UISearchControllerDelegate {}

public protocol DPAGContactsSearchViewControllerDelegate: AnyObject {
    func didSelectContact(contact: DPAGContact)
}

public protocol DPAGContactsSearchResultsViewControllerProtocol: DPAGSearchResultsViewControllerProtocol {
    var contactsSearched: [DPAGContact] { get set }
    var contactsSelected: Set<DPAGContact>? { get set }
}

public protocol DPAGContactsSelectionBaseViewControllerProtocol: DPAGObjectsSelectionBaseViewControllerProtocol, DPAGTableViewControllerWithSearchProtocol {
    var model: DPAGSearchListModel<DPAGContact>? { get set }
}

public protocol DPAGContactsPagesBaseViewControllerProtocol: AnyObject {
    var searchController: UISearchController? { get }

    func pageChangeRequest(_ page: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?)

    func updateTitle()
}

public protocol DPAGContactsPagesViewControllerProtocol: AnyObject {
    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)
    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?
    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?
}

public extension DPAGContactsPagesViewControllerProtocol {
    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        nil
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        nil
    }
}

public protocol DPAGContactsSelectionSendingBaseViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {
    var delegate: DPAGContactSendingDelegate? { get set }
}

public protocol DPAGContactSendingDelegate: AnyObject {
    func send(contact: DPAGContact, asLocalVCard: Bool)
}

public protocol DPAGContactsSelectionSendingDelegateConsumer: AnyObject {
    var delegate: DPAGContactSendingDelegate? { get set }
}

public protocol DPAGReceiverDelegate: AnyObject {
    func didSelectReceiver(_ receiver: DPAGObject)
}

public protocol DPAGContactsSelectionReceiverDelegateConsumer: AnyObject {
    var delegate: DPAGReceiverDelegate? { get set }
}

public protocol DPAGContactsSelectionReceiverViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {
    var delegate: DPAGReceiverDelegate? { get set }
}

public protocol DPAGMediaDetailViewDelegate: AnyObject {
    func contentViewRecognizedSingleTap(_ contentViewController: UIViewController)
    func updateBackgroundColor(_ backgroundColor: UIColor)
}

public extension DPAGMediaDetailViewDelegate {
    func contentViewRecognizedSingleTap(_: UIViewController) {}
}

public protocol DPAGDefaultTransitionerZoomingBase: AnyObject {
    func zoomingViewForNavigationTransitionInView(_ inView: UIView, mediaResource: DPAGMediaResource?) -> CGRect
}

public protocol DPAGDefaultTransitionerDelegate: AnyObject {
    func preparePresentationWithZoomingRect(_ zoomingRect: CGRect)
    func animatePresentationZoomingRect(_ zoomingRect: CGRect)
    func completePresentationZoomingRect(_ zoomingRect: CGRect)
    func prepareDismissalWithZoomingRect(_ zoomingRect: CGRect)
    func animateDismissalZoomingRect(_ zoomingRect: CGRect)
    func completeDismissalZoomingRect(_ zoomingRect: CGRect)

    func mediaResourceShown() -> DPAGMediaResource?
}

public protocol DPAGMediaContentViewControllerProtocol: DPAGDefaultTransitionerDelegate {
    var mediaResource: DPAGMediaResource { get }
    var customDelegate: DPAGMediaDetailViewDelegate? { get set }
    var index: Int { get set }
}

public protocol DPAGMediaContentImageViewControllerProtocol: DPAGMediaContentViewControllerProtocol {
    var imageView: UIImageView? { get }

    func saveToLibrary(buttonPressed: UIBarButtonItem)
}

public protocol DPAGMediaContentVideoViewControllerProtocol: DPAGMediaContentViewControllerProtocol {
    func saveToLibrary(buttonPressed: UIBarButtonItem)
}

public protocol DPAGChatStreamCitationViewDelegate: AnyObject {
    func handleCitationCancel()
}

public protocol DPAGSendingDelegate: NSObjectProtocol {
    var navigationController: UINavigationController? { get }

    func performBlockOnMainThread(_ block: @escaping DPAGCompletion)
    func performBlockInBackground(_ block: @escaping DPAGCompletion)

    func sendMessageResponseBlock() -> DPAGServiceResponseBlock

    func updateViewBeforeMessageWillSend()
    func updateViewAfterMessageWasSent()

    func getRecipients() -> [DPAGSendMessageRecipient]
    func updateRecipientsConfidenceState()
}

public protocol DPAGChatStreamSendOptionsContentViewDelegate: AnyObject {
    func sendOptionsChanged()
}

public protocol DPAGChatStreamSendOptionsContentViewProtocol: AnyObject {
    var delegate: DPAGChatStreamSendOptionsContentViewDelegate? { get set }

    func setup()
    func configure()
    func completeConfigure()
    func reset()
}

public protocol DPAGContainerViewControllerProtocol: AnyObject {
    var mainNavigationController: UINavigationController { get }
    var secondaryNavigationController: UINavigationController { get }

    func showTopMainViewController(_ topMainViewController: UIViewController, completion: DPAGCompletion?)
    func showTopMainViewController(_ topMainViewController: UIViewController, animated: Bool, completion: DPAGCompletion?)
    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?)
    func showTopMainViewController(_ topMainViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?)
    func showTopMainViewController(_ topMainViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?)

    func pushMainViewController(_ topMainViewController: UIViewController, animated: Bool)

    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, completion: DPAGCompletion?)
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, animated: Bool, completion: DPAGCompletion?)
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, completion: DPAGCompletion?)
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewControllers: [UIViewController], animated: Bool, completion: DPAGCompletion?)
    func showSecondaryViewController(_ topSecondaryViewController: UIViewController, addViewController: UIViewController?, animated: Bool, completion: DPAGCompletion?)
    
    func pushSecondaryViewController(_ secondaryViewController: UIViewController, animated: Bool)

}

public protocol DPAGMediaFileTableViewCellProtocol: AnyObject {
    var isMediaSelected: Bool { get set }
    func setupWithAttachment(_ attachment: DPAGDecryptedAttachment)
    func update(withSearchBarText searchBarText: String?)
}

public protocol DPAGMediaOverviewSearchResultsViewControllerDelegate: AnyObject {
    func didSelectMedia(_ attachment: DPAGMediaViewAttachmentProtocol)

    func setupCell(_ cell: UITableViewCell & DPAGMediaFileTableViewCellProtocol, with attachment: DPAGDecryptedAttachment)
}

public protocol DPAGMediaOverviewSearchResultsViewControllerProtocol: DPAGSearchResultsViewControllerProtocol {
    var mediasSearched: [DPAGMediaViewAttachmentProtocol] { get set }
}

public protocol DPAGMediaOverviewViewControllerBaseProtocol: AnyObject {}

public protocol DPAGMediaContentFileViewControllerProtocol: DPAGMediaContentViewControllerProtocol {}

public typealias DPAGMediaResourceForwarding = (DPAGMediaResource) -> Void

public protocol DPAGMediaContentViewDelegate: AnyObject {
    func deleteAttachment(_ decryptedAttachment: DPAGDecryptedAttachment)
//    func forwardMediaResource(_ mediaResource: DPAGMediaResource)
}

public protocol DPAGMediaPickerDelegate: AnyObject {
    func didFinishedPickingMediaResource(_ attachment: DPAGMediaResource)
    func pickingMediaFailedWithError(_ errorMessage: String)
}

public protocol DPAGMediaMultiPickerDelegate: AnyObject {
    func pickingMediaFailedWithError(_ errorMessage: String)
    func didFinishedPickingMultipleMedia(_ attachments: [DPAGMediaResource])
}

public protocol DPAGMediaOverviewViewControllerDelegate: AnyObject {
    func updateToolbar()
}

public protocol DPAGMediaSelectViewControllerDelegate: AnyObject {
    func didSelectAttachment(_ attachment: DPAGMediaViewAttachmentProtocol?)
}

public protocol DPAGMediaDetailViewControllerProtocol: AnyObject {
    var titleShow: String? { get set }
}

public protocol DPAGMediaViewControllerProtocol: AnyObject, UISearchBarDelegate, UISearchControllerDelegate, UICollectionViewDataSource {
    var searchController: UISearchController? { get set }
    var searchResultsController: (UIViewController & DPAGSearchResultsViewControllerProtocol)? { get set }

    func configureSearchBar()

    var mediaOverviewDelegate: DPAGMediaOverviewViewControllerDelegate? { get set }
    var mediaSelectDelegate: DPAGMediaSelectViewControllerDelegate? { get set }

    var selection: [DPAGMediaViewAttachmentProtocol] { get set }

    func removeSelectedAttachments()
    func removeAttachment(_ decryptedAttachment: DPAGDecryptedAttachment)
    func resetSelection()
    var isSelectionMarked: Bool { get set }

    var attachments: [DPAGMediaViewAttachmentProtocol] { get }
    var selectedMediaType: DPAGMediaSelectionOptions { get set }

    var selectedIndexPath: IndexPath? { get set }

    func toolbarText() -> String

    var mediaOverView: UICollectionView { get }
}

public protocol DPAGMediaFilesViewControllerProtocol: DPAGTableViewControllerWithSearchProtocol {
    func configureSearchBar()

    var mediaOverviewDelegate: DPAGMediaOverviewViewControllerDelegate? { get set }
    var mediaSelectDelegate: DPAGMediaSelectViewControllerDelegate? { get set }

    var selection: [DPAGMediaViewAttachmentProtocol] { get }
    var isSelectionMarked: Bool { get set }

    func removeSelectedAttachments()
    func resetSelection()
}

public protocol DPAGMediaSelectSingleViewControllerProtocol: DPAGMediaOverviewViewControllerBaseProtocol {
    var mediaPickerDelegate: DPAGMediaPickerDelegate? { get set }
}

public protocol DPAGMediaSelectMultiViewControllerProtocol: DPAGMediaOverviewViewControllerBaseProtocol {
    var mediaMultiPickerDelegate: DPAGMediaMultiPickerDelegate? { get set }
}

public protocol DPAGRootContainerViewControllerProtocol: AnyObject {
    var rootViewController: UIViewController? { get set }
}

public typealias DPAGPasswordRequest = (Bool) -> Void

public protocol DPAGLoginViewControllerProtocol: DPAGPasswordInputDelegate {
    var mustChangePassword: Bool { get set }

    func companyRecoveryPasswordSuccess()

    func requestPassword(withTouchID: Bool, completion: @escaping DPAGPasswordRequest)
    func loginRequest(withTouchID: Bool, completion: DPAGCompletion?)
    func start()
}

public protocol DPAGPasswordInputDelegate: UITextFieldDelegate {
    func passwordDidDecryptPrivateKey()
    func passwordDidNotDecryptPrivateKey()
    func passwordIsValid()
    func passwordIsInvalid()
    func passwordViewController(_ passwordViewController: DPAGPasswordViewControllerProtocol, finishedInputWithPassword password: String?)
    func touchIDAuthenticationFailed()
    func passwordCorrespondsNotToThePasswordPolicies()
    func passwordIsExpired()
}

public extension DPAGPasswordInputDelegate {
    func passwordDidDecryptPrivateKey() {}
    func passwordDidNotDecryptPrivateKey() {}
    func passwordIsValid() {}
    func passwordIsInvalid() {}
    func passwordViewController(_: DPAGPasswordViewControllerProtocol, finishedInputWithPassword _: String?) {}
    func touchIDAuthenticationFailed() {}
    func passwordCorrespondsNotToThePasswordPolicies() {}
    func passwordIsExpired() {}
}

public protocol DPAGPasswordViewControllerProtocol: AnyObject {
    var delegate: DPAGPasswordInputDelegate? { get set }

    var state: DPAGPasswordViewControllerState { get set }

    func activate()

    func reset()

    func authenticate()

    func passwordEnteredCanBeValidated(_ enteredPassword: String?) -> Bool
    func getEnteredPassword() -> String?
    func verifyPassword(checkSimplePinUsage: Bool) -> DPAGPasswordViewControllerVerifyState
}

public enum DPAGPasswordViewControllerState: Int {
    case registration,
        login,
        enterPassword,
        changePassword,
        backup
}

public protocol DPAGTextFieldDelegate: AnyObject {
    func willDeleteBackward(_ textField: UITextField)
    func didDeleteBackward(_ textField: UITextField)
}

public protocol DPAGComplexPasswordViewControllerProtocol: DPAGPasswordViewControllerProtocol {
    var textFieldPassword: DPAGTextField! { get }

    func getMessageForPasswordVerifyState(_ state: DPAGPasswordViewControllerVerifyState) -> String?
}

public protocol DPAGOverlaySheetViewControllerHeaderViewDelegate: AnyObject {
    func handleHeaderAction()
}

public protocol DPAGOverlaySheetViewControllerFooterViewDelegate: AnyObject {
    func handleFooterAction()
}

public protocol DPAGPINPasswordViewControllerProtocol: DPAGPasswordViewControllerProtocol {
    var colorFillEmpty: UIColor { get set }
    var colorBorderEmpty: UIColor { get set }
    var colorFillFocused: UIColor { get set }
    var colorBorderFocused: UIColor { get set }
    var colorFillFilled: UIColor { get set }
    var colorBorderFilled: UIColor { get set }
}

public protocol DPAGTouchIDPasswordViewControllerProtocol: DPAGPasswordViewControllerProtocol {}

public protocol DPAGNavigationDrawerHeaderViewProtocol: AnyObject {
    var delegate: DPAGOverlaySheetViewControllerHeaderViewDelegate? { get set }

    func update()
}

public protocol DPAGNavigationDrawerFooterViewProtocol: AnyObject {
    var delegate: DPAGOverlaySheetViewControllerFooterViewDelegate? { get set }
}

public protocol DPAGViewControllerWithCompletion: AnyObject {
    var completion: (() -> Void)? { get set }
}

public protocol DPAGAdjustChatBackgroundDelegate: AnyObject {
    func didSelectImage(_ image: UIImage, imageLandscape: UIImage?, from controller: UINavigationController?, fromAlbum: Bool)
}

public protocol DPAGCompanyProfilConfirmEMailControllerSkipDelegate: AnyObject {
    var skipToEmailValidation: Bool { get set }
}

public protocol DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate: AnyObject {
    var skipToPhoneNumberValidation: Bool { get set }
}

public protocol DPAGCompanyProfilValidateEMailControllerSkipDelegate: AnyObject {
    var skipToEmailValidationInit: Bool { get set }
}

public protocol DPAGCompanyProfilValidatePhoneNumberControllerSkipDelegate: AnyObject {
    var skipToPhoneNumberValidationInit: Bool { get set }
}

public protocol DPAGProfileViewControllerProtocol: DPAGCompanyProfilConfirmEMailControllerSkipDelegate, DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate, DPAGCompanyProfilValidateEMailControllerSkipDelegate, DPAGCompanyProfilValidatePhoneNumberControllerSkipDelegate {}

public protocol DPAGOutOfOfficeStatusViewControllerProtocol: AnyObject {
    var delegate: DPAGStatusPickerTableViewControllerDelegate? { get set }
}

public protocol DPAGStatusPickerTableViewControllerProtocol: AnyObject {
    var delegate: DPAGStatusPickerTableViewControllerDelegate? { get set }
}

public protocol DPAGStatusPickerTableViewControllerDelegate: AnyObject {
    func updateStatusMessage(_ statusMessage: String)
}

public protocol DPAGPersonSendingDelegate: AnyObject {
    func send(person: DPAGPerson)
}

public protocol DPAGContactsSelectionNewChatDelegateConsumer: AnyObject {}

public protocol DPAGNewChatDelegate: AnyObject {
    func startChatWithGroup(_ streamGuid: String, fileURL: URL?)
}

public protocol DPAGNewGroupDelegate: AnyObject {
    func handleGroupCreated(_ groupGuid: String?)
}

public protocol DPAGContactDetailDelegate: AnyObject {
    func contactDidUpdate(_ person: DPAGContact)
}

public protocol DPAGContactDetailsViewControllerBaseProtocol: AnyObject {
    var delegate: DPAGContactDetailDelegate? { get set }
}

public protocol DPAGContactDetailsViewControllerProtocol: DPAGContactDetailsViewControllerBaseProtocol {
    var pushedFromChats: Bool { get set }
    var enableRemove: Bool { get set }
}

public protocol DPAGContactNewCreateViewControllerProtocol: DPAGContactDetailsViewControllerBaseProtocol {
    var confirmConfidence: Bool { get set }
}

public protocol GNContactScannedCreateViewControllerProtocol: DPAGContactDetailsViewControllerBaseProtocol {
    var confirmConfidence: Bool { get set }
    var isLogin: Bool { get set }
    var createNewChat: Bool { get set }
}

public protocol DPAGContactNewSearchViewControllerProtocol: AnyObject {
    var phoneNumInit: String? { get set }
    var countryCodeInit: String? { get set }
    var emailAddressInit: String? { get set }
    var ginloIDInit: String? { get set }
}

public protocol DPAGContactNewSelectViewControllerProtocol: AnyObject {}

public protocol DPAGContactNotFoundViewControllerProtocol: AnyObject {
    var fromWelcomePage: Bool { get set }
}

public protocol DPAGContactsSelectionGroupMembersDelegate: AnyObject {
    func addMembers(_ members: Set<DPAGContact>)
}

public protocol DPAGContactsSelectionGroupAdminsDelegate: AnyObject {
    func addAdmins(_ admins: Set<DPAGContact>)
}

public protocol DPAGContactsSelectionGroupMembersDelegateConsumer: AnyObject {
    var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate? { get set }
}

public protocol DPAGContactsSelectionGroupMembersAddViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {}

public protocol DPAGContactsSelectionGroupMembersRemoveViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {
    var memberSelectionDelegate: DPAGContactsSelectionGroupMembersDelegate? { get set }
}

public protocol DPAGContactsSelectionDistributionListMembersViewControllerDelegate: AnyObject {
    func didSelect(contacts: Set<DPAGContact>)
}

public protocol DPAGContactsSelectionDistributionListMembersDelegateConsumer: AnyObject {
    var delegate: DPAGContactsSelectionDistributionListMembersViewControllerDelegate? { get set }
}

public protocol DPAGContactsSelectionDistributionListMembersViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {}

public protocol DPAGContactsSelectionNewChatBaseViewControllerProtocol: DPAGContactsSelectionBaseViewControllerProtocol {}

public protocol DPAGActiveChatsListViewControllerProtocol: DPAGReceiverSelectionViewControllerProtocol {
    var completionOnSelectReceiver: ((DPAGObject) -> Void)? { get set }
}

public protocol DPAGNewFileChatViewControllerProtocol: DPAGReceiverSelectionViewControllerProtocol {}

public protocol DPAGPersonsSearchViewControllerDelegate: AnyObject {
    func didSelect(person: DPAGPerson)
}

public protocol DPAGPersonsSearchResultsViewControllerProtocol: DPAGSearchResultsViewControllerProtocol {
    var personsSearched: [DPAGPerson] { get set }
}

public protocol DPAGPersonsSelectionDelegate: AnyObject {
    func didSelect(persons: Set<DPAGPerson>)
}

public protocol DPAGLicencesInitConsumer: AnyObject {
    func setDateValid(_ dateValid: Date?)
}

public protocol DPAGWelcomeViewControllerProtocol: AnyObject {
    var accountGuid: String { get }
    var invitationData: [String: Any]? { get set }
}

public protocol DPAGBackupRecoverPasswordViewControllerDelegate: AnyObject {
    func handlePasswordEntered(_ backupFile: DPAGBackupFileInfo, password: String)
}

public protocol DPAGBackupRecoverViewControllerPKDelegate: AnyObject {
    func handleProceedWithBackupOverride(backupEntry: DPAGBackupFileInfo)
}

public protocol DPAGPageViewControllerProtocol: AnyObject {
    func pageForwards()
    func pageBackwards()
}

public protocol DPAGIntroViewControllerProtocol: AnyObject {}

public protocol DPAGConfirmAccountViewControllerProtocol: AnyObject {}
