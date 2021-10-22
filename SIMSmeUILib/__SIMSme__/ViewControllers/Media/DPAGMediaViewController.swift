//
//  DPAGMediaViewController.swift
// ginlo
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaViewController: DPAGViewControllerBackground, DPAGMediaViewControllerProtocol, DPAGViewControllerOrientationFlexibleIfPresented {
    weak var mediaOverviewDelegate: DPAGMediaOverviewViewControllerDelegate?
    weak var mediaSelectDelegate: DPAGMediaSelectViewControllerDelegate?

    var searchController: UISearchController?
    var searchResultsController: (UIViewController & DPAGSearchResultsViewControllerProtocol)?

    var selectedMediaType: DPAGMediaSelectionOptions = [.imageVideo, .audio, .file]
    var selection: [DPAGMediaViewAttachmentProtocol] = []
    var isSelectionMarked = false

    let stackView: UIStackView = UIStackView()
    let mediaOverView: UICollectionView

    private var isInitialLoading: Bool = false

    private var numberOfVideos: Int = 0
    private var numberOfImages: Int = 0
    private var numberOfVoiceRecs: Int = 0
    private var numberOfFiles: Int = 0

    private(set) var attachments: [DPAGMediaViewAttachmentProtocol] = []

    var selectedIndexPath: IndexPath?

    init() {
        let layout = UICollectionViewFlowLayout()

        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 0
        layout.estimatedItemSize = CGSize(width: 93, height: 137)
        layout.sectionInsetReference = .fromSafeArea
        self.mediaOverView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.media")
        self.view.addSubview(self.stackView)
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addConstraintsFill(subview: self.stackView)
        self.stackView.alignment = .fill
        self.stackView.axis = .vertical
        self.stackView.distribution = .fill
        self.stackView.addArrangedSubview(self.mediaOverView)
        self.mediaOverView.translatesAutoresizingMaskIntoConstraints = false
        self.mediaOverView.backgroundColor = .clear
        self.mediaOverView.dataSource = self
        self.mediaOverView.delegate = self
        self.mediaOverView.allowsMultipleSelection = false
        self.mediaOverView.register(DPAGApplicationFacadeUIMedia.cellMediaNib(), forCellWithReuseIdentifier: "Cell")
        self.isInitialLoading = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.handleListNeedsUpdate()
        self.storeAttachments()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.configureSearchBar()
    }

    private func storeAttachmentsInBackground() -> [DPAGMediaViewAttachmentProtocol] {
        let mediaViewAttachments = DPAGApplicationFacade.mediaWorker.loadMediaViewAttachments(selectedMediaType: self.selectedMediaType)
        self.numberOfVideos = mediaViewAttachments.numberOfVideos
        self.numberOfImages = mediaViewAttachments.numberOfImages
        self.numberOfVoiceRecs = mediaViewAttachments.numberOfVoiceRecs
        self.numberOfFiles = mediaViewAttachments.numberOfFiles
        return mediaViewAttachments.mediaAttachments
    }

    func storeAttachments() {
        if self.attachments.count == 0 {
            let refreshControl = UIRefreshControl()
            self.mediaOverView.refreshControl = refreshControl
            refreshControl.beginRefreshing()
            self.performBlockInBackground { [weak self] in
                let messageGuids = self?.storeAttachmentsInBackground()
                self?.performBlockOnMainThread { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.attachments = messageGuids ?? []
                    strongSelf.isInitialLoading = false
                    refreshControl.endRefreshing()
                    strongSelf.mediaOverView.refreshControl = nil
                    strongSelf.handleListNeedsUpdate()
                    strongSelf.mediaOverviewDelegate?.updateToolbar()
                }
            }
        }
    }

    fileprivate func handleListNeedsUpdate() {
        if self.isInitialLoading {
            self.mediaOverView.setEmptyMessage(DPAGLocalizedString("migration.info.init"))
        } else if self.attachments.count <= 0 {
            self.mediaOverView.setEmptyMessage(DPAGLocalizedString("settings.media.nomedia"))
            self.mediaOverView.reloadData()
        } else {
            self.mediaOverView.removeEmptyMessage()
            self.mediaOverView.reloadData()
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        if self.isEditing {
            self.mediaOverView.allowsMultipleSelection = true
        } else {
            self.mediaOverView.allowsMultipleSelection = false
            self.selection.removeAll()
            self.mediaOverView.reloadData()
        }
    }

    func toolbarText() -> String {
        let imageText = (self.numberOfImages == 1) ? String(format: "%@ \(self.numberOfImages)", DPAGLocalizedString("settings.media.image")) : String(format: "%@ \(self.numberOfImages)", DPAGLocalizedString("settings.media.images"))
        let videoText = (self.numberOfVideos == 1) ? String(format: "%@ \(self.numberOfVideos)", DPAGLocalizedString("settings.media.video")) : String(format: "%@ \(self.numberOfVideos)", DPAGLocalizedString("settings.media.videos"))
        let voiceRecText = (self.numberOfVoiceRecs == 1) ? String(format: "%@ \(self.numberOfVoiceRecs)", DPAGLocalizedString("settings.media.voiceRec")) : String(format: "%@ \(self.numberOfVoiceRecs)", DPAGLocalizedString("settings.media.voiceRecs"))
        let fileText = (self.numberOfFiles == 1) ? String(format: "%@ \(self.numberOfFiles)", DPAGLocalizedString("settings.media.file")) : String(format: "%@ \(self.numberOfFiles)", DPAGLocalizedString("settings.media.files"))
        var labelText = ""
        if self.numberOfImages > 0 {
            labelText += imageText
        }
        if self.numberOfVideos > 0 {
            if !labelText.isEmpty {
                labelText += " | "
            }
            labelText += videoText
        }
        if self.numberOfVoiceRecs > 0 {
            if !labelText.isEmpty {
                labelText += " | "
            }
            labelText += voiceRecText
        }
        if self.numberOfFiles > 0 {
            if !labelText.isEmpty {
                labelText += " | "
            }
            labelText += fileText
        }
        return labelText
    }

    func removeAttachment(_ decryptedAttachment: DPAGDecryptedAttachment) {
        guard let idx = self.attachments.firstIndex(where: { (entry) -> Bool in
            entry.messageGuid == decryptedAttachment.messageGuid
        }) else {
            return
        }
        self.removeAttachmentSimple(decryptedAttachment, idx: idx)
        if let idx = self.selection.firstIndex(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == decryptedAttachment.messageGuid
        }) {
            self.selection.remove(at: idx)
        }
        self.handleListNeedsUpdate()
    }

    private func removeAttachmentSimple(_ decryptedAttachment: DPAGDecryptedAttachment, idx: Int) {
        switch decryptedAttachment.attachmentType {
            case .video:
                self.numberOfVideos -= 1
            case .image:
                self.numberOfImages -= 1
            case .voiceRec:
                self.numberOfVoiceRecs -= 1
            case .file:
                self.numberOfFiles -= 1
            case .unknown:
                break
        }
        if self.attachments.count > idx {
            self.attachments.remove(at: idx)
        }
    }

    func removeSelectedAttachments() {
        for item in self.selection {
            if let decryptedAttachment = item.decryptedAttachment, let idx = self.attachments.firstIndex(where: { (entry) -> Bool in
                entry.messageGuid == decryptedAttachment.messageGuid
            }) {
                self.removeAttachmentSimple(decryptedAttachment, idx: idx)
            }
        }
        self.selection.removeAll()
        self.handleListNeedsUpdate()
    }

    func resetSelection() {
        self.selection.removeAll()
        self.handleListNeedsUpdate()
    }

    private func filterContent(searchText: String, completion: @escaping DPAGCompletion) {
        var searchResults: [DPAGMediaViewAttachmentProtocol] = []
        if searchText.isEmpty == false {
            let searchTextEval = searchText.lowercased()
            for attachment in self.attachments {
                if let decAttachment = attachment.decryptedAttachment, /* self.filesSelected.contains(attachment) == false && */ self.isSearchResultForMedia(decAttachment, searchText: searchTextEval) {
                    searchResults.append(attachment)
                }
            }
        }
        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGMediaOverviewSearchResultsViewControllerProtocol)?.mediasSearched = searchResults
            completion()
        }
    }

    private func isSearchResultForMedia(_ attachment: DPAGDecryptedAttachment, searchText: String) -> Bool {
        guard attachment.contactName?.lowercased().range(of: searchText) == nil else { return true }
        guard attachment.messageDate?.timeLabelMediaFile.lowercased().range(of: searchText) == nil else { return true }
        return false
    }

    func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIMedia.mediaOverviewSearchResultsVC(delegate: self), placeholder: "android.serach.placeholder")
    }

    private func configureSearchBarWithResultsController(_ searchResultsController: UIViewController & DPAGSearchResultsViewControllerProtocol, placeholder: String) {
        let searchController: UISearchController
        searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchBar.delegate = self
        searchController.delegate = self
        self.navigationItem.searchController = searchController
        searchController.searchBar.placeholder = DPAGLocalizedString(placeholder)
        searchController.searchBar.accessibilityIdentifier = placeholder
        self.searchController = searchController
        self.definesPresentationContext = true
        self.searchResultsController = searchResultsController
        DPAGUIHelper.customizeSearchBar(searchController.searchBar)
    }
}

