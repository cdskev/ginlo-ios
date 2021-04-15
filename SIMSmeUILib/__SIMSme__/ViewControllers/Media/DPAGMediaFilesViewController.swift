//
//  DPAGMediaFilesViewController.swift
//  SIMSme
//
//  Created by RBU on 02/03/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaFilesViewController: DPAGTableViewControllerWithSearch, DPAGMediaFilesViewControllerProtocol, DPAGViewControllerOrientationFlexibleIfPresented {
    private static let cellIdentifier = "cellIdentifier"
    private static let headerIdentifier = "headerIdentifier"
    private static let rowHeight: CGFloat = 44

    weak var mediaOverviewDelegate: DPAGMediaOverviewViewControllerDelegate?
    weak var mediaSelectDelegate: DPAGMediaSelectViewControllerDelegate?

    private var attachmentsSections: [String: [DPAGMediaViewAttachmentProtocol]] = [:]
    private var attachmentsSectionChars: [String] = []

    private var isInitialLoading: Bool = true

    private var selectedIndexPath: IndexPath?

    var selection: [DPAGMediaViewAttachmentProtocol] = []
    var isSelectionMarked = false

    private let queueSyncVars = DispatchQueue(label: "de.dpag.simsme.DPAGMediaFilesViewController.queueSyncVars", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)

    init() {
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.mediaFiles")
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.allowsMultipleSelection = false
        self.tableView.sectionIndexMinimumDisplayRowCount = 8
        self.tableView.sectionFooterHeight = 0
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.sectionHeaderHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 60
        self.tableView.estimatedSectionHeaderHeight = 38
        self.tableView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.tableView.register(DPAGApplicationFacadeUIMedia.cellMediaFileNib(), forCellReuseIdentifier: DPAGMediaFilesViewController.cellIdentifier)
        self.tableView.register(DPAGApplicationFacadeUIViews.tableHeaderPlainNib(), forHeaderFooterViewReuseIdentifier: DPAGMediaFilesViewController.headerIdentifier)
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.tableView.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.handleListNeedsUpdate()
        self.storeAttachments()
    }

    func configureSearchBar() {
        self.configureSearchBarWithResultsController(DPAGApplicationFacadeUIMedia.mediaOverviewSearchResultsVC(delegate: self), placeholder: "android.serach.placeholder")
    }

    private func storeAttachmentsInBackground() {
        var messageGuids: [DPAGMediaViewAttachmentProtocol] = []
        DPAGFunctionsGlobal.synchronized(self, block: {
            self.queueSyncVars.sync(flags: .barrier) {
                self.attachmentsSections.removeAll()
                self.attachmentsSectionChars.removeAll()
            }
            messageGuids = DPAGApplicationFacade.mediaWorker.loadFileViewAttachments()
            var attachmentsSections: [String: [DPAGMediaViewAttachmentProtocol]] = [:]
            var attachmentsSectionChars: [String] = []
            for messageAttachment in messageGuids {
                if let filename = messageAttachment.decryptedAttachment?.additionalData?.fileName, filename.isEmpty == false, let firstChar = filename.uppercased().first {
                    let firstCharStr = String(firstChar)
                    var attachmentSection: [DPAGMediaViewAttachmentProtocol] = attachmentsSections[firstCharStr] ?? []
                    attachmentSection.append(messageAttachment)
                    attachmentsSections[firstCharStr] = attachmentSection
                }
            }

            attachmentsSectionChars = attachmentsSections.keys.sorted()
            for attachmentSectionKey in attachmentsSections.keys {
                attachmentsSections[attachmentSectionKey] = attachmentsSections[attachmentSectionKey]?.sorted(by: { (decAtt1, decAtt2) -> Bool in
                    var filename1 = decAtt1.decryptedAttachment?.additionalData?.fileName?.uppercased()
                    var filename2 = decAtt2.decryptedAttachment?.additionalData?.fileName?.uppercased()
                    if let rangeExtension = filename1?.range(of: ".", options: .backwards) {
                        filename1 = String(filename1?[...rangeExtension.lowerBound] ?? "")
                    }
                    if let rangeExtension = filename2?.range(of: ".", options: .backwards) {
                        filename2 = String(filename2?[...rangeExtension.lowerBound] ?? "")
                    }
                    if let filename1 = filename1 {
                        if let filename2 = filename2 {
                            if filename1 == filename2 {
                                if let date1 = decAtt1.decryptedAttachment?.messageDate, let date2 = decAtt2.decryptedAttachment?.messageDate {
                                    return date1.compare(date2) == .orderedDescending
                                }
                            }
                            return filename1 < filename2
                        }
                        return true
                    } else if filename2 != nil {
                        return false
                    }
                    return true
                })
            }
            self.queueSyncVars.sync(flags: .barrier) {
                self.attachmentsSections = attachmentsSections
                self.attachmentsSectionChars = attachmentsSectionChars
            }
        })
    }

    private func storeAttachments() {
        if self.attachmentsSections.count == 0 {
            DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
                self?.storeAttachmentsInBackground()
                self?.performBlockOnMainThread { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.isInitialLoading = false
                    strongSelf.handleListNeedsUpdate()
                    DPAGProgressHUD.sharedInstance.hide(true)
                }
            }
        }
    }

    fileprivate func handleListNeedsUpdate() {
        if self.isInitialLoading {
            self.tableView.setEmptyMessage(DPAGLocalizedString("migration.info.init"))
        } else {
            var rc = 0
            self.queueSyncVars.sync(flags: .barrier) {
                rc = self.attachmentsSectionChars.count
            }
            if rc <= 0 {
                self.tableView.setEmptyMessage(DPAGLocalizedString("settings.media.nofiles"))
            } else {
                self.tableView.removeEmptyMessage()
            }
            self.tableView.reloadData()
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        if editing {
            self.tableView.allowsSelection = true
            self.tableView.allowsMultipleSelection = true
        } else {
            self.tableView.allowsSelection = true
            self.tableView.allowsMultipleSelection = false
            self.selection.removeAll()
            self.tableView.reloadData()
        }
    }

    func removeSelectedAttachments() {
        let attachmentsSectionChars = self.attachmentsSectionChars
        for key in attachmentsSectionChars {
            var section = self.attachmentsSections[key]
            section = section?.filter({ (attachment) -> Bool in
                self.selection.contains(where: { (attachmentSelection) -> Bool in
                    attachmentSelection.messageGuid == attachment.messageGuid
                }) == false
            })
            if section?.isEmpty ?? true {
                self.attachmentsSections.removeValue(forKey: key)
                if let idxChar = self.attachmentsSectionChars.firstIndex(of: key) {
                    self.attachmentsSectionChars.remove(at: idxChar)
                }
            } else {
                self.attachmentsSections[key] = section
            }
        }
        self.selection.removeAll()
        self.handleListNeedsUpdate()
    }

    func resetSelection() {
        self.selection.removeAll()
        self.handleListNeedsUpdate()
    }

    override func filterContent(searchText: String, completion: @escaping () -> Void) {
        var searchResults: [DPAGMediaViewAttachmentProtocol] = []
        if searchText.isEmpty == false {
            let searchTextEval = searchText.lowercased()
            for attachmentSectionChar in self.attachmentsSectionChars {
                if let attachmentSection = self.attachmentsSections[attachmentSectionChar] {
                    for attachment in attachmentSection {
                        if let decAttachment = attachment.decryptedAttachment, /* self.filesSelected.contains(attachment) == false && */ self.isSearchResultForFile(decAttachment, searchText: searchTextEval) {
                            searchResults.append(attachment)
                        }
                    }
                }
            }
        }
        self.performBlockOnMainThread { [weak self] in
            (self?.searchResultsController as? DPAGMediaOverviewSearchResultsViewController)?.mediasSearched = searchResults
            completion()
        }
    }

    private func isSearchResultForFile(_ attachment: DPAGDecryptedAttachment, searchText: String) -> Bool {
        guard attachment.additionalData?.fileName?.lowercased().range(of: searchText) == nil else { return true }
        guard attachment.contactName?.lowercased().range(of: searchText) == nil else { return true }
        guard attachment.messageDate?.timeLabelMediaFile.lowercased().range(of: searchText) == nil else { return true }
        return false
    }
}

