//
//  DPAGMediaDetailViewController.swift
//  SIMSme
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaDetailViewController: DPAGViewControllerBackground, DPAGMediaDetailViewControllerProtocol, DPAGViewControllerOrientationFlexibleIfPresented {
    var titleShow: String?
    // var colorNavigationBarBackground: UIColor
    // var colorNavigationBarText: UIColor
    // var statusBarStyle: UIStatusBarStyle

    private var currentPage: Int = 0

    private let pageViewController: UIPageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)

    private var mediaResources: [DPAGMediaResource] = []

    private var contentControllers: [Int: UIViewController & DPAGMediaContentViewControllerProtocol] = [:]

    private var buttonShareImage: UIBarButtonItem
    private var buttonShareVideo: UIBarButtonItem
    private var buttonShareFile: UIBarButtonItem
    private var buttonDelete: UIBarButtonItem
    private var buttonSpace: UIBarButtonItem

    private weak var contentViewDelegate: DPAGMediaContentViewDelegate?

    private var zoomingRect: CGRect = CGRect.null

    private var fileURLTemp: URL?
    private var openInController: UIDocumentInteractionController?
    private var openInControllerOpensApplication = false

    private let mediaResourceForwarding: DPAGMediaResourceForwarding?

    init(mediaResources: [DPAGMediaResource], index: Int, contentViewDelegate: DPAGMediaContentViewDelegate?, mediaResourceForwarding: DPAGMediaResourceForwarding?) {
        self.mediaResources = mediaResources
        self.currentPage = index
        self.contentViewDelegate = contentViewDelegate

        self.buttonShareImage = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageShare], style: .plain, target: nil, action: #selector(handleShareImageButtonPressed))
        self.buttonShareVideo = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageShare], style: .plain, target: nil, action: #selector(handleShareVideoButtonPressed))
        self.buttonShareFile = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageShare], style: .plain, target: nil, action: #selector(handleShareFileButtonPressed))
        self.buttonDelete = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageChatTrash], style: .plain, target: nil, action: #selector(handleDeleteButtonPressed))
        self.buttonSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        self.mediaResourceForwarding = mediaResourceForwarding

        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))

        self.buttonShareImage.target = self
        self.buttonShareVideo.target = self
        self.buttonShareFile.target = self
        self.buttonDelete.target = self

        self.buttonShareImage.accessibilityIdentifier = "buttonShareImage"
        self.buttonShareVideo.accessibilityIdentifier = "buttonShareVideo"
        self.buttonShareFile.accessibilityIdentifier = "buttonShareFile"
        self.buttonDelete.accessibilityIdentifier = "buttonDelete"
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        (self.navigationController?.isNavigationBarHidden ?? false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        (self.navigationController?.isNavigationBarHidden ?? false) ? DPAGColorProvider.shared[.defaultViewBackground].statusBarStyle(backgroundColor: DPAGColorProvider.shared[.defaultViewBackgroundInverted]) : super.preferredStatusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setUpGui()

        self.updateToolBar()

        self.pageViewController.view.frame = self.view.bounds

        self.extendedLayoutIncludesOpaqueBars = true
        self.pageViewController.extendedLayoutIncludesOpaqueBars = true

        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.view.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)

        if (self.navigationController?.viewControllers.count ?? 0) == 1 {
            self.setLeftBackBarButtonItem(action: #selector(dismissViewController))
        }
    }

    @objc
    private func dismissViewController() {
        self.dismissViewControllerAnimated(true)
    }

    private func dismissViewControllerAnimated(_ animated: Bool) {
        self.dismiss(animated: animated, completion: nil)
    }

    fileprivate func currentVC() -> (UIViewController & DPAGMediaContentViewControllerProtocol)? {
        self.contentControllers[self.currentPage]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        var vcCurrent = self.contentControllers[self.currentPage]
        if vcCurrent == nil, self.currentPage >= 0, self.mediaResources.count > self.currentPage {
            let mediaResource = self.mediaResources[self.currentPage]
            switch mediaResource.mediaType {
                case .image:
                    vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: self.currentPage, mediaResource: mediaResource)
                case .file:
                    vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentFileVC(index: self.currentPage, mediaResource: mediaResource)
                case .video, .voiceRec, .unknown:
                    vcCurrent = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: self.currentPage, mediaResource: mediaResource)
            }
            self.contentControllers[self.currentPage] = vcCurrent
        }
        vcCurrent?.customDelegate = self
        if let vcCurrent = vcCurrent {
            self.pageViewController.setViewControllers([vcCurrent], direction: .forward, animated: false, completion: nil)
        }
        self.pageViewController.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.title = self.titleShow ?? String(format: DPAGLocalizedString("settings.media.detail.title"), (vcCurrent?.index ?? 0) + 1, self.mediaResources.count)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.navigationController?.setToolbarHidden(true, animated: false)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        self.navigationController?.setToolbarHidden(false, animated: animated)
        self.view.backgroundColor = UIColor.clear
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
            self?.dismissViewControllerAnimated(false)
        })
        self.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            if let strongSelf = self {
                (strongSelf.navigationController as? DPAGNavigationControllerProtocol)?.copyToolBarStyle(navVCSrc: strongSelf.navigationController)
            }
        }, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        (self.navigationController as? DPAGNavigationControllerProtocol)?.copyToolBarStyle(navVCSrc: self.navigationController)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setUpGui() {
        self.pageViewController.delegate = self
        self.pageViewController.dataSource = self
    }
}

