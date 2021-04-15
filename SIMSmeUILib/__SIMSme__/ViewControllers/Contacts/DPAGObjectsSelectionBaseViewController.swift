//
//  DPAGObjectsSelectionBaseViewController.swift
//  SIMSme
//
//  Created by RBU on 14.12.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

struct DPAGObjectsSelectionOptions: OptionSet {
    let rawValue: Int
    init(rawValue: Int) { self.rawValue = rawValue }

    static let NoOption = DPAGObjectsSelectionOptions([])
    static let EnableMultiSelection = DPAGObjectsSelectionOptions(rawValue: 1 << 0)
    static let EnableEmptySelection = DPAGObjectsSelectionOptions(rawValue: 1 << 1)
    static let EnableGroupedStyle = DPAGObjectsSelectionOptions(rawValue: 1 << 2)
    static let ShowSelectionOnly = DPAGObjectsSelectionOptions(rawValue: 1 << 3)
    static let InvertedSelection = DPAGObjectsSelectionOptions(rawValue: 1 << 4)
}

class DPAGObjectsSelectionBaseViewController<T: DPAGSearchListModelEntry>: DPAGTableViewControllerWithSearch, DPAGObjectsSelectionBaseViewControllerProtocol {
    var options: DPAGObjectsSelectionOptions = .NoOption

    var groupStyle: Bool { self.options.contains(.EnableGroupedStyle) }
    var multipleSelectionEnabled: Bool { self.options.contains(.EnableMultiSelection) }
    var emptySelectionEnabled: Bool { self.options.contains(.EnableEmptySelection) }
    var invertedSelection: Bool { self.options.contains(.InvertedSelection) }

    var model: DPAGSearchListModel<T>?

    private let objectsSelected: DPAGSearchListSelection<T>

    init(objectsSelected: DPAGSearchListSelection<T>) {
        self.objectsSelected = objectsSelected
        super.init(style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureNavigationBar()
        if self.parent is UINavigationController {
            self.configureSearchBar()
        }
        self.performBlockInBackground { [weak self] in
            self?.createModel()
            self?.performBlockOnMainThread { [weak self] in
                self?.handleModelCreated()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if AppConfig.isShareExtension == false {
            self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
                self?.searchController?.isActive = false
            })
        }
    }

    func createModel() {}

    func handleModelCreated() {
        self.tableView.reloadData()
        if self.multipleSelectionEnabled || self.emptySelectionEnabled {
            self.navigationItem.rightBarButtonItem?.isEnabled = self.objectsSelected.objectsSelected.count > 0 || self.emptySelectionEnabled
        }
        if let pagesVC = self.parent?.parent as? DPAGContactsPagesBaseViewControllerProtocol {
            return pagesVC.pageChangeRequest(nil)
        }
    }

    override func configureTableView() {
        super.configureTableView()
        self.tableView.register(DPAGApplicationFacadeUIViews.tableHeaderPlainNib(), forHeaderFooterViewReuseIdentifier: "headerIdentifier")
        self.tableView.separatorStyle = .singleLine
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
        self.tableView.estimatedSectionFooterHeight = 0
        self.tableView.estimatedSectionHeaderHeight = 38
        self.tableView.sectionFooterHeight = 0
        self.tableView.sectionIndexMinimumDisplayRowCount = 4
    }

    func configureSearchBar() {}

    func configureNavigationBar() {
        if self.multipleSelectionEnabled || self.emptySelectionEnabled {
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck]?.imageWithTintColor(DPAGColorProvider.shared[.labelText]), action: #selector(handleSelectionDone), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    func handleSelectionDone() {
        self.didSelect(objects: self.objectsSelected.objectsSelected)
    }

    @objc(numberOfSectionsInTableView:)
    func numberOfSections(in _: UITableView) -> Int {
        if self.groupStyle {
            return max(1, self.model?.objectsInSections.count ?? 0)
        }
        return 1
    }

    @objc
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.groupStyle, (self.model?.sectionsChars.count ?? 0) > section, let sectionsChar = self.model?.sectionsChars[section] {
            return self.model?.objectsInSections[sectionsChar]?.count ?? 0
        }

        return self.model?.objects.count ?? 0
    }

    @objc
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "headerIdentifier") as? (UITableViewHeaderFooterView & DPAGTableHeaderViewPlainProtocol)

        headerView?.label.text = self.tableView(tableView, titleForHeaderInSection: section)
        headerView?.label.textColor = DPAGColorProvider.shared[.actionSheetLabel]
        return headerView
    }

    @objc(sectionIndexTitlesForTableView:)
    func sectionIndexTitles(for _: UITableView) -> [String]? {
        if self.groupStyle {
            return self.model?.sectionsChars
        }
        return nil
    }

    @objc
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.groupStyle, (self.model?.sectionsChars.count ?? 0) > section {
            return self.model?.sectionsChars[section]
        }
        return nil
    }

    @objc
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.groupStyle {
            return tableView.numberOfRows(inSection: section) > 0 ? UITableView.automaticDimension : 0
        }
        return 0
    }

    @objc
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let lastSectionIdx = self.numberOfSections(in: tableView) - 1

        if section == lastSectionIdx {
            return 1
        }

        return 0
    }

    @objc(tableView:heightForRowAtIndexPath:)
    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        DPAGConstantsGlobal.kContactCellHeight
    }

    func objectForTableView(_: UITableView, indexPath: IndexPath) -> T? {
        var objects: [T]?

        if self.groupStyle {
            if let sectionsChar = self.model?.sectionsChars[indexPath.section] {
                objects = self.model?.objectsInSections[sectionsChar]
            }
        } else {
            objects = self.model?.objectsSorted
        }

        if (objects?.count ?? 0) <= indexPath.row {
            return nil
        }

        return objects?[indexPath.row]
    }

    @objc(tableView:didSelectRowAtIndexPath:)
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let object = self.objectForTableView(tableView, indexPath: indexPath) {
            self.tableViewDidSelect(object: object, at: indexPath)
        }
    }

    func tableViewDidSelect(object: T, at indexPath: IndexPath?) {
        if self.objectsSelected.objectsSelectedFixed.contains(object) {
            return
        }
        if self.objectsSelected.contains(object) {
            self.objectsSelected.removeSelected(object)

            if self.multipleSelectionEnabled || self.emptySelectionEnabled {
                self.navigationItem.rightBarButtonItem?.isEnabled = self.emptySelectionEnabled == true || self.objectsSelected.objectsSelected.count > 0
            }
            if let indexPath = indexPath {
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
            } else {
                self.tableView.reloadData()
            }

            self.didUnselectMulti(object: object)
        } else if self.multipleSelectionEnabled == false {
            if AppConfig.isShareExtension == false {
                if let contact = object as? DPAGContact {
                    DPAGApplicationFacade.preferences.addLastRecentlyUsed(contacts: [contact])
                }
            }

            self.didSelect(objects: [object])
        } else {
            self.objectsSelected.appendSelected(object)

            if AppConfig.isShareExtension == false {
                if let contact = object as? DPAGContact {
                    DPAGApplicationFacade.preferences.addLastRecentlyUsed(contacts: [contact], withNotification: indexPath == nil)
                }
            }

            if self.multipleSelectionEnabled || self.emptySelectionEnabled {
                self.navigationItem.rightBarButtonItem?.isEnabled = true
            }

            if let indexPath = indexPath {
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
            } else {
                self.tableView.reloadData()
            }

            self.didSelectMulti(object: object)
        }
    }

    func didSelect(objects _: Set<T>) {}

    func didSelectMulti(object _: T) {}

    func didUnselectMulti(object _: T) {}
}
