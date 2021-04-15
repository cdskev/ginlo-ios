//
//  PageEndpointViewController.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 28.08.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import SIMSmeCore

class PageEndpointViewController: DPAGViewControllerWithKeyboard {
    @IBOutlet private var titleEndpoint: UILabel! {
        didSet {
            self.titleEndpoint.text = "Endpoint"
        }
    }

    @IBOutlet private var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
            tableView.register(EndpointCell.self, forCellReuseIdentifier: EndpointCell.idendifier)
        }
    }

    @IBOutlet private var titleCustom: UILabel! {
        didSet {
            self.titleCustom.text = "Custom:"
        }
    }

    @IBOutlet private var customTextField: UITextField! {
        didSet {
            self.customTextField.text = viewModel.customEndPoint
            self.customTextField.accessibilityIdentifier = "PageEndoint.textfield.custom"
        }
    }

    @IBOutlet private var customDescription: UILabel! {
        didSet {
            self.customDescription.text = "If none of the endpoint in the list is selected, the custom will be used."
        }
    }

    @IBOutlet private var validateButton: UIButton! {
        didSet {
            self.validateButton.setTitle("Validate", for: .normal)
            self.validateButton.accessibilityIdentifier = "PageEndoint.button.validate"
            self.validateButton.addTargetClosure { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.validateButtonClicked()
            }
        }
    }

    private func validateButtonClicked() {
        guard let endpoint = selectedEndpoint() else {
            return
        }
        EndpointDAO.save(endpoint: endpoint)
        AppConfig.hostHttpService = endpoint
        if accountCreation {
            navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.requestAccountVC(password: password, enabled: enabled, endpoint: endpoint),
                                                     animated: true)
        } else {
            navigationController?.pushViewController(DPAGApplicationFacadeUIRegistration.createDeviceRequestCodeVC(password: password,
                                                                                                                   enabled: enabled),
                                                     animated: true)
        }
    }

    var viewModel = PageEndPointViewModel()
    let password: String
    let enabled: Bool
    let accountCreation: Bool

    init(password: String, enabled: Bool, accountCreation: Bool = false) {
        self.password = password
        self.enabled = enabled
        self.accountCreation = accountCreation
        super.init(nibName: "PageEndpointViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func selectedEndpoint() -> String? {
        guard let index = viewModel.selectedIndexPath?.row else {
            return customTextField.text
        }

        return viewModel.endpoints[index].uri
    }
}

extension PageEndpointViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel.endpoints.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: EndpointCell.idendifier, for: indexPath)
        let endpoint = viewModel.endpoints[indexPath.row]
        cell.textLabel?.text = endpoint.name
        cell.accessibilityIdentifier = "PageEndpoint.list.\(endpoint.name)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if viewModel.selectedIndexPath == indexPath {
            viewModel.selectedIndexPath = nil
            tableView.deselectRow(at: indexPath, animated: false)
        } else {
            viewModel.selectedIndexPath = indexPath
        }
    }
}

struct PageEndPointViewModel {
    let endpoints = [Endpoint.prod, Endpoint.staging]
    var customEndPoint = "ginlo-stg.g3o.io/MessageService/MsgService"
    var selectedIndexPath: IndexPath?
}

enum Endpoint {
    static let prod = EndpointEntry(name: "PROD", uri: "ginlo-prod.g3o.io/MessageService/MsgService")
    static let staging = EndpointEntry(name: "STAGING", uri: "ginlo-stg.g3o.io/MessageService/MsgService")
}

struct EndpointEntry {
    let name: String
    let uri: String
}

class EndpointCell: UITableViewCell {
    static let idendifier = "endpointCell"
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.accessoryType = selected ? .checkmark : .none
    }
}