// MARK: - search

extension DPAGMediaFilesViewController: DPAGMediaOverviewSearchResultsViewControllerDelegate {
    func didSelectMedia(_ attachment: DPAGMediaViewAttachmentProtocol) {
        if self.isSelectionMarked {
            if let idx = self.selection.firstIndex(where: { (attachmentCheck) -> Bool in
                attachmentCheck.messageGuid == attachment.messageGuid
            }) {
                self.selection.remove(at: idx)
                self.tableView.reloadData()
            } else {
                self.selection.append(attachment)
                self.tableView.reloadData()
                self.mediaSelectDelegate?.didSelectAttachment(attachment)
            }
        } else {
            self.mediaSelectDelegate?.didSelectAttachment(attachment)
        }
    }
}

extension DPAGMediaFilesViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        var rc: Int = 0
        self.queueSyncVars.sync(flags: .barrier) {
            rc = self.attachmentsSectionChars.count > 0 ? self.attachmentsSectionChars.count : 1
        }
        return rc
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        var rc: Int = 0
        self.queueSyncVars.sync(flags: .barrier) {
            if self.attachmentsSectionChars.count > 0, let attachmentSection = self.attachmentsSections[self.attachmentsSectionChars[section]] {
                rc = attachmentSection.count
            }
        }
        return rc
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGMediaFilesViewController.cellIdentifier, for: indexPath)
        cellDequeued.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        guard let cell = cellDequeued as? (UITableViewCell & DPAGMediaFileTableViewCellProtocol) else { return cellDequeued }
        self.queueSyncVars.sync(flags: .barrier) {
            if self.attachmentsSectionChars.count > indexPath.section {
                if let attachmentSection = self.attachmentsSections[self.attachmentsSectionChars[indexPath.section]] {
                    if attachmentSection.count > indexPath.row {
                        let messageAttachment = attachmentSection[indexPath.row]
                        if let decAttachment = messageAttachment.decryptedAttachment {
                            self.setupCell(cell, with: decAttachment)
                        }
                    }
                }
            }
        }
        return cell
    }

    func setupCell(_ cell: UITableViewCell & DPAGMediaFileTableViewCellProtocol, with attachment: DPAGDecryptedAttachment) {
        cell.setupWithAttachment(attachment)
        cell.isMediaSelected = self.selection.contains(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == attachment.messageGuid
        })
    }

    func sectionIndexTitles(for _: UITableView) -> [String]? {
        self.attachmentsSectionChars
    }
}

