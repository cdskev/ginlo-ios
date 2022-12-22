//
//  DPAGStatusPickerTableViewController.swift
// ginlo
//
//  Created by RBU on 28/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData
import SIMSmeCore
import UIKit

class DPAGStatusPickerTableViewController: DPAGTableViewControllerBackground, DPAGStatusPickerTableViewControllerProtocol {
    private static let statusListCellIdentifier = "statusCell"
    private static let statusListCurrentCellIdentifier = "statusCellCurrent"
    private static let MAXLENGTH_STATUS = 140
    private weak var textFieldStatusText: UITextField?
    private var statusMessages: [String] = []
    private var statusText: String?
    weak var delegate: DPAGStatusPickerTableViewControllerDelegate?

    init() {
        super.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(DPAGApplicationFacadeUIViews.cellTextFieldNib(), forCellReuseIdentifier: DPAGStatusPickerTableViewController.statusListCurrentCellIdentifier)
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: DPAGStatusPickerTableViewController.statusListCellIdentifier)
        self.setLeftBarButtonItem(title: DPAGLocalizedString("res.cancel"), action: #selector(cancel))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(handleSetButtonPressed))
        self.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "navigation.done"
        self.statusMessages = DPAGApplicationFacade.profileWorker.loadStatusMessages()
        if self.statusText == nil {
            self.statusText = self.statusMessages.first
        }
        self.textFieldStatusText?.text = self.statusText
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    @objc
    private func cancel() {
        self.textFieldStatusText?.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    func handleSetButtonPressed() {
        self.textFieldStatusText?.resignFirstResponder()
        if let statusMessage = self.statusText {
            self.delegate?.updateStatusMessage(statusMessage)
            self.performBlockInBackground { [weak self] in
                DPAGApplicationFacade.statusWorker.updateStatus(statusMessage, broadCast: true)
                self?.performBlockOnMainThread { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
            }
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}

extension DPAGStatusPickerTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        2
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            return self.statusMessages.count
        }
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: DPAGStatusPickerTableViewController.statusListCellIdentifier, for: indexPath)
            cell.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
            cell.textLabel?.textColor = DPAGColorProvider.shared[.labelText]
            cell.textLabel?.text = self.statusMessages[indexPath.row]
            return cell
        }
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGStatusPickerTableViewController.statusListCurrentCellIdentifier, for: indexPath)
        cellDequeued.accessibilityIdentifier = "cell-\(indexPath.section)-\(indexPath.row)"
        guard let cell = cellDequeued as? (UITableViewCell & DPAGTableViewCellTextFieldProtocol) else { return cellDequeued }
        cell.textField.delegate = self
        self.textFieldStatusText = cell.textField
        cell.textField.text = self.statusText
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        44
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return DPAGLocalizedString("settings.pickStatus.pickOther")
        }
        return DPAGLocalizedString("settings.pickStatus.currentStatus")
    }
}

extension DPAGStatusPickerTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            self.textFieldStatusText?.resignFirstResponder()
            self.statusText = tableView.cellForRow(at: indexPath)?.textLabel?.text
            self.textFieldStatusText?.text = self.statusText
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension DPAGStatusPickerTableViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.statusText = textField.text
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        self.textFieldStatusText?.resignFirstResponder()
        return false
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let currentText = (textField.text as NSString?) else { return true }
        var retVal = true
        let resultedString = currentText.replacingCharacters(in: range, with: string)
        if textField == self.textFieldStatusText, resultedString.count >= DPAGStatusPickerTableViewController.MAXLENGTH_STATUS {
            let resultedStringNew = String(resultedString[..<resultedString.index(resultedString.startIndex, offsetBy: DPAGStatusPickerTableViewController.MAXLENGTH_STATUS)])
            textField.text = String(resultedStringNew)
            retVal = false
        }
        self.navigationItem.rightBarButtonItem?.isEnabled = (resultedString.isEmpty == false)
        return retVal
    }
}
