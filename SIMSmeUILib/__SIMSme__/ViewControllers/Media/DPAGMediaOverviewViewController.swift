//
//  DPAGMediaOverviewViewController.swift
// ginlo
//
//  Created by RBU on 24.04.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaOverviewViewControllerBase: DPAGViewControllerBackground, DPAGMediaOverviewViewControllerBaseProtocol, DPAGViewControllerOrientationFlexibleIfPresented {
    fileprivate let mediaResourceForwarding: DPAGMediaResourceForwarding?

    fileprivate let pageViewController: UIPageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let viewButtonFrame = UIView()
    let stackViewButtons: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        return stackView
    }()

    lazy var buttonMedia: UIButton = {
        let buttonMedia = UIButton(type: .custom)
        buttonMedia.accessibilityIdentifier = "buttonMedia"
        buttonMedia.setTitle(DPAGLocalizedString("settings.profile.mediaLabel").uppercased(), for: .normal)
        buttonMedia.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        buttonMedia.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        buttonMedia.titleLabel?.font = UIFont.kFontFootnote
        NSLayoutConstraint.activate([buttonMedia.constraintHeight(56)])
        buttonMedia.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
        buttonMedia.addTargetClosure { [weak self] _ in
            self?.buttonMedia.isSelected = true
            self?.buttonFiles.isSelected = false
            self?.searchController?.searchBar.text = nil
            if let vcMedia = self?.vcMedia {
                self?.pageViewController.setViewControllers([vcMedia], direction: .reverse, animated: true, completion: nil)
                self?.vcFiles.resetSelection()
            }
            (self as? DPAGMediaOverviewViewControllerDelegate)?.updateToolbar()
        }
        return buttonMedia
    }()

    lazy var buttonFiles: UIButton = {
        let buttonFiles = UIButton(type: .custom)
        buttonFiles.accessibilityIdentifier = "buttonFiles"
        buttonFiles.setTitle(DPAGLocalizedString("settings.media.files").uppercased(), for: .normal)
        buttonFiles.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        buttonFiles.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        buttonFiles.titleLabel?.font = UIFont.kFontFootnote
        NSLayoutConstraint.activate([buttonFiles.constraintHeight(56)])
        buttonFiles.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
        buttonFiles.addTargetClosure { [weak self] _ in
            self?.buttonMedia.isSelected = false
            self?.buttonFiles.isSelected = true
            self?.searchController?.searchBar.text = nil
            if let vcFiles = self?.vcFiles {
                self?.pageViewController.setViewControllers([vcFiles], direction: .forward, animated: true, completion: nil)
                self?.vcMedia.resetSelection()
            }
            (self as? DPAGMediaOverviewViewControllerDelegate)?.updateToolbar()
        }
        return buttonFiles
    }()

    fileprivate let vcMedia = DPAGApplicationFacadeUIMedia.mediaVC()
    fileprivate let vcFiles = DPAGApplicationFacadeUIMedia.mediaFilesVC()

    var searchController: UISearchController?
    fileprivate var showFiles = true

    fileprivate init(mediaResourceForwarding: DPAGMediaResourceForwarding?) {
        self.mediaResourceForwarding = mediaResourceForwarding
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(self.stackView)
    
        if #available(iOS 13.0, *) {
            NSLayoutConstraint.activate([
                self.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: self.stackView.topAnchor),
                self.view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: self.stackView.bottomAnchor),
                self.view.leadingAnchor.constraint(equalTo: self.stackView.leadingAnchor),
                self.view.trailingAnchor.constraint(equalTo: self.stackView.trailingAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                self.view.topAnchor.constraint(equalTo: self.stackView.topAnchor),
                self.view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: self.stackView.bottomAnchor),
                self.view.leadingAnchor.constraint(equalTo: self.stackView.leadingAnchor),
                self.view.trailingAnchor.constraint(equalTo: self.stackView.trailingAnchor)
            ])
        }
        if self.showFiles {
            self.stackViewButtons.addArrangedSubview(self.buttonMedia)
            self.stackViewButtons.addArrangedSubview(self.buttonFiles)
        } else {
            NSLayoutConstraint.activate([self.stackViewButtons.constraintHeight(0)])
        }
        self.stackView.addArrangedSubview(self.stackViewButtons)
        self.title = DPAGLocalizedString("settings.mediaFiles")
        self.buttonMedia.isSelected = true
        self.buttonFiles.isSelected = false
        self.pageViewController.setViewControllers([self.vcMedia], direction: .forward, animated: false, completion: nil)
        self.pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.stackView.addArrangedSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.configureSearchBar()
    }

    private func configureSearchBar() {
        let placeholder = "android.serach.placeholder"
        let searchResultsController = DPAGApplicationFacadeUIMedia.mediaOverviewSearchResultsVC(delegate: self)
        let searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchBar.placeholder = DPAGLocalizedString(placeholder)
        searchController.searchBar.accessibilityIdentifier = placeholder
        searchController.searchBar.delegate = self
        searchController.delegate = self
        self.navigationItem.searchController = searchController
        self.definesPresentationContext = true
    
        if #available(iOS 13.0, *) {
            self.extendedLayoutIncludesOpaqueBars = true
            self.edgesForExtendedLayout = .all
        }
        self.searchController = searchController
        self.vcMedia.searchResultsController = searchResultsController
        self.vcFiles.searchResultsController = searchResultsController
        DPAGUIHelper.customizeSearchBar(searchController.searchBar)
    }
    
    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        buttonFiles.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        buttonFiles.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        buttonMedia.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        buttonMedia.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        if let searchBar = self.navigationItem.searchController?.searchBar {
            DPAGUIHelper.customizeSearchBar(searchBar)
        }
    }

}