extension DPAGMediaViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        self.searchResultsController?.searchBarText = searchText.lowercased()
        self.filterContent(searchText: searchText) { [weak self] in
            if self?.searchResultsController?.view != nil {
                self?.searchResultsController?.tableView.reloadData()
            }
        }
    }
}

extension DPAGMediaViewController: UISearchControllerDelegate {
    func willPresentSearchController(_: UISearchController) {}
    func willDismissSearchController(_: UISearchController) {
        self.mediaOverView.reloadData()
    }
}

// MARK: - search

extension DPAGMediaViewController: DPAGMediaOverviewSearchResultsViewControllerDelegate {
    func didSelectMedia(_ attachment: DPAGMediaViewAttachmentProtocol) {
        if self.isSelectionMarked {
            if let idx = self.selection.firstIndex(where: { (attachmentCheck) -> Bool in
                attachmentCheck.messageGuid == attachment.messageGuid
            }) {
                self.selection.remove(at: idx)
                self.mediaOverView.reloadData()
            } else {
                self.selection.append(attachment)
                self.mediaOverView.reloadData()
                self.mediaSelectDelegate?.didSelectAttachment(attachment)
            }
        } else {
            self.mediaSelectDelegate?.didSelectAttachment(attachment)
        }
    }

    func setupCell(_ cell: UITableViewCell & DPAGMediaFileTableViewCellProtocol, with attachment: DPAGDecryptedAttachment) {
        cell.setupWithAttachment(attachment)
        cell.isMediaSelected = self.selection.contains(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == attachment.messageGuid
        })
    }
}

