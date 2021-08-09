//
//  DPAGNewFileChatViewController.swift
//  SIMSme
//
//  Created by RBU on 29/01/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import AVFoundation
import MobileCoreServices
import SIMSmeCore
import UIKit

protocol DPAGShareExtSendingViewControllerDelegate: AnyObject {
    var extensionContext: NSExtensionContext? { get }

    func dismiss()
    func showError(text: String)
}

@objc(DPAGShareExtViewControllerBase)
open class DPAGShareExtViewControllerBase: UIViewController, DPAGShareExtSendingViewControllerDelegate {
    open var containerConfig: DPAGSharedContainerConfig? {
        nil
    }

    override open func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.view.backgroundColor = DPAGColorProvider.ShareExtension.backgroundLoad

        // Start monitoring the internet connection
        AFNetworkReachabilityManager.shared().startMonitoring()
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration * 2), animations: { [weak self] in
            self?.view.backgroundColor = DPAGColorProvider.ShareExtension.backgroundAppear
        }, completion: { [weak self] _ in

            do {
                DPAGLog("ShareExt::init Step 1")
                guard let strongSelf = self, let config = strongSelf.containerConfig else { return }

                DPAGLog("ShareExt::init Step 2")
                // Lesen des PrivatKey aus der KeyChain
                guard let privateKey = DPAGSharedContainerExtensionSending().getShareExtKey(config: config) else {
                    DPAGLog("no privateKey")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }

                DPAGLog("ShareExt::init Step 3")
                // Lesen der Infos
                guard let sharedContainer = try DPAGSharedContainerExtensionSending().readfile(config: config) else {
                    DPAGLog("no sharedContainer")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }

                DPAGLog("ShareExt::init Step 4")
                DPAGApplicationFacadeShareExt.preferences.configure(container: sharedContainer)
                DPAGApplicationFacadeShareExt.cache.configure(container: sharedContainer)

                DPAGLog("ShareExt::init Step 5")
                guard let deviceGuid = DPAGApplicationFacadeShareExt.preferences.shareExtensionDeviceGuid else {
                    DPAGLog("no deviceGuid")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }
                guard let devicePasstoken = DPAGApplicationFacadeShareExt.preferences.shareExtensionDevicePasstoken else {
                    DPAGLog("no devicePasstoken")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }

                DPAGLog("ShareExt::init Step 6")
                guard let account = DPAGApplicationFacadeShareExt.cache.account else {
                    DPAGLog("no account")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }
                guard let publicKey = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid)?.publicKey else {
                    DPAGLog("no account")
                    self?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
                    return
                }

                DPAGLog("ShareExt::init Step 7")

                if DPAGApplicationFacadeShareExt.preferences.isBaMandant {
                    DPAGColorProvider.shared.updateProviderBA()
                    DPAGImageProvider.shared.updateProviderBA()
                }

                DPAGLog("ShareExt::init Step 8")
                NSLog("Sharing start")
                let httpUsername = String(format: "%@@%@", strongSelf.stripGuid(deviceGuid), strongSelf.stripGuid(account.guid))
                let httpPassword = devicePasstoken

                let sendingVC = DPAGShareExtSendingViewController()
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: sendingVC)

                DPAGLog("ShareExt::init Step 9")
                let accountCrypto = try CryptoHelperSimple(publicKey: publicKey, privateKey: privateKey)

                DPAGLog("ShareExt::init Step 10")
                sendingVC.extensionDelegate = self
                sendingVC.accountCrypto = accountCrypto
                sendingVC.containerConfig = config
                sendingVC.configSending = DPAGShareExtSendingConfig(httpUsername: httpUsername, httpPassword: httpPassword)

                DPAGLog("ShareExt::init Step 11")
                self?.present(navVC, animated: true, completion: nil)
            } catch {
                DPAGLog(error)
                self?.showError(text: error.localizedDescription)
            }
        })
    }

    private func stripGuid(_ guidWithPrefix: String) -> String {
        if let range = guidWithPrefix.range(of: ":{"), guidWithPrefix.hasSuffix("}") {
            return "{" + guidWithPrefix[range.upperBound...]
        }
        return guidWithPrefix
    }

    func dismiss() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.

        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.

        guard let extensionContext = self.extensionContext else { return }

        var items: [Any] = []

        for item in extensionContext.inputItems {
            if let itemCopyable = item as? NSCopying {
                items.append(itemCopyable.copy())
            }
        }

        self.extensionContext?.completeRequest(returningItems: items, completionHandler: nil)
    }

    func showError(text: String) {
        self.performBlockOnMainThread { [weak self] in

            let sendingErrorVC = DPAGShareExtSendingErrorViewController()

            sendingErrorVC.text = text
            sendingErrorVC.extensionDelegate = self

            if let navVC = self?.presentedViewController as? DPAGNavigationController {
                navVC.setViewControllers([sendingErrorVC], animated: true)
            } else {
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: sendingErrorVC)

                self?.present(navVC, animated: true, completion: nil)
            }
        }
    }
}

