//
//  DPAGSendAVViewController.swift
// ginlo
//
//  Created by RBU on 06/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import MobileCoreServices
import Photos
import SIMSmeCore
import UIKit

protocol DPAGSendAVViewControllerDelegate: AnyObject {
    func sendObjects(with sendObjectViewController: DPAGSendAVViewControllerProtocol, media mediaArray: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?)
}

extension DPAGSendAVViewController: DPAGChatStreamSendOptionsViewDelegate {
    func sendOptionSelected(sendOption: DPAGChatStreamSendOptionsViewSendOption) {
        switch sendOption {
            case .closed, .hidden:
                break
            case .opened:
                break
            case .deactivated:
                self.inputSendOptionsView?.deactivate()
            case .highPriority:
                break
            case .selfDestruct:
                break
            case .sendTimed:
                break
        }
        self.inputController?.sendOptionSelected(sendOption: sendOption)
    }
}

extension DPAGSendAVViewController: DPAGChatStreamSendOptionsContentViewDelegate {
    func sendOptionsChanged() {
        self.inputSendOptionsView?.updateButtonTextsWithSendOptions()
    }
}

protocol DPAGSendAVViewControllerProtocol: AnyObject {
    var draft: String? { get set }
}

class DPAGSendAVViewController: DPAGViewControllerBackground, UINavigationControllerDelegate, DPAGSendAVViewControllerProtocol, DPAGViewControllerOrientationFlexible {
    private weak var sendDelegate: DPAGSendAVViewControllerDelegate?

    private var mediaSourceType: DPAGSendObjectMediaSourceType

    var mediaResources: [DPAGMediaResource] = []
    private var buttonDelete: UIBarButtonItem?
    private var pageViewController: UIPageViewController?
    var currentPage = 0

    var inputController: (UIViewController & DPAGChatStreamInputMediaViewControllerProtocol)?
    private weak var inputSendOptionsView: (UIView & DPAGChatStreamSendOptionsViewProtocol)?

    var draft: String?

    private let enableMultiSelection: Bool
    private let enableAdd: Bool

    weak var tapGrView: UITapGestureRecognizer?