extension DPAGMediaDetailViewController: DPAGDefaultTransitionerDelegate {
    func preparePresentationWithZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.preparePresentationWithZoomingRect(zoomingRect)
    }

    func animatePresentationZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.animatePresentationZoomingRect(zoomingRect)
    }

    func completePresentationZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.completePresentationZoomingRect(zoomingRect)
    }

    func prepareDismissalWithZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.prepareDismissalWithZoomingRect(zoomingRect)
    }

    func animateDismissalZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.animateDismissalZoomingRect(zoomingRect)
    }

    func completeDismissalZoomingRect(_ zoomingRect: CGRect) {
        self.currentVC()?.completeDismissalZoomingRect(zoomingRect)
    }

    func mediaResourceShown() -> DPAGMediaResource? {
        self.currentVC()?.mediaResourceShown()
    }
}

// MARK: page data source

extension DPAGMediaDetailViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        var idxBefore = 0
        let vcCurrent = viewController as? (UIViewController & DPAGMediaContentViewControllerProtocol)

        if let vcCurrent = vcCurrent {
            if vcCurrent.index - 1 < 0 {
                return nil
            }

            idxBefore = vcCurrent.index - 1
        }

        var vcBefore = self.contentControllers[idxBefore]

        if let vcBefore = vcBefore {
            if let vcCurrent = vcCurrent {
                vcBefore.view.frame = vcCurrent.view.frame
            }
            return vcBefore
        }

        let mediaResource = self.mediaResources[idxBefore]

        if mediaResource.mediaType == .image {
            vcBefore = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: idxBefore, mediaResource: mediaResource)
        } else if mediaResource.mediaType == .file {
            vcBefore = DPAGApplicationFacadeUIMedia.mediaContentFileVC(index: idxBefore, mediaResource: mediaResource)
        } else {
            vcBefore = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: idxBefore, mediaResource: mediaResource)
        }
        vcBefore?.customDelegate = self

        if let vcBefore = vcBefore {
            self.contentControllers[idxBefore] = vcBefore
        }

        return vcBefore
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

        var vcAfter = self.contentControllers[idxAfter]

        if let vcAfter = vcAfter {
            if let vcCurrent = vcCurrent {
                vcAfter.view.frame = vcCurrent.view.frame
            }
            return vcAfter
        }

        let mediaResource = self.mediaResources[idxAfter]

        if mediaResource.mediaType == .image {
            vcAfter = DPAGApplicationFacadeUIMedia.mediaContentImageVC(index: idxAfter, mediaResource: mediaResource)
        } else if mediaResource.mediaType == .file {
            vcAfter = DPAGApplicationFacadeUIMedia.mediaContentFileVC(index: idxAfter, mediaResource: mediaResource)
        } else {
            vcAfter = DPAGApplicationFacadeUIMedia.mediaContentVideoVC(index: idxAfter, mediaResource: mediaResource)
        }
        vcAfter?.customDelegate = self

        if let vcAfter = vcAfter {
            self.contentControllers[idxAfter] = vcAfter
        }

        return vcAfter
    }

    // MARK: - page delegate

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        for vc in pendingViewControllers {
            vc.view.backgroundColor = pageViewController.viewControllers?.first?.view.backgroundColor
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating _: Bool, previousViewControllers _: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let vcCurrent = pageViewController.viewControllers?.last as? DPAGMediaContentViewControllerProtocol {
                self.currentPage = vcCurrent.index

                self.title = String(format: DPAGLocalizedString("settings.media.detail.title"), vcCurrent.index + 1, self.mediaResources.count)
            }
            self.updateToolBar()
        }
    }

    private func updateToolBar() {
        var toolbarItems: [UIBarButtonItem] = []

        if self.currentPage >= 0, self.mediaResources.count > self.currentPage {
            switch self.mediaResources[self.currentPage].mediaType {
            case .video:

                let itemsDefault = [self.buttonSpace, self.buttonDelete]

                if self.mediaResourceForwarding != nil, DPAGApplicationFacade.preferences.canExportMedia || DPAGApplicationFacade.preferences.canSendMedia {
                    toolbarItems = [self.buttonShareVideo] + itemsDefault
                } else {
                    toolbarItems = itemsDefault
                }

            case .voiceRec, .unknown:

                toolbarItems = [self.buttonSpace, self.buttonDelete]

            case .file:

                let itemsDefault = [self.buttonSpace, self.buttonDelete]

                if self.mediaResourceForwarding != nil, DPAGApplicationFacade.preferences.canExportMedia || DPAGApplicationFacade.preferences.canSendMedia {
                    toolbarItems = [self.buttonShareFile] + itemsDefault
                } else {
                    toolbarItems = itemsDefault
                }

            case .image:

                let itemsDefault = [self.buttonSpace, self.buttonDelete]

                if self.mediaResourceForwarding != nil, DPAGApplicationFacade.preferences.canExportMedia || DPAGApplicationFacade.preferences.canSendMedia {
                    toolbarItems = [self.buttonShareImage] + itemsDefault
                } else {
                    toolbarItems = itemsDefault
                }
            }
        }

        self.toolbarItems = toolbarItems
    }

    private func handleShare(title: String, exportOptionTitle: String, sendOptionTitle: String, buttonPressed: UIBarButtonItem) {
        var alertOptions: [AlertOption] = []
        if DPAGApplicationFacade.preferences.canSendMedia {
            alertOptions.append(AlertOption(title: DPAGLocalizedString(sendOptionTitle), style: .default) { [weak self] in
                self?.handleForwardData()
            })
        }
        if DPAGApplicationFacade.preferences.canExportMedia {
            alertOptions.append(AlertOption(title: DPAGLocalizedString(exportOptionTitle), style: .default) { [weak self] in
                self?.handleSaveData(buttonPressed: buttonPressed)
            })
        }
        alertOptions.append(AlertOption.cancelOption())
        let alertController = UIAlertController.controller(options: alertOptions, withStyle: .alert, accessibilityIdentifier: title, barButtonItem: buttonPressed)
        self.presentAlertController(alertController)
    }

    @objc
    private func handleShareImageButtonPressed() {
        self.handleShare(title: "action_share_image", exportOptionTitle: "chats.showPicture.save", sendOptionTitle: "chats.title.forwardMessage", buttonPressed: self.buttonShareImage)
    }

    @objc
    private func handleShareVideoButtonPressed() {
        self.handleShare(title: "action_share_video", exportOptionTitle: "chats.showVideo.save", sendOptionTitle: "chats.title.forwardMessage", buttonPressed: self.buttonShareVideo)
    }

    @objc
    private func handleShareFileButtonPressed() {
        self.handleShare(title: "action_share_file", exportOptionTitle: "chats.showFile.save", sendOptionTitle: "chats.title.forwardMessage", buttonPressed: self.buttonShareFile)
    }

    @objc
    private func handleDeleteButtonPressed() {
        let alertOptionDelete = AlertOption(title: DPAGLocalizedString("chats.deleteAttachment.actionSheetDelete"), style: .destructive) { [weak self] in
            self?.handleDeleteAttachment()
        }
        let alertController = UIAlertController.controller(options: [alertOptionDelete, AlertOption.cancelOption()], accessibilityIdentifier: "action_delete_media", barButtonItem: self.buttonDelete)
        self.presentAlertController(alertController)
    }

    private func handleDeleteAttachment() {
        if self.mediaResources.count > 1, let vcCurrent = self.pageViewController.viewControllers?.last as? (UIViewController & DPAGMediaContentViewControllerProtocol) {
            var newVCs: [UIViewController & DPAGMediaContentViewControllerProtocol] = []

            if let vcNext = self.pageViewController(self.pageViewController, viewControllerAfter: vcCurrent) as? (UIViewController & DPAGMediaContentViewControllerProtocol) {
                newVCs.append(vcNext)
            } else if let vcPrevious = self.pageViewController(self.pageViewController, viewControllerBefore: vcCurrent) as? (UIViewController & DPAGMediaContentViewControllerProtocol) {
                newVCs.append(vcPrevious)
            }

            var newAttachments = self.mediaResources
            let attachmentToDelete = newAttachments[self.currentPage]

            newAttachments.remove(at: self.currentPage)

            if let attachment = attachmentToDelete.attachment {
                self.contentViewDelegate?.deleteAttachment(attachment)
            }
            self.currentPage = max(0, min(self.currentPage, newAttachments.count - 1))
            self.mediaResources = newAttachments

            self.pageViewController.setViewControllers(newVCs, direction: .forward, animated: false) { [weak self] _ in

                guard let strongSelf = self else { return }

                var contentControllersNew: [Int: UIViewController & DPAGMediaContentViewControllerProtocol] = [:]

                for (_, vcContent) in strongSelf.contentControllers {
                    if vcContent.index > vcCurrent.index {
                        vcContent.index -= 1
                        contentControllersNew[vcContent.index] = vcContent
                    } else if vcContent.index < vcCurrent.index {
                        contentControllersNew[vcContent.index] = vcContent
                    }
                }

                strongSelf.contentControllers = contentControllersNew
                strongSelf.title = String(format: DPAGLocalizedString("settings.media.detail.title"), (newVCs.last?.index ?? -1) + 1, strongSelf.mediaResources.count)
                strongSelf.updateToolBar()
            }
        } else {
            if let attachment = self.mediaResources[self.currentPage].attachment {
                self.contentViewDelegate?.deleteAttachment(attachment)
            }

            self.dismissViewController()
        }
    }

    private func handleSaveData(buttonPressed: UIBarButtonItem) {
        let vcCurrent = self.pageViewController.viewControllers?.last as? DPAGMediaContentViewControllerProtocol

        if vcCurrent is DPAGMediaContentImageViewControllerProtocol {
            (vcCurrent as? DPAGMediaContentImageViewControllerProtocol)?.saveToLibrary(buttonPressed: buttonPressed)
        } else if vcCurrent is DPAGMediaContentVideoViewControllerProtocol {
            (vcCurrent as? DPAGMediaContentVideoViewControllerProtocol)?.saveToLibrary(buttonPressed: buttonPressed)
        } else if vcCurrent is DPAGMediaContentFileViewControllerProtocol {
            if let mediaResource = vcCurrent?.mediaResource {
                self.setUpFileViewWithData(mediaResource)
            }
        }
    }

    private func handleForwardData() {
        let mediaResource = self.mediaResources[self.currentPage]

        self.mediaResourceForwarding?(mediaResource)
    }

    private func setUpFileViewWithData(_ data: DPAGMediaResource) {
        if let fileName = data.additionalData?.fileName {
            self.openFileData(data, fileName: fileName)
        }
        /*
        if let fileName = data.additionalData?.fileName {
            let actionOK = UIAlertAction(titleIdentifier: "res.ok", style: .destructive, handler: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.openFileData(data, fileName: fileName)
            })
            self.presentAlert(alertConfig: AlertConfig(titleIdentifier: DPAGLocalizedString("chat.message.fileOpen.warning.title"), messageIdentifier: "chat.message.fileOpen.warning.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionOK]))
        }
         */
    }

    private func openFileData(_ data: DPAGMediaResource, fileName: String) {
        let fileURLTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
        self.fileURLTemp = fileURLTemp
        if FileManager.default.fileExists(atPath: fileURLTemp.path) {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
        }
        try? data.mediaContent?.write(to: fileURLTemp, options: [.atomic])
        self.openInController = UIDocumentInteractionController(url: fileURLTemp)
        self.openInController?.delegate = self
        self.openInControllerOpensApplication = false
        if self.openInController?.presentPreview(animated: true) == false {
            if self.openInController?.presentOpenInMenu(from: self.buttonShareFile, animated: true) == false {
                DPAGHelperEx.clearInboxFolder()
                self.fileURLTemp = nil
                self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.noAppToOpenInFound.message"))
            }
        }
    }
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }

}