extension DPAGMediaOverviewViewControllerBase: DPAGMediaOverviewSearchResultsViewControllerDelegate {
    func setupCell(_ cell: UITableViewCell & DPAGMediaFileTableViewCellProtocol, with attachment: DPAGDecryptedAttachment) {
        (self.pageViewController.viewControllers?.last as? DPAGMediaOverviewSearchResultsViewControllerDelegate)?.setupCell(cell, with: attachment)
    }

    func didSelectMedia(_ attachment: DPAGMediaViewAttachmentProtocol) {
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) { [weak self] in
                (self?.pageViewController.viewControllers?.last as? DPAGMediaOverviewSearchResultsViewControllerDelegate)?.didSelectMedia(attachment)
            }
        } else {
            (self.pageViewController.viewControllers?.last as? DPAGMediaOverviewSearchResultsViewControllerDelegate)?.didSelectMedia(attachment)
        }
    }
}

extension DPAGMediaOverviewViewControllerBase: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        (self.pageViewController.viewControllers?.last as? UISearchBarDelegate)?.searchBar?(searchBar, textDidChange: searchText)
    }
}

extension DPAGMediaOverviewViewControllerBase: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        (self.pageViewController.viewControllers?.last as? UISearchControllerDelegate)?.willPresentSearchController?(searchController)
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        (self.pageViewController.viewControllers?.last as? UISearchControllerDelegate)?.willDismissSearchController?(searchController)
    }
}

extension DPAGMediaOverviewViewController: UIPageViewControllerDelegate {}

extension DPAGMediaOverviewViewController: DPAGMediaOverviewViewControllerDelegate {
    func updateToolbar() {
        if self.pageViewController.viewControllers?.last == self.vcFiles {
            self.buttonDelete.isEnabled = self.isEditing && self.vcFiles.selection.count > 0
            self.toolbarItems = [self.buttonFlex, self.buttonDelete]
        } else {
            self.buttonDelete.isEnabled = self.isEditing && self.vcMedia.selection.count > 0
            self.labelLabelText.text = self.vcMedia.toolbarText()
            self.labelLabelText.sizeToFit()
            self.toolbarItems = [self.buttonFlex, self.buttonLabelText, self.buttonFlex, self.buttonDelete]
        }
        self.navigationController?.toolbar.backgroundColor = .clear
        self.navigationController?.toolbar.barTintColor = DPAGColorProvider.shared[.defaultViewBackground]
    }
}