class DPAGShareExtSendingViewController: DPAGReceiverSelectionViewController {
    fileprivate var accountCrypto: CryptoHelperSimple?
    fileprivate var containerConfig: DPAGSharedContainerConfig?
    fileprivate var configSending: DPAGShareExtSendingConfig?
    private var sendMessageOptionsShareExt: DPAGSendMessageOptionsShareExt?

    fileprivate weak var extensionDelegate: DPAGShareExtSendingViewControllerDelegate?

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        if parent == nil {
            self.extensionDelegate = nil
        }
    }

    override func viewDidLoad() {
        DPAGLog("ShareExt::viewDidLoad")

        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.title = DPAGLocalizedString("chats.title.newFileChat")

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissVC))

        UINavigationBar.appearance().barTintColor = DPAGColorProvider.shared[.navigationBar]
        UINavigationBar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        DPAGLog("ShareExt::viewDidAppear")
        super.viewDidAppear(animated)
        self.textToSend = nil
        if self.attachmentsLoaded == false {
            self.attachmentsLoaded = true
            self.showProgressHUDForBackgroundProcess(animated: true) { [weak self] _ in
                NSLog("Hello")
                self?.loadAttachments()
            }
        } else if DPAGHelperEx.isNetworkReachable() == false {
            self.extensionDelegate?.showError(text: DPAGLocalizedString("service.networkFailure"))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    private var recipients: [DPAGSendMessageRecipient] = []

    private var attachmentCountToLoad = 0

    private var willSend = false
    private var hasError = false
    private var hasMaxLengthError = false
    private var attachmentsLoaded = false
    private var mediaResources: [DPAGMediaResource] = []
    private var textToSend: String?
    private var containsFileType = false

    private let queueSync: DispatchQueue = DispatchQueue(label: "de.dpag.simsme.DPAGShareExtSendingViewController.queueSync", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    override func didSelectReceiver(_ receiver: DPAGObject) {
        super.didSelectReceiver(receiver)
        guard let containerConfig = self.containerConfig, let configSending = self.configSending else { return }
        self.recipients.removeAll()
        guard let accountCrypto = self.accountCrypto else {
            DPAGLog("no accountCrypto")
            self.extensionDelegate?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
            return
        }
        if let group = receiver as? DPAGGroup, let groupAesKey = group.aesKey {
            self.recipients.append(DPAGSendMessageRecipient(recipientGuid: group.guid))
            self.sendMessageOptionsShareExt = DPAGSendMessageOptionsShareExtGroup(accountCrypto: accountCrypto, aesKey: XMLWriter.xmlString(from: ["key": groupAesKey]))
            self.sendMedia(streamName: group.name)
        } else if let contact = receiver as? DPAGContact, let contactPublicKey = contact.publicKey, let account = DPAGApplicationFacadeShareExt.cache.account, let contactAccount = DPAGApplicationFacadeShareExt.cache.contact(for: account.guid), let accountPublicKey = contactAccount.publicKey {
            let progress: DPAGProgressHUDWithLabelProtocol? = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, in: self.view.window, completion: { _ in
                DPAGApplicationFacadeShareExt.server.getAccountInfo(guid: contact.guid, withProfile: true, withTempDevice: true, config: containerConfig, configSending: configSending) { [weak self] _, _, errorMessage in
                    self?.performBlockOnMainThread { [weak self] in
                        guard let strongSelf = self else { return }
                        if let errorMessage = errorMessage, errorMessage == "service.ERR-0007" {
                            DPAGProgressHUD.sharedInstance.hide(true, in: strongSelf.view.window) { [weak self] in
                                guard let strongSelf = self else { return }
                                strongSelf.extensionDelegate?.showError(text: DPAGLocalizedString(errorMessage))
                            }
                        } else {
                            DPAGProgressHUD.sharedInstance.hide(true, in: strongSelf.view.window) { [weak self] in
                                guard let strongSelf = self else { return }
                                do {
                                    let cachedAesKeys: DPAGContactAesKeys
                                    if let aesKeysContact = contact.aesKeys {
                                        cachedAesKeys = aesKeysContact
                                    } else {
                                        let aesKeyNew = try CryptoHelperEncrypter.getNewRawAesKey()
                                        let recipientEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyNew, withPublicKey: contactPublicKey)
                                        let senderEncAesKey = try CryptoHelperEncrypter.encrypt(string: aesKeyNew, withPublicKey: accountPublicKey)
                                        cachedAesKeys = DPAGContactAesKeys(aesKey: aesKeyNew, recipientEncAesKey: recipientEncAesKey, senderEncAesKey: senderEncAesKey)
                                    }
                                    strongSelf.recipients.append(DPAGSendMessageRecipient(recipientGuid: contact.guid))
                                    strongSelf.sendMessageOptionsShareExt = DPAGSendMessageOptionsShareExtSingle(accountCrypto: accountCrypto, recipientPublicKey: contactPublicKey, cachedAesKeys: cachedAesKeys)
                                    strongSelf.sendMedia(streamName: contact.displayName)
                                } catch {
                                    DPAGLog(error)
                                    strongSelf.extensionDelegate?.showError(text: error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }) as? DPAGProgressHUDWithLabelProtocol
            progress?.labelTitle.text = DPAGLocalizedString("share.extension.getAccountInfo")
        }
    }

    private func loadAttachments() {
        NSLog("ShareExt::loadAttachments")
        guard let extensionContext = self.extensionDelegate?.extensionContext else {
            DPAGLog("no context")
            self.extensionDelegate?.showError(text: DPAGLocalizedString("share.extension.enable.setting"))
            return
        }
        // If you want to debug, make this line active so that you have some time to attach to the share extension
//        Thread.sleep(forTimeInterval: 20.0)

        self.queueSync.sync(flags: .barrier) { [weak self] in
            self?.willSend = false
            self?.mediaResources = []
            self?.hasError = false
        }
        var attachmentCountToLoad = 0
        for inputItem in extensionContext.inputItems {
            guard let extensionItem = inputItem as? NSExtensionItem else { continue }
            guard let attachments = extensionItem.attachments, attachments.count > 0 else { continue }
            // If we receive a mixed-type item (multi-attachment)
            // and one of them is text, we ignore that one
            // if any of the other attachments is a supported type.
            // Otherwise we send the text-attachment
            var textItemProvider: NSItemProvider?
            for attachment in attachments {
                let itemProvider = attachment
                attachmentCountToLoad += 1
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    textItemProvider = nil
                    self.loadImage(itemProvider)
                } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                    textItemProvider = nil
                    self.loadVideo(itemProvider)
                } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                    textItemProvider = nil
                    containsFileType = true
                    self.loadAttachment(itemProvider)
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                    textItemProvider = nil
                    containsFileType = false
                    self.loadURL(itemProvider)
                } else if itemProvider.hasItemConformingToTypeIdentifier("public.text") {
                    if attachments.count == 1 {
                        self.loadText(itemProvider)
                    } else {
                        // we remember this one here for later use (in case there was no other supported attachment in this share-item)
                        textItemProvider = itemProvider
                    }
                }
            }
            if let textItemProvider = textItemProvider {
                self.loadText(textItemProvider)
            }
        }
        self.attachmentCountToLoad = attachmentCountToLoad
        if attachmentCountToLoad > 0 || self.textToSend != nil {
            self.queueSync.sync(flags: .barrier) { [weak self] in
                self?.checkSendMedia()
            }
        }
    }

    private func sendMedia(streamName: String?) {
        if textToSend == nil && containsFileType == false {
            let sendViewController = DPAGApplicationFacadeUI.imageOrVideoSendVC(mediaSourceType: .album, mediaResources: self.mediaResources, sendDelegate: self, enableMultiSelection: self.mediaResources.count > 0, enableAdd: false)
            sendViewController.title = streamName
            sendViewController.draft = nil
            self.navigationController?.pushViewController(sendViewController, animated: true)
        } else if containsFileType {
            self.sendAsFiles()
        } else {
            self.sendAsText()
        }
    }

    private func sendAsFiles() {
        guard let containerConfig = self.containerConfig, let configSending = self.configSending, let sendMessageOptionsShareExt = self.sendMessageOptionsShareExt else { return }
        var urlList: [URL] = []
        for resource in mediaResources {
            if let url = resource.mediaUrl {
                urlList.append(url)
            }
        }
        if urlList.count > 0 {
            DPAGChatHelper.sendMessageWithDelegate(self) { [weak self] recipients in
                if let strongSelf = self {
                    DPAGApplicationFacadeShareExt.sendMessageWorker.sendFiles(urlList, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: nil, toRecipients: recipients, config: containerConfig, configSending: configSending)
                    strongSelf.textToSend = nil
                    strongSelf.containsFileType = false
                }
            }
        }
    }
    
    //
    private func sendAsText() {
        guard let containerConfig = self.containerConfig, let configSending = self.configSending, let sendMessageOptionsShareExt = self.sendMessageOptionsShareExt else { return }
        DPAGChatHelper.sendMessageWithDelegate(self) { [weak self] recipients in
            if let strongSelf = self, let textToSend = strongSelf.textToSend {
                DPAGApplicationFacadeShareExt.sendMessageWorker.sendText(textToSend, toRecipients: recipients, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: nil, config: containerConfig, configSending: configSending)
                strongSelf.textToSend = nil
            }
        }
    }

    private func checkSendMedia() {
        if self.attachmentCountToLoad == self.mediaResources.count, self.willSend == false, self.hasError == false {
            self.willSend = true
            self.hideProgressHUD(animated: true) { [weak self] in
                guard let strongSelf = self else { return }
                if strongSelf.hasMaxLengthError {
                    strongSelf.presentErrorAlert(alertConfig: UIViewController.AlertConfigError(messageIdentifier: DPAGLocalizedString(strongSelf.mediaResources.count == 0 ? "share.extension.medias.hasMaxLengthErrorAll" : "share.extension.medias.hasMaxLengthError"), okActionHandler: { [weak self] _ in
                        guard let strongSelf = self else { return }
                        if strongSelf.mediaResources.count == 0 {
                            strongSelf.extensionDelegate?.dismiss()
                        }
                    }))
                } else if DPAGHelperEx.isNetworkReachable() == false {
                    strongSelf.extensionDelegate?.showError(text: DPAGLocalizedString("service.networkFailure"))
                }
            }
        } else if self.textToSend != nil {
            self.hideProgressHUD(animated: true) {
            }
        }
    }

    private func loadURL(_ itemProvider: NSItemProvider) { //
        itemProvider.loadItem(forTypeIdentifier: "public.url" as String, options: nil) { [weak self] item, _ in
            if let browserUrl = item as? URL {
                self?.textToSend = browserUrl.absoluteString
                self?.checkSendMedia()
            }
        }
    }
    
    private func loadText(_ itemProvider: NSItemProvider) { //
        itemProvider.loadItem(forTypeIdentifier: "public.text" as String, options: nil) { [weak self] item, _ in
            if let text = item as? String {
                self?.textToSend = text
                self?.checkSendMedia()
            }
        }
    }
    
    private func loadAttachment(_ itemProvider: NSItemProvider) { //
        itemProvider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { [weak self] item, error in
            guard let strongSelf = self else { return }
            if let error = error {
                strongSelf.extensionDelegate?.showError(text: error.localizedDescription)
                return
            }
            if let fileUrl = item as? URL {
                if strongSelf.hasError == false {
                    let mediaResource = DPAGMediaResource(type: .file)
                    mediaResource.mediaUrl = fileUrl
                    self?.performBlockOnMainThread {
                        self?.queueSync.sync(flags: .barrier) {
                            self?.mediaResources.append(mediaResource)
                            self?.checkSendMedia()
                        }
                    }
                }
            } else {
                strongSelf.extensionDelegate?.showError(text: "no movie loaded")
            }
        }
    }
    
    private func loadImage(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: DPAGApplicationFacadeShareExt.preferences.imageOptionsForSending.size)]) { [weak self] item, error in
            guard let strongSelf = self else { return }
            if let error = error {
                strongSelf.extensionDelegate?.showError(text: error.localizedDescription)
                return
            }
            if let imageUrl = item as? URL {
                if strongSelf.hasError == false {
                    let mediaResource = DPAGMediaResource(type: .image)
                    mediaResource.mediaUrl = imageUrl
                    itemProvider.loadPreviewImage(options: [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: DPAGConstantsGlobal.kChatMaxWidthObjects))]) { [weak self] item, _ in
                        if let image = item as? UIImage {
                            mediaResource.preview = image
                        }
                        self?.performBlockOnMainThread {
                            self?.queueSync.sync(flags: .barrier) {
                                self?.mediaResources.append(mediaResource)
                                self?.checkSendMedia()
                            }
                        }
                    }
                }
            } else if let image = item as? UIImage {
                // Since iOS 13, users can make screenshots and directly send that screenshot
                // Without ever saving the image to disk
                // In this case, we receive it as UIImage and save it first
                let mediaResource = DPAGMediaResource(type: .image)
                mediaResource.preview = image
                let data = image.jpegData(compressionQuality: 1.0)
                guard let incomingUrl = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent("incomingScreenShot", isDirectory: true).appendingPathComponent("screenshot").appendingPathExtension(".jpeg") else {
                    return
                }
                if FileManager.default.fileExists(atPath: incomingUrl.path) {
                    do {
                        try FileManager.default.removeItem(at: incomingUrl)
                    } catch {
                        DPAGLog(error)
                    }
                }
                do {
                    try FileManager.default.createDirectory(at: incomingUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                    try data?.write(to: incomingUrl)
                } catch {
                    DPAGLog(error, message: "Error writing media for saving to library")
                    return
                }
                mediaResource.mediaUrl = incomingUrl
                self?.performBlockOnMainThread {
                    self?.queueSync.sync(flags: .barrier) {
                        self?.mediaResources.append(mediaResource)
                        self?.checkSendMedia()
                    }
                }
            } else {
                strongSelf.extensionDelegate?.showError(text: "no image loaded")
            }
        }
    }

    private func loadVideo(_ itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: kUTTypeMovie as String, options: nil) { [weak self] item, error in
            guard let strongSelf = self else { return }
            if let error = error {
                strongSelf.extensionDelegate?.showError(text: error.localizedDescription)
                return
            }
            if let videoURL = item as? URL {
                if strongSelf.hasError == false {
                    let asset = AVURLAsset(url: videoURL)
                    if CMTimeGetSeconds(asset.duration) > DPAGApplicationFacadeShareExt.preferences.maxLengthForSentVideos {
                        strongSelf.attachmentCountToLoad -= 1
                        strongSelf.hasMaxLengthError = true
                        strongSelf.checkSendMedia()
                        return
                    }
                    let mediaResource = DPAGMediaResource(type: .video)
                    mediaResource.mediaUrl = videoURL
                    itemProvider.loadPreviewImage(options: [NSItemProviderPreferredImageSizeKey: NSValue(cgSize: CGSize(width: DPAGConstantsGlobal.kChatMaxWidthObjects, height: DPAGConstantsGlobal.kChatMaxWidthObjects))]) { [weak self] item, _ in
                        if let image = item as? UIImage {
                            mediaResource.preview = image
                        }
                        self?.performBlockOnMainThread {
                            self?.queueSync.sync(flags: .barrier) {
                                self?.mediaResources.append(mediaResource)
                                self?.checkSendMedia()
                            }
                        }
                    }
                }
            } else {
                strongSelf.extensionDelegate?.showError(text: "no movie loaded")
            }
        }
    }

    @objc
    private func dismissVC() {
        self.dismiss(animated: true) { [weak self] in
            self?.extensionDelegate?.dismiss()
        }
    }
}