    init(mediaSourceType: DPAGSendObjectMediaSourceType, mediaResources: [DPAGMediaResource], sendDelegate: DPAGSendAVViewControllerDelegate?, enableMultiSelection: Bool, enableAdd: Bool) {
        self.mediaSourceType = mediaSourceType
        self.mediaResources.append(contentsOf: mediaResources)
        self.sendDelegate = sendDelegate
        self.enableMultiSelection = enableMultiSelection
        self.enableAdd = enableAdd
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageViewController.delegate = self
        pageViewController.dataSource = self
        pageViewController.view.frame = self.view.bounds
        pageViewController.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.addChild(pageViewController)
        self.view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleViewTapped))
        tap.numberOfTapsRequired = 1
        tap.cancelsTouchesInView = false
        tap.isEnabled = false
        pageViewController.view.addGestureRecognizer(tap)
        self.tapGrView = tap
        self.pageViewController = pageViewController
        self.buttonDelete = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageChatTrash], style: .plain, target: self, action: #selector(deleteSelectedItem))
        let inputControllerViewName: String
        if self.enableMultiSelection {
            inputControllerViewName = "DPAGChatStreamInputMediaViewController"
            self.navigationItem.rightBarButtonItem = self.buttonDelete
        } else {
            inputControllerViewName = "DPAGChatStreamInputMediaOnlyViewController"
            self.navigationItem.rightBarButtonItem = nil
        }
        let inputController = DPAGApplicationFacadeUI.inputMediaVC(nibName: inputControllerViewName, bundle: Bundle(for: type(of: self)))
        inputController.inputMediaDelegate = self
        inputController.sendOptionsEnabled = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation == nil
        inputController.enableAdd = self.enableAdd
        self.inputController = inputController
        self.addChild(inputController)
        self.view.addSubview(inputController.view)
        inputController.didMove(toParent: self)
        inputController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addConstraintsStackingBottom(subview: inputController.view)
        self.view.setNeedsUpdateConstraints()
        if self.mediaResources.count > 0 {
            inputController.textView?.text = self.mediaResources.first?.text
        }
        let inputEmpty = (inputController.textView?.text?.isEmpty ?? true)
        if inputEmpty {
            inputController.textView?.text = self.draft
        }
        if inputController.sendOptionsEnabled {
            inputController.sendOptionsContainerView?.configure()
            inputController.sendOptionsChanged()
        }
        if let inputSendOptionsView = DPAGApplicationFacadeUI.viewChatStreamSendOptions() {
            self.inputSendOptionsView = inputSendOptionsView
            self.view.addSubview(inputSendOptionsView)
            inputSendOptionsView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.view.centerXAnchor.constraint(equalTo: inputSendOptionsView.centerXAnchor),
                self.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: inputSendOptionsView.topAnchor),
                self.view.leadingAnchor.constraint(equalTo: inputSendOptionsView.leadingAnchor),
                self.view.trailingAnchor.constraint(equalTo: inputSendOptionsView.trailingAnchor),
                inputSendOptionsView.bottomAnchor.constraint(equalTo: inputController.view.topAnchor)
            ])
            inputSendOptionsView.delegate = self
            inputSendOptionsView.show()
        }
        self.inputController?.mediaResources = self.mediaResources
        self.inputController?.collectionViewMediaObjects?.reloadData()
        self.currentPage = max(0, self.mediaResources.count - 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = false
        self.extendedLayoutIncludesOpaqueBars = true
        if self.currentPage >= self.mediaResources.count {
            self.currentPage = 0
        }
        self.updateCurrentPage(animated: false)
        self.buttonDelete?.isEnabled = self.mediaResources.count > 1
        self.pageViewController?.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let messageGuidCitation = DPAGSendMessageViewOptions.sharedInstance.messageGuidCitation, let decMessage = DPAGApplicationFacade.cache.decryptedMessage(messageGuid: messageGuidCitation) {
            self.inputController?.handleCommentMessage(for: decMessage)
        }
        if let collectionViewMediaObjects = self.inputController?.collectionViewMediaObjects, let selectedIndexPath = collectionViewMediaObjects.indexPathsForSelectedItems?.first {
            collectionViewMediaObjects.selectItem(at: selectedIndexPath, animated: animated, scrollPosition: .centeredHorizontally)
        }
    }

    private var isSending = false

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            DPAGSendMessageViewOptions.sharedInstance.reset()
            if self.isSending == false {
                for mediaResource in self.mediaResources {
                    if let mediaUrl = mediaResource.mediaUrl {
                        do { try FileManager.default.removeItem(at: mediaUrl) } catch {
                            DPAGLog(error)
                        }
                    }
                }
            }
        }
    }

    private func updateCurrentPage(animated: Bool) {
        var vcCurrent = self.pageViewController?.viewControllers?.last as? (UIViewController & DPAGMediaContentViewControllerProtocol)
        if vcCurrent == nil || (vcCurrent?.index ?? -1) != self.currentPage, self.currentPage >= 0, self.mediaResources.count > self.currentPage {
            let resource = self.mediaResources[self.currentPage]
            switch resource.mediaType {
                case .image:
                    vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: self.currentPage, mediaResource: resource)
                case .file, .video, .unknown, .voiceRec:
                    vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: self.currentPage, mediaResource: resource)
            }
        }
        vcCurrent?.customDelegate = self
        if let vcCurrent = vcCurrent {
            self.pageViewController?.setViewControllers([vcCurrent], direction: .forward, animated: animated, completion: nil)
            if self.currentPage < self.mediaResources.count {
                if let collectionViewMediaObjects = self.inputController?.collectionViewMediaObjects {
                    let selectedIndexPath = IndexPath(item: self.currentPage, section: 0)
                    collectionViewMediaObjects.selectItem(at: selectedIndexPath, animated: animated, scrollPosition: .centeredHorizontally)
                }
            }
        }
    }

    @objc
    private func deleteSelectedItem() {
        let itemIndex = self.inputController?.collectionViewMediaObjects?.indexPathsForSelectedItems?.last?.item ?? self.mediaResources.count
        if itemIndex < self.mediaResources.count {
            self.mediaResources.remove(at: itemIndex)
            self.inputController?.mediaResources = self.mediaResources
            self.inputController?.collectionViewMediaObjects?.reloadData()
            if self.mediaResources.count > 0, self.currentPage > 0, self.currentPage >= self.mediaResources.count {
                self.currentPage -= 1
            } else if let collectionViewMediaObjects = self.inputController?.collectionViewMediaObjects {
                let selectedIndexPath = IndexPath(item: self.currentPage, section: 0)
                collectionViewMediaObjects.selectItem(at: selectedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
            }
            self.inputContainerDidSelectMedia(at: self.currentPage)
            self.updateCurrentPage(animated: true)
        }
    }

    private func updateMediaObjects(_ mediaObjects: [DPAGMediaResource]) {
        var newMedia: [DPAGMediaResource] = []
        for mediaObject in self.mediaResources {
            if mediaObjects.contains(where: { mediaResource -> Bool in
                mediaResource.attachment?.attachmentGuid != nil && mediaObject.attachment?.attachmentGuid == mediaResource.attachment?.attachmentGuid
            }) {
                newMedia.append(mediaObject)
            }
        }
        for mediaObject in mediaObjects {
            if newMedia.contains(where: { mediaResource -> Bool in
                mediaResource.attachment?.attachmentGuid != nil && mediaObject.attachment?.attachmentGuid == mediaResource.attachment?.attachmentGuid
            }) == false {
                newMedia.append(mediaObject)
            }
        }
        self.mediaResources = newMedia
        self.inputController?.mediaResources = self.mediaResources
        self.inputController?.collectionViewMediaObjects?.reloadData()
        let currentPage = max(0, self.mediaResources.count - 1)
        self.currentPage = -1
        if let collectionViewMediaObjects = self.inputController?.collectionViewMediaObjects {
            let selectedIndexPath = IndexPath(item: currentPage, section: 0)
            collectionViewMediaObjects.selectItem(at: selectedIndexPath, animated: false, scrollPosition: .centeredHorizontally)
        }
        self.inputContainerDidSelectMedia(at: currentPage)
    }

    private func currentVC() -> (UIViewController & DPAGMediaContentViewControllerProtocol)? {
        self.pageViewController?.viewControllers?.last as? (UIViewController & DPAGMediaContentViewControllerProtocol)
    }

    @objc
    private func handleViewTapped() {
        if let textView = self.inputController?.textView, textView.isFirstResponder() {
            textView.resignFirstResponder()
        } else {
            self.inputController?.dismissSendOptionsView(animated: true)
        }
    }

    override func appWillResignActive() {
        self.inputController?.textView?.resignFirstResponder()
    }

    public class func checkFileSize(_ url: URL, showAlertVC: UIViewController?, cleanUpFile: Bool) -> NSNumber? {
        var fileAttributesRead: [FileAttributeKey: Any]?

        do {
            fileAttributesRead = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            DPAGLog(error)
        }
        if let fileAttributes = fileAttributesRead {
            if let fileType = fileAttributes[.type] as? FileAttributeType, fileType == .typeDirectory {
                let filename = url.lastPathComponent
                if filename.hasSuffix("pages") || filename.hasSuffix("numbers") || filename.hasSuffix("keynote") || filename.hasSuffix("key") {
                    showAlertVC?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.foldersNotImplemented.message.pages"))
                } else {
                    showAlertVC?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.foldersNotImplemented.message"))
                }
                if cleanUpFile {
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        DPAGLog(error)
                    }
                }
                return nil
            }
            if let fileSize = fileAttributes[.size] as? NSNumber {
                if AppConfig.isShareExtension {
                    let preferences = DPAGApplicationFacadeShareExt.preferences
                    if fileSize.uint64Value <= 0 || fileSize.uint64Value > preferences.maxFileSize || !DPAGHelper.canPerformRAMBasedJSON(ofSize: UInt(fileSize.uint64Value)) {
                        showAlertVC?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.fileSize.message"))
                        if cleanUpFile {
                            do {
                                try FileManager.default.removeItem(at: url)
                            } catch {
                                DPAGLog(error)
                            }
                        }
                        return nil
                    }
                } else {
                    let preferences = DPAGApplicationFacade.preferences
                    if fileSize.uint64Value <= 0 || fileSize.uint64Value > preferences.maxFileSize {
                        showAlertVC?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.fileSize.message"))
                        if cleanUpFile {
                            do {
                                try FileManager.default.removeItem(at: url)
                            } catch {
                                DPAGLog(error)
                            }
                        }
                        return nil
                    }
                }
                return fileSize
            }
        }
        showAlertVC?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.fileSizeNotAvailable.message"))
        if cleanUpFile {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                DPAGLog(error)
            }
        }

        return nil
    }
}