extension DPAGMediaOverviewViewController: DPAGNavigationViewControllerStyler {
    func configureNavigationWithStyle() {
        if let navigationController = self.navigationController as? (UINavigationController & DPAGNavigationControllerProtocol) {
            navigationController.resetNavigationBarStyle()
            navigationController.copyToolBarStyle(navVCSrc: navigationController)
        }
    }
}

class DPAGMediaOverviewViewController: DPAGMediaOverviewViewControllerBase, DPAGViewControllerNavigationTitleBig {
    fileprivate let buttonFlex: UIBarButtonItem
    fileprivate var buttonDelete: UIBarButtonItem
    fileprivate let buttonLabelText: UIBarButtonItem
    fileprivate let labelLabelText: UILabel = {
        let retVal = UILabel()
        retVal.font = UIFont.kFontHeadline
        retVal.textColor = DPAGColorProvider.shared[.labelText]
        return retVal
    }()

    fileprivate var openInController: UIDocumentInteractionController?
    fileprivate var openInControllerOpensApplication = true
    fileprivate var fileURLTemp: URL?

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.buttonDelete.tintColor = DPAGColorProvider.shared[.labelText]
        self.labelLabelText.textColor = DPAGColorProvider.shared[.labelText]
        self.navigationController?.toolbar.backgroundColor = .clear
        self.navigationController?.toolbar.barTintColor = DPAGColorProvider.shared[.defaultViewBackground]
    }
    
    init(mediaResourceForwarding: @escaping DPAGMediaResourceForwarding) {
        self.buttonFlex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        self.buttonLabelText = UIBarButtonItem(customView: self.labelLabelText)
        self.buttonDelete = UIBarButtonItem(image: DPAGImageProvider.shared[.kImageChatTrash], style: .plain, target: nil, action: #selector(deleteSelectedItems))
        self.buttonDelete.tintColor = DPAGColorProvider.shared[.labelText]
        super.init(mediaResourceForwarding: mediaResourceForwarding)
        self.buttonDelete.target = self
        self.buttonDelete.accessibilityIdentifier = "buttonDelete"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.vcFiles.mediaOverviewDelegate = self
        self.vcMedia.mediaOverviewDelegate = self
        self.vcFiles.mediaSelectDelegate = self
        self.vcMedia.mediaSelectDelegate = self
        self.vcFiles.tableView.allowsSelection = DPAGApplicationFacade.preferences.canExportMedia
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.vcMedia.setEditing(editing, animated: animated)
        self.vcFiles.setEditing(editing, animated: animated)
        if editing == false {
            self.buttonDelete.isEnabled = false
            self.vcFiles.tableView.allowsSelection = DPAGApplicationFacade.preferences.canExportMedia
        }
        self.vcFiles.isSelectionMarked = editing
        self.vcMedia.isSelectionMarked = editing
        self.updateToolbar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setToolbarHidden(false, animated: false)
        self.updateToolbar()
    }

    @objc
    private func deleteSelectedItems() {
        let deleteItems = AlertOption(title: DPAGLocalizedString("media.list.confirm.delete_selected_items.action.title"), style: .destructive, accesibilityIdentifier: "media.list.confirm.delete_selected_items.action.title", handler: { [weak self] in
            self?.commitDeleteSelectedItems()
        })
        let cancel = AlertOption.cancelOption()
        let alertController = UIAlertController.controller(options: [deleteItems, cancel], titleKey: "media.list.confirm.delete_selected_items.title", barButtonItem: self.buttonDelete)
        self.presentAlertController(alertController)
    }

    private func commitDeleteSelectedItems() {
        if self.pageViewController.viewControllers?.last == self.vcFiles {
            for attachment in self.vcFiles.selection {
                if let attachmentGuid = attachment.decryptedAttachment?.attachmentGuid {
                    DPAGAttachmentWorker.removeEncryptedAttachment(guid: attachmentGuid)
                }
            }
            self.vcFiles.removeSelectedAttachments()
            self.updateToolbar()
        } else {
            for attachment in self.vcMedia.selection {
                if let attachmentGuid = attachment.decryptedAttachment?.attachmentGuid {
                    DPAGAttachmentWorker.removeEncryptedAttachment(guid: attachmentGuid)
                }
            }
            self.vcMedia.removeSelectedAttachments()
            self.updateToolbar()
        }
    }
}

