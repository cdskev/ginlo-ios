//
//  DPAGDevicesTableViewController.swift
// ginlo
//
//  Created by RBU on 24.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGDevicesTableViewController: DPAGViewControllerBackground, DPAGViewControllerNavigationTitleBig, DPAGNavigationViewControllerStyler {
    private static let CellIdentifier = "CellIdentifier"

    private var devices: [DPAGDevice] = []

    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var viewButtonAddDevice: DPAGButtonPrimaryView! {
        didSet {
            self.viewButtonAddDevice.button.accessibilityIdentifier = "buttonAddDevice"
            self.viewButtonAddDevice.button.setTitle(DPAGLocalizedString("settings.devices.buttonAdd.title"), for: .normal)
            self.viewButtonAddDevice.button.addTargetClosure { [weak self] _ in
                let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: DPAGApplicationFacadeUISettings.addDeviceVC())
                self?.present(navVC, animated: true, completion: nil)
            }
        }
    }

    private let refreshControl = UIRefreshControl()

    init() {
        super.init(nibName: "DPAGDevicesTableViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = DPAGLocalizedString("settings.devices.title")
        self.extendedLayoutIncludesOpaqueBars = true
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.backgroundColor = .clear
        self.tableView.register(DPAGApplicationFacadeUISettings.cellDeviceNib(), forCellReuseIdentifier: DPAGDevicesTableViewController.CellIdentifier)
        self.tableView.estimatedRowHeight = 88.0
        self.tableView.rowHeight = UITableView.automaticDimension
        if AppConfig.buildConfigurationMode == .TEST {} else {
            self.tableView.refreshControl = self.refreshControl
        }
        self.refreshControl.addTarget(self, action: #selector(refreshDevices(_:)), for: .valueChanged)
        self.view.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        self.tableView.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
    }

    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
        self.view.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
        self.tableView.backgroundColor = DPAGColorProvider.shared[.settingsBackground]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.refreshControl.beginRefreshing()
        self.performBlockInBackground { [weak self] in
            self?.loadDevices()
        }
    }

    @objc
    private func refreshDevices(_: Any) {
        self.performBlockInBackground { [weak self] in
            self?.loadDevices()
        }
    }

    private func loadDevices() {
        DPAGApplicationFacade.devicesWorker.getDevices(withResponse: { [weak self] responseObject, _, _ in
            if let devices = responseObject as? [[AnyHashable: Any]] {
                var devicesNew: [DPAGDevice] = []
                for deviceObj in devices {
                    if let deviceDict = deviceObj[DPAGStrings.JSON.Device.OBJECT_KEY] as? [AnyHashable: Any] {
                        let device = DPAGDevice(deviceDict: deviceDict)
                        devicesNew.append(device)
                    }
                }
                devicesNew.sort(by: { (firstDevice, secondDevice) -> Bool in
                    let name1 = firstDevice.deviceName ?? ""
                    let name2 = secondDevice.deviceName ?? ""
                    return name1.caseInsensitiveCompare(name2) == .orderedAscending
                })
                self?.performBlockOnMainThread { [weak self] in
                    self?.devices = devicesNew
                    self?.refreshControl.endRefreshing()
                    self?.tableView.reloadData()
                    let maxDeviceCount = DPAGApplicationFacade.preferences.maxClients
                    self?.viewButtonAddDevice.isEnabled = (devicesNew.count < maxDeviceCount)
                }
            } else {
                self?.performBlockOnMainThread { [weak self] in
                    self?.refreshControl.endRefreshing()
                }
            }
        })
    }

    private func deleteDevice(_ guid: String) {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
            DPAGApplicationFacade.devicesWorker.deleteDevice(guid) { _, _, errorMessage in

                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    if let errorMessage = errorMessage {
                        self?.presentErrorAlert(alertConfig: AlertConfigError(titleIdentifier: "attention", messageIdentifier: errorMessage))
                    } else if let idx = self?.devices.firstIndex(where: { (device) -> Bool in
                        device.guid == guid
                    }) {
                        let isTempDevice = (self?.devices[idx].isTempDevice() ?? false)

                        if isTempDevice {
                            // Gültigkeit korrigieren
                            self?.performBlockInBackground {
                                do {
                                    try DPAGApplicationFacade.couplingWorker.deleteTempDevice(guid: guid)
                                } catch {
                                    DPAGLog(error)
                                }
                            }
                        }
                        self?.devices.remove(at: idx)
                        self?.tableView.reloadData()
                    }
                }
            }
        }
    }
}

extension DPAGDevicesTableViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellDequeued = tableView.dequeueReusableCell(withIdentifier: DPAGDevicesTableViewController.CellIdentifier, for: indexPath)
        guard let cell = cellDequeued as? (UITableViewCell & DPAGDeviceTableViewCellProtocol) else {
            return cellDequeued
        }
        let device = self.devices[indexPath.row]
        cell.configureCell(withDevice: device, forHeightMeasurement: false)
        return cell
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        1
    }
}

extension DPAGDevicesTableViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let device = self.devices[indexPath.row]

        guard device.guid != nil else {
            self.tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        let nextVC = DPAGApplicationFacadeUISettings.deviceVC(device: device)

        self.navigationController?.pushViewController(nextVC, animated: true)
    }
}