// MARK: - Input Controller Delegate

extension DPAGSendAVViewController: DPAGChatStreamInputMediaViewControllerDelegate {
    func inputContainerSendMedia() {
        let resource = self.mediaResources[self.currentPage]
        resource.text = self.inputController?.textView?.text
        let sendOptions = self.inputController?.getSendOptions()
        sendOptions?.attachmentIsInternalCopy = self.mediaResources.first?.attachment?.attachmentGuid != nil
        self.isSending = true
        self.sendDelegate?.sendObjects(with: self, media: self.mediaResources, sendMessageOptions: sendOptions)
    }

    func inputContainerDidSelectMedia(at mediaObjectIndex: Int) {
        if mediaObjectIndex < self.mediaResources.count {
            let resource = self.mediaResources[mediaObjectIndex]
            self.buttonDelete?.isEnabled = self.mediaResources.count > 1
            if self.currentPage != mediaObjectIndex {
                let lastPage = self.currentPage
                self.currentPage = mediaObjectIndex
                var vcCurrent = self.currentVC()
                if vcCurrent == nil || (vcCurrent?.index ?? -1) != mediaObjectIndex, self.currentPage >= 0, self.mediaResources.count > self.currentPage {
                    if resource.mediaType == .image {
                        vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: self.currentPage, mediaResource: resource)
                    } else {
                        vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: self.currentPage, mediaResource: resource)
                    }
                }
                vcCurrent?.customDelegate = self
                if let vcCurrent = vcCurrent {
                    let direction: UIPageViewController.NavigationDirection = (lastPage < mediaObjectIndex) ? .forward : .reverse
                    self.pageViewController?.setViewControllers([vcCurrent], direction: direction, animated: true, completion: nil)
                }
            }
            if resource.text != nil || (self.inputController?.textView?.text?.isEmpty ?? true) {
                self.inputController?.textView?.text = resource.text
            }
        } else {
            self.buttonDelete?.isEnabled = false
            self.inputController?.textView?.resignFirstResponder()
            self.inputController?.collectionViewMediaObjects?.cellForItem(at: IndexPath(item: mediaObjectIndex, section: 0))?.isSelected = false
            if AppConfig.isShareExtension == false {
                switch self.mediaSourceType {
                    case .simsme:
                        let mediaViewController = DPAGApplicationFacadeUIMedia.mediaSelectMultiVC(selectionType: .imageVideo, selection: self.mediaResources.compactMap { $0.attachment })
                        mediaViewController.mediaMultiPickerDelegate = self
                        self.present(DPAGApplicationFacadeUIBase.navVC(rootViewController: mediaViewController), animated: true, completion: nil)
                    case .album:
                        let libraryUI = DPAGImagePickerController()
                        libraryUI.setup()
                        libraryUI.sourceType = .photoLibrary
                        libraryUI.mediaTypes = [String(kUTTypeImage), String(kUTTypeMovie)]
                        libraryUI.videoMaximumDuration = DPAGApplicationFacade.preferences.maxLengthForSentVideos
                        libraryUI.videoQuality = DPAGApplicationFacade.preferences.videoQualityForSentVideos
                        libraryUI.delegate = self
                        self.present(libraryUI, animated: true, completion: nil)
                    case .camera:
                        let cameraUI = DPAGImagePickerController()
                        cameraUI.setup()
                        cameraUI.sourceType = .camera
                        cameraUI.mediaTypes = [String(kUTTypeImage), String(kUTTypeMovie)]
                        cameraUI.videoMaximumDuration = DPAGApplicationFacade.preferences.maxLengthForSentVideos
                        cameraUI.videoQuality = DPAGApplicationFacade.preferences.videoQualityForSentVideos
                        cameraUI.delegate = self
                        self.present(cameraUI, animated: true, completion: nil)
                    case .file, .none:
                        break
                }
            }
        }
    }

    func inputContainerDidDeselectMedia(at idx: Int) {
        self.buttonDelete?.isEnabled = false
        if idx < self.mediaResources.count {
            let resource = self.mediaResources[idx]
            resource.text = self.inputController?.textView?.text
        }
    }

    func inputContainerInitDraft() {}
    func inputContainerTextPlaceholder() -> String? { nil }
    func inputContainerSizeSizeChangedWithDiff(_: CGFloat) {}
    func inputContainerWillShowKeyboardWithHeight(_: CGFloat, animated _: Bool) {}
    func inputContainerWillHideKeyboardWithHeight(_: CGFloat, animated _: Bool) {}
    func inputContainerAddAttachment() {}
    func inputContainerTextViewDidChange() {}

    func inputContainerMaxHeight() -> CGFloat {
        let navHeight: CGFloat = (self.navigationController?.navigationBar.frame.size.height ?? 0)
        return self.view.frame.size.height - navHeight - 20
    }

    func inputContainerSendText(_: String) {}

    func inputContainerCanExecuteSendMessage() -> Bool {
        if let destructionConfig = self.inputController?.getSendOptions() {
            if let sendDate = destructionConfig.dateToBeSend, Date().compare(sendDate) == .orderedDescending {
                self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.sendDateBeforeNow"))
                return false
            } else if let destructionDate = destructionConfig.dateSelfDestruction, destructionConfig.countDownSelfDestruction == nil {
                if Date().compare(destructionDate) == .orderedDescending {
                    self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.selfDestructDateBeforeNow"))
                    return false
                } else if let sendDate = destructionConfig.dateToBeSend, sendDate.compare(destructionDate) == .orderedDescending {
                    self.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: "chat.message.selfDestructDateBeforeSendDate"))
                    return false
                }
            }
        }
        return true
    }

    func inputContainerShowsAdditionalView(_ isShowingView: Bool) {
        self.tapGrView?.isEnabled = isShowingView
    }

    var inputContainerCitationEnabled: Bool {
        if AppConfig.isShareExtension {
            return false
        } else {
            return true
        }
    }

    func inputContainerCitationCancel() {
        if let viewControllers = self.navigationController?.viewControllers {
            for vc in viewControllers {
                if let vcStreamBase = vc as? DPAGChatStreamBaseViewControllerProtocol {
                    vcStreamBase.inputController?.handleCitationCancel()
                }
            }
        }
        self.inputController?.sendOptionsEnabled = true
    }
}