extension DPAGShareExtSendingViewController: DPAGSendAVViewControllerDelegate {
    func sendObjects(with _: DPAGSendAVViewControllerProtocol, media mediaArray: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?) {
        guard let containerConfig = self.containerConfig, let configSending = self.configSending, let sendMessageOptionsShareExt = self.sendMessageOptionsShareExt else { return }
        DPAGChatHelper.sendMessageWithDelegate(self) { recipients in
            DPAGApplicationFacadeShareExt.sendMessageWorker.sendMedias(mediaArray, sendMessageOptionsShareExt: sendMessageOptionsShareExt, sendMessageOptions: sendOptions, toRecipients: recipients, config: containerConfig, configSending: configSending)
        }
    }
}

extension DPAGShareExtSendingViewController: DPAGSendingDelegate {
    func sendMessageResponseBlock() -> DPAGServiceResponseBlock {
        let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
            if let errorMessage = errorMessage {
                self?.extensionDelegate?.showError(text: errorMessage)
            }
        }
        return responseBlock
    }

    func updateViewBeforeMessageWillSend() {
        if let window = self.view.window {
            let progress: DPAGProgressHUDWithLabelProtocol? = DPAGProgressHUDWithLabel.sharedInstanceLabel.showForBackgroundProcess(true, in: window, completion: { _ in

            }) as? DPAGProgressHUDWithLabelProtocol
            progress?.labelTitle.text = DPAGLocalizedString("share.extension.sendMessage")
        }
    }

    func updateViewAfterMessageWasSent() {}

    func getRecipients() -> [DPAGSendMessageRecipient] {
        self.recipients
    }

    func updateRecipientsConfidenceState() {
        self.performBlockOnMainThread { [weak self] in
            DPAGLog("dismissing")
            if let window = self?.view.window {
                DPAGProgressHUD.sharedInstance.hide(true, in: window) { [weak self] in
                    self?.dismissVC()
                }
            } else {
                self?.dismissVC()
            }
        }
    }
}

class DPAGShareExtSendingErrorViewController: DPAGViewControllerBackground {
    fileprivate weak var extensionDelegate: DPAGShareExtSendingViewControllerDelegate?

    fileprivate var text: String?

    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissVC))

        UINavigationBar.appearance().barTintColor = DPAGColorProvider.shared[.navigationBar]
        UINavigationBar.appearance().tintColor = DPAGColorProvider.shared[.navigationBarTint]
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: DPAGColorProvider.shared[.navigationBarTint]]

        let scrollView = UIScrollView()

        self.view.addSubview(scrollView)
        scrollView.addSubview(self.label)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.label.font = UIFont.kFontBody
        self.label.textColor = DPAGColorProvider.shared[.labelText]
        self.label.numberOfLines = 0
        self.label.textAlignment = .center

        NSLayoutConstraint.activate(scrollView.constraintsFillSafeArea(subview: self.label, padding: 16) + self.view.constraintsFill(subview: scrollView))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.setNeedsStatusBarAppearanceUpdate()
        self.label.text = self.text
    }

    @objc
    private func dismissVC() {
        self.dismiss(animated: true) { [weak self] in
            self?.extensionDelegate?.dismiss()
        }
    }
}