// MARK: - contentView Delegate

extension DPAGMediaDetailViewController: DPAGMediaDetailViewDelegate {
    func contentViewRecognizedSingleTap(_: UIViewController) {
        if let navigationController = self.navigationController {
            let navigationBarHidden = (navigationController.navigationBar.alpha == 0) || navigationController.isNavigationBarHidden

            self.pageViewController.navigationController?.setNavigationBarHidden(navigationBarHidden == false, animated: true)
            self.pageViewController.navigationController?.setToolbarHidden(navigationBarHidden == false, animated: true)

            UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

                self?.setNeedsStatusBarAppearanceUpdate()
                self?.view.backgroundColor = navigationBarHidden ? DPAGColorProvider.shared[.defaultViewBackground] : DPAGColorProvider.shared[.defaultViewBackgroundInverted]
            })
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                if let navigationController = self.navigationController {
                    let navigationBarHidden = (navigationController.navigationBar.alpha == 0) || navigationController.isNavigationBarHidden
                    self.view.backgroundColor = navigationBarHidden ? DPAGColorProvider.shared[.defaultViewBackground] : DPAGColorProvider.shared[.defaultViewBackgroundInverted]
                }
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func updateBackgroundColor(_ backgroundColor: UIColor) {
        self.view.backgroundColor = backgroundColor
    }
}

extension DPAGMediaDetailViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerDidDismissOpenInMenu(_: UIDocumentInteractionController) {
        if self.openInControllerOpensApplication == false, self.fileURLTemp != nil {
            DPAGHelperEx.clearInboxFolder()

            self.fileURLTemp = nil
        }
    }

    func documentInteractionController(_: UIDocumentInteractionController, willBeginSendingToApplication _: String?) {
        self.openInControllerOpensApplication = true
    }

    func documentInteractionController(_: UIDocumentInteractionController, didEndSendingToApplication _: String?) {
        if self.fileURLTemp != nil {
            DPAGHelperEx.clearInboxFolder()

            self.fileURLTemp = nil
        }
    }
}