// MARK: - CollectionView Data Source

extension DPAGMediaViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        self.attachments.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellDequeued = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        cellDequeued.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        guard let cell = cellDequeued as? (UICollectionViewCell & DPAGMediaCollectionViewCellProtocol) else { return cellDequeued }
        let messageAttachment = self.attachments[indexPath.row]
        if let currentAttachment = messageAttachment.decryptedAttachment {
            self.setupCell(cell, with: currentAttachment)
        }
        return cell
    }

    private func setupCell(_ cell: UICollectionViewCell & DPAGMediaCollectionViewCellProtocol, with attachment: DPAGDecryptedAttachment) {
        cell.setupWithAttachment(attachment)
        cell.isMediaSelected = self.selection.contains(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == attachment.messageGuid
        })
        let accessibilityIdentifier: String
        switch attachment.attachmentType {
            case .image:
                accessibilityIdentifier = "-image"
            case .video:
                accessibilityIdentifier = "-video"
            case .voiceRec:
                accessibilityIdentifier = "-voiceRec"
            case .file:
                accessibilityIdentifier = "-file"
            case .unknown:
                accessibilityIdentifier = "-unknown"
        }
        cell.accessibilityIdentifier = (cell.accessibilityIdentifier ?? "") + accessibilityIdentifier
    }
}

extension DPAGMediaViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, shouldSelectItemAt _: IndexPath) -> Bool {
        self.selection.count < DPAGApplicationFacade.preferences.maximumNumberOfMediaAttachments
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.mediaOverView.deselectItem(at: indexPath, animated: false)
        let messageAttachment = self.attachments[indexPath.row]
        guard let selectedAttachment = messageAttachment.decryptedAttachment else { return }
        self.selectedIndexPath = indexPath
        if let idx = self.selection.firstIndex(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == selectedAttachment.messageGuid
        }) {
            self.selectedIndexPath = nil
            (collectionView.cellForItem(at: indexPath) as? DPAGMediaCollectionViewCellProtocol)?.isMediaSelected = false
            self.selection.remove(at: idx)
            self.mediaSelectDelegate?.didSelectAttachment(nil)
        } else {
            if self.mediaOverView.allowsMultipleSelection {
                (collectionView.cellForItem(at: indexPath) as? DPAGMediaCollectionViewCellProtocol)?.isMediaSelected = true
                self.selection.append(messageAttachment)
            }
            self.mediaSelectDelegate?.didSelectAttachment(messageAttachment)
        }
    }
}