extension DPAGMediaFilesViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: DPAGMediaFilesViewController.headerIdentifier) as? (UITableViewHeaderFooterView & DPAGTableHeaderViewPlainProtocol)
        var rc: String?
        self.queueSyncVars.sync(flags: .barrier) {
            rc = self.attachmentsSectionChars.count > 0 ? self.attachmentsSectionChars[section] : nil
        }
        headerView?.label.text = rc
        headerView?.label.textColor = DPAGColorProvider.shared[.actionSheetLabel]
        return headerView
    }

    func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 1))
    }

    func tableView(_ tableView: UITableView, canFocusRowAt _: IndexPath) -> Bool {
        if tableView.allowsMultipleSelection, let selectedItems = tableView.indexPathsForSelectedRows {
            return selectedItems.count < DPAGApplicationFacade.preferences.maximumNumberOfMediaAttachments
        }
        return true
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let messageAttachment = self.attachmentsSections[self.attachmentsSectionChars[indexPath.section]]?[indexPath.row], let selectedAttachment = messageAttachment.decryptedAttachment else { return }
        self.selectedIndexPath = indexPath
        if let idx = self.selection.firstIndex(where: { (attachmentCheck) -> Bool in
            attachmentCheck.messageGuid == selectedAttachment.messageGuid
        }) {
            self.selectedIndexPath = nil
            (tableView.cellForRow(at: indexPath) as? DPAGMediaFileTableViewCellProtocol)?.isMediaSelected = false
            self.selection.remove(at: idx)
            self.mediaSelectDelegate?.didSelectAttachment(nil)
        } else {
            if tableView.allowsMultipleSelection {
                (tableView.cellForRow(at: indexPath) as? DPAGMediaFileTableViewCellProtocol)?.isMediaSelected = true
                self.selection.append(messageAttachment)
            }
            self.mediaSelectDelegate?.didSelectAttachment(messageAttachment)
        }
    }
}