extension DPAGMediaOverviewViewController: DPAGMediaSelectViewControllerDelegate {
    func didSelectAttachment(_ attachment: DPAGMediaViewAttachmentProtocol?) {
        if self.isEditing {
            if self.pageViewController.viewControllers?.last == self.vcFiles {
                self.buttonDelete.isEnabled = self.vcFiles.selection.count > 0
            } else {
                self.buttonDelete.isEnabled = self.vcMedia.selection.count > 0
            }
        } else if let attachment = attachment {
            guard let decryptedAttachment = attachment.decryptedAttachment else { return }
            if self.pageViewController.viewControllers?.last == self.vcFiles {
                self.getDecAttachment(decryptedAttachment)
            } else if let idx = self.vcMedia.attachments.firstIndex(where: { (attachmentCheck) -> Bool in
                attachment.messageGuid == attachmentCheck.messageGuid
            }) {
                self.updateToolbar()
                let detailViewController = DPAGApplicationFacadeUIMedia.mediaDetailVC(mediaResources: self.vcMedia.attachments.compactMap {
                    if let attachment = $0.decryptedAttachment {
                        let mediaResource = DPAGMediaResource(type: attachment.attachmentType)
                        mediaResource.attachment = $0.decryptedAttachment
                        return mediaResource
                    }
                    return nil
                }, index: idx, contentViewDelegate: self, mediaResourceForwarding: self.mediaResourceForwarding)
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: detailViewController)
                navVC.modalPresentationStyle = .custom
                navVC.transitioningDelegateZooming = DPAGApplicationFacadeUIBase.defaultAnimatedTransitioningDelegate()
                navVC.transitioningDelegate = navVC.transitioningDelegateZooming
                navVC.copyNavigationBarStyle(navVCSrc: self.navigationController)
                self.present(navVC, animated: true, completion: nil)
            }
        }
    }

    private func getDecAttachment(_ attachment: DPAGDecryptedAttachment) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGAttachmentWorker.loadAttachment(attachment.attachmentGuid, forMessageGuid: attachment.messageGuid, progress: nil, withResponse: DPAGAttachmentWorker.loadAttachmentResponseBlockWithAttachmentLoader(self, attachment: attachment, loadingFinishedCompletion: { [weak self] mediaResource in
                guard self != nil else { return }
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    guard let strongSelf = self, let mediaResource = mediaResource else { return }
                    strongSelf.openFileData(mediaResource)
                }
            }))
        }
    }
}

extension DPAGMediaOverviewViewController: DPAGDefaultTransitionerZoomingBase {
    func zoomingViewForNavigationTransitionInView(_ inView: UIView, mediaResource: DPAGMediaResource?) -> CGRect {
        var view: UIView?
        if let attachment = mediaResource?.attachment {
            if let idxObj = self.vcMedia.attachments.firstIndex(where: { (messageAttachment) -> Bool in
                messageAttachment.decryptedAttachment?.attachmentGuid == attachment.attachmentGuid
            }) {
                let cell = self.vcMedia.mediaOverView.cellForItem(at: IndexPath(item: idxObj, section: 0))
                if let cellMedia = cell as? DPAGMediaCollectionViewCellProtocol {
                    view = cellMedia.imageView
                } else {
                    view = cell
                }
            }
        }
        if view == nil, let selectedIndexPath = self.vcMedia.selectedIndexPath {
            if self.vcMedia.collectionView(self.vcMedia.mediaOverView, numberOfItemsInSection: selectedIndexPath.section) <= selectedIndexPath.item {
                self.vcMedia.selectedIndexPath = nil
                return .null
            }
            let cell = self.vcMedia.mediaOverView.cellForItem(at: selectedIndexPath)
            if let cellMedia = cell as? DPAGMediaCollectionViewCellProtocol {
                view = cellMedia.imageView
            } else {
                view = cell
            }
        }
        if let view = view {
            return inView.convert(view.frame, from: view.superview ?? self.vcMedia.mediaOverView)
        }
        return .null
    }
}