// MARK: - DPAGMediaMultiPickerDelegate

extension DPAGSendAVViewController: DPAGMediaMultiPickerDelegate {
    func pickingMediaFailedWithError(_ errorMessage: String) {
        self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
    }

    func didFinishedPickingMultipleMedia(_ attachments: [DPAGMediaResource]) {
        self.updateMediaObjects(attachments)
    }
}

// MARK: - UIImagePickerControllerDelegate

extension DPAGSendAVViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let mediaType = info[.mediaType] as? String else { return }
        if mediaType == String(kUTTypeImage) {
            if let mediaAsset = info[.phAsset] as? PHAsset {
                let imageResource = DPAGMediaResource(type: .image)
                imageResource.mediaAsset = mediaAsset
                picker.dismiss(animated: true, completion: nil)
                self.updateMediaObjects(self.mediaResources + [imageResource])
            } else if let imageToSend = info[.originalImage] as? UIImage {
                let imageResource = DPAGMediaResource(type: .image)
                imageResource.mediaContent = (imageToSend.resizedForSending() ?? imageToSend).dataForSending()
                imageResource.preview = imageToSend.previewImage()
                picker.dismiss(animated: true, completion: nil)
                self.updateMediaObjects(self.mediaResources + [imageResource])
            }
        } else if mediaType == String(kUTTypeMovie) {
            guard let mediaURL = info[.mediaURL] as? URL else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch let error as NSError {
                DPAGLog(error, message: "audioSession error")
            }
            guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("sendingVideo" + DPAGFunctionsGlobal.uuid(), isDirectory: false).appendingPathExtension(mediaURL.pathExtension) else {
                picker.dismiss(animated: false, completion: nil)
                return
            }
            do {
                try FileManager.default.copyItem(at: mediaURL, to: outputUrl)
            } catch {
                DPAGLog(error, message: "error copying movie")
                picker.dismiss(animated: false, completion: nil)
                return
            }
            let videoResource = DPAGMediaResource(type: .video)
            videoResource.mediaUrl = outputUrl
            picker.dismiss(animated: true, completion: nil)
            self.updateMediaObjects(self.mediaResources + [videoResource])
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch let error as NSError {
            DPAGLog(error, message: "audioSession error")
        }

        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIVideoEditorControllerDelegate

extension DPAGSendAVViewController: UIVideoEditorControllerDelegate {
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        editor.dismiss(animated: true) { [weak self] in
            guard let strongself = self else { return }
            let mediaURL = URL(fileURLWithPath: editedVideoPath)
            guard let outputUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("sendingVideo" + DPAGFunctionsGlobal.uuid(), isDirectory: false).appendingPathExtension(mediaURL.pathExtension) else { return }
            do {
                try FileManager.default.copyItem(at: mediaURL, to: outputUrl)
            } catch {
                DPAGLog(error, message: "error copying movie")
                return
            }
            let videoResource = DPAGMediaResource(type: .video)
            videoResource.mediaUrl = outputUrl
            strongself.updateMediaObjects(strongself.mediaResources + [videoResource])
        }
    }

    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
        editor.dismiss(animated: true) { [weak self] in
            self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: error.localizedDescription, accessibilityIdentifier: "error_video_editor"))
        }
    }

    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        editor.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIPageViewControllerDataSource

extension DPAGSendAVViewController: UIPageViewControllerDataSource {
    func pageViewController(_: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        var idxBefore = 0
        let vcCurrent = viewController as? (UIViewController & DPAGMediaContentViewControllerProtocol)
        if let vcCurrent = vcCurrent {
            if vcCurrent.index - 1 < 0 {
                return nil
            }
            idxBefore = vcCurrent.index - 1
        }
        let mediaResource = self.mediaResources[idxBefore]
        let vcBeforNew: UIViewController & DPAGMediaContentViewControllerProtocol
        if mediaResource.mediaType == .image {
            vcBeforNew = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: idxBefore, mediaResource: mediaResource)
        } else {
            vcBeforNew = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: idxBefore, mediaResource: mediaResource)
        }
        vcBeforNew.customDelegate = self
        return vcBeforNew
    }

    func pageViewController(_: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        var idxAfter = 0
        let vcCurrent = viewController as? (UIViewController & DPAGMediaContentViewControllerProtocol)
        if let vcCurrent = vcCurrent {
            if vcCurrent.index + 1 >= self.mediaResources.count {
                return nil
            }
            idxAfter = vcCurrent.index + 1
        }
        let mediaResource = self.mediaResources[idxAfter]
        let vcAfterNew: UIViewController & DPAGMediaContentViewControllerProtocol
        if mediaResource.mediaType == .image {
            vcAfterNew = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: idxAfter, mediaResource: mediaResource)
        } else {
            vcAfterNew = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: idxAfter, mediaResource: mediaResource)
        }
        vcAfterNew.customDelegate = self
        return vcAfterNew
    }
}

