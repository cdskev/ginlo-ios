//
// Created by mg on 27.10.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreData

public protocol DPAGSimsMeModelProtocol: AnyObject {
    var httpUsername: String? { get }
    var httpPassword: String? { get }
    var language: String? { get }
    var appVersion: String? { get }
    var appName: String? { get }
    var bundleId: String? { get }

    var recoveryAccountguid: String? { get set }
    var recoveryPasstoken: String? { get set }

    var ownDeviceGuid: String? { get }

    func update(with localContext: NSManagedObjectContext?)

    func addParams(to request: NSMutableURLRequest)

    func setupDeviceData()
}

class DPAGSimsMeModel: DPAGSimsMeModelProtocol {
    public private(set) var httpUsername: String?
    public private(set) var httpPassword: String?
    public private(set) var language: String?
    public private(set) var appVersion: String?
    public private(set) var appVersionRequests: String?
    public private(set) var appName: String?
    public private(set) var bundleId: String?

    var recoveryAccountguid: String?
    var recoveryPasstoken: String?

    private(set) var ownDeviceGuid: String?

    init() {
        self.setupDeviceData()
    }

    func update(with localContext: NSManagedObjectContext?) {
        if let localContext = localContext {
            self.readManagedObjectsWithContext(localContext)
        } else {
            DPAGApplicationFacade.persistance.loadWithBlock { localContext in
                self.readManagedObjectsWithContext(localContext)
            }
        }
    }

    private func readManagedObjectsWithContext(_ localContext: NSManagedObjectContext) {
        guard let account = SIMSAccount.mr_findFirst(in: localContext), let device = SIMSDevice.mr_findFirst(with: NSComparisonPredicate(leftExpression: NSExpression(forKeyPath: \SIMSDevice.ownDevice), rightExpression: NSExpression(forConstantValue: 1)), in: localContext), let accountGuid = account.guid, SIMSContactIndexEntry.findFirst(byGuid: accountGuid, in: localContext) != nil else {
            DPAGLog("Model initialization failed: Managed objects could not be found!")
            return
        }

        self.setup(account: account, device: device)
    }

    private func stripGuid(_ guidWithPrefix: String) -> String {
        if let range = guidWithPrefix.range(of: ":{"), guidWithPrefix.hasSuffix("}") {
            return "{" + guidWithPrefix[range.upperBound...]
        }
        return guidWithPrefix
    }

    private func setup(account: SIMSAccount, device: SIMSDevice) {
        guard let accountGuid = account.guid, let deviceGuid = device.guid else { return }

        let httpUsername = String(format: "%@@%@", self.stripGuid(deviceGuid), self.stripGuid(accountGuid))
        let httpPassword = device.passToken

        if let httpPassword = httpPassword {
            self.httpUsername = httpUsername
            self.httpPassword = httpPassword

            DPAGApplicationFacade.preferences.backgroundAccessUsername = httpUsername
        }

        self.ownDeviceGuid = deviceGuid
    }

    func setupDeviceData() {
        let bundle = Bundle.main

        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        let revision = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")

        self.appVersion = shortVersion
        self.appVersionRequests = shortVersion + "." + revision
        self.appName = String(format: "%@", (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "SIMSme")
        self.bundleId = bundle.bundleIdentifier
        self.language = bundle.preferredLocalizations.first
    }

    func addParams(to request: NSMutableURLRequest) {
        if let appVersion = self.appVersionRequests {
            request.addValue(appVersion, forHTTPHeaderField: "X-Client-Version")
        }
        if let appName = self.appName {
            request.addValue(appName, forHTTPHeaderField: "X-Client-App")
        }
    }
}