extension DPAGMediaOverviewViewController: DPAGMediaAttachmentDelegate {
    func pickingMediaFinished(mediaResource _: DPAGMediaResource?, errorMessage: String?) {
        if let errorMessage = errorMessage {
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
        }
    }
}

extension DPAGMediaOverviewViewController: DPAGMediaContentViewDelegate {
    func deleteAttachment(_ decryptedAttachment: DPAGDecryptedAttachment) {
        if self.pageViewController.viewControllers?.last == self.vcMedia {
            DPAGAttachmentWorker.removeEncryptedAttachment(guid: decryptedAttachment.attachmentGuid)
            self.vcMedia.removeAttachment(decryptedAttachment)
            self.updateToolbar()
        }
    }
}

extension DPAGMediaOverviewViewController: UIDocumentInteractionControllerDelegate {
    fileprivate func openFileData(_ attachment: DPAGMediaResource) {
        let fileName = attachment.additionalData?.fileName ?? "noname"
        let fileURLTemp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(fileName)
        self.fileURLTemp = fileURLTemp
        if FileManager.default.fileExists(atPath: fileURLTemp.path) {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
        }
        try? attachment.mediaContent?.write(to: fileURLTemp, options: [.atomic])
        self.openInController = UIDocumentInteractionController(url: fileURLTemp)
        self.openInController?.delegate = self
        self.openInControllerOpensApplication = false
        if self.openInController?.presentPreview(animated: true) == false {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: "chat.message.fileOpen.error.noAppToOpenInFound.message"))
        }
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }

    func documentInteractionControllerDidDismissOpenInMenu(_: UIDocumentInteractionController) {
        if self.openInControllerOpensApplication == false, let fileURLTemp = self.fileURLTemp {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.fileURLTemp = nil
        }
    }

    func documentInteractionController(_: UIDocumentInteractionController, willBeginSendingToApplication _: String?) {
        self.openInControllerOpensApplication = true
    }

    func documentInteractionController(_: UIDocumentInteractionController, didEndSendingToApplication _: String?) {
        if let fileURLTemp = self.fileURLTemp {
            do {
                try FileManager.default.removeItem(at: fileURLTemp)
            } catch {
                DPAGLog(error)
            }
            self.fileURLTemp = nil
        }
    }
}

class DPAGMediaSelectSingleViewController: DPAGMediaOverviewViewControllerBase, DPAGMediaSelectSingleViewControllerProtocol {
    weak var mediaPickerDelegate: DPAGMediaPickerDelegate?