// MARK: - UIPageViewControllerDelegate

extension DPAGSendAVViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        for vc in pendingViewControllers {
            vc.view.backgroundColor = pageViewController.viewControllers?.first?.view.backgroundColor
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating _: Bool, previousViewControllers _: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let vcCurrent = pageViewController.viewControllers?.last as? DPAGMediaContentViewControllerProtocol {
                self.currentPage = vcCurrent.index
            }
            let selectedIndexPath = IndexPath(item: self.currentPage, section: 0)
            if let collectionViewMediaObjects = self.inputController?.collectionViewMediaObjects {
                if let previouslySelectedIndexPath = collectionViewMediaObjects.indexPathsForSelectedItems?.first {
                    collectionViewMediaObjects.deselectItem(at: previouslySelectedIndexPath, animated: false)
                    self.inputController?.collectionView?(collectionViewMediaObjects, didDeselectItemAt: previouslySelectedIndexPath)
                }
                collectionViewMediaObjects.selectItem(at: selectedIndexPath, animated: true, scrollPosition: .centeredHorizontally)
                self.inputController?.collectionView?(collectionViewMediaObjects, didSelectItemAt: selectedIndexPath)
            }
        }
    }
}

// MARK: - MediaDetailViewDelegate

extension DPAGSendAVViewController: DPAGMediaDetailViewDelegate {
    func updateBackgroundColor(_ backgroundColor: UIColor) {
        self.view.backgroundColor = backgroundColor
    }

    func contentViewRecognizedSingleTap(_: UIViewController) {
        if self.inputController?.textView?.isFirstResponder() ?? false {
            self.inputController?.textView?.resignFirstResponder()
        }
    }
}