    init(showFiles: Bool) {
        super.init(mediaResourceForwarding: nil)
        self.showFiles = showFiles
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setEditing(true, animated: true)
        self.vcFiles.tableView.allowsMultipleSelection = false
        self.vcMedia.mediaOverView.allowsMultipleSelection = false
        self.vcFiles.mediaSelectDelegate = self
        self.vcMedia.mediaSelectDelegate = self
        self.vcFiles.isSelectionMarked = false
        self.vcMedia.isSelectionMarked = false
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    fileprivate func getDecAttachment(_ attachment: DPAGDecryptedAttachment) {
        let decResource = DPAGAttachmentWorker.resourceFromAttachment(attachment)
        self.pickingMediaFinished(mediaResource: decResource.mediaResource, errorMessage: decResource.errorMessage)
    }
}

extension DPAGMediaSelectSingleViewController: DPAGMediaSelectViewControllerDelegate {
    func didSelectAttachment(_ attachment: DPAGMediaViewAttachmentProtocol?) {
        guard let decAttachment = attachment?.decryptedAttachment else { return }
        self.getDecAttachment(decAttachment)
    }
}

extension DPAGMediaSelectSingleViewController: DPAGMediaAttachmentDelegate {
    func pickingMediaFinished(mediaResource: DPAGMediaResource?, errorMessage: String?) {
        self.dismiss(animated: true, completion: { [weak self] in
            if let errorMessage = errorMessage {
                self?.mediaPickerDelegate?.pickingMediaFailedWithError(errorMessage)
            } else if let mediaResource = mediaResource {
                self?.mediaPickerDelegate?.didFinishedPickingMediaResource(mediaResource)
            }
        })
    }
}

class DPAGMediaSelectMultiViewController: DPAGMediaOverviewViewControllerBase, DPAGMediaSelectMultiViewControllerProtocol {
    weak var mediaMultiPickerDelegate: DPAGMediaMultiPickerDelegate?

    init(selectionType: DPAGMediaSelectionOptions, selection: [DPAGDecryptedAttachment]) {
        super.init(mediaResourceForwarding: nil)
        self.vcMedia.selectedMediaType = selectionType
        var selectionFull: [DPAGMediaViewAttachmentProtocol] = []
        for decAttachment in selection {
            selectionFull.append(DPAGMediaViewAttachment(messageGuid: decAttachment.messageGuid, decryptedAttachment: decAttachment))
        }
        self.vcMedia.selection = selectionFull
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setRightBarButtonItemWithText(DPAGLocalizedString("navigation.done"), action: #selector(handleNavigationRightBarButton), accessibilityLabelIdentifier: "navigation.done")
        self.setEditing(true, animated: true)
        self.vcMedia.mediaOverView.allowsMultipleSelection = true
        self.vcFiles.mediaSelectDelegate = self
        self.vcMedia.mediaSelectDelegate = self
        self.vcFiles.isSelectionMarked = true
        self.vcMedia.isSelectionMarked = true
        self.viewButtonFrame.isHidden = true
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissViewController))
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    private func handleNavigationRightBarButton() {
        if self.pageViewController.viewControllers?.last == self.vcFiles {
            self.getDecAttachments(self.vcFiles.selection.compactMap { $0.decryptedAttachment })
        } else {
            self.getDecAttachments(self.vcMedia.selection.compactMap { $0.decryptedAttachment })
        }
    }

    private func getDecAttachments(_ attachmentArray: [DPAGDecryptedAttachment]) {
        let attachments = attachmentArray.compactMap { (attachment) -> DPAGMediaResource? in
            let mediaResource = DPAGMediaResource(type: attachment.attachmentType)
            mediaResource.attachment = attachment
            mediaResource.preview = attachment.thumb
            return mediaResource
        }

        self.dismiss(animated: true) { [weak self] in
            self?.mediaMultiPickerDelegate?.didFinishedPickingMultipleMedia(attachments)
        }
    }
}

extension DPAGMediaSelectMultiViewController: DPAGMediaAttachmentDelegate {
    func pickingMediaFinished(mediaResource _: DPAGMediaResource?, errorMessage: String?) {
        if let errorMessage = errorMessage {
            self.mediaMultiPickerDelegate?.pickingMediaFailedWithError(errorMessage)
        }
    }
}

extension DPAGMediaSelectMultiViewController: DPAGMediaSelectViewControllerDelegate {
    func didSelectAttachment(_: DPAGMediaViewAttachmentProtocol?) {
        if self.pageViewController.viewControllers?.last == self.vcFiles {
            self.navigationItem.rightBarButtonItem?.isEnabled = self.vcFiles.selection.count > 0
        } else {
            self.navigationItem.rightBarButtonItem?.isEnabled = self.vcMedia.selection.count > 0
        }
    }
}
