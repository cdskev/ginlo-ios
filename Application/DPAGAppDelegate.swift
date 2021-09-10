//
//  DPAGAppDelegate.m
//  SIMSme
//
//  Created by mg on 12.09.13.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AFNetworking
import Sentry
import SIMSmeCore
import SIMSmeUILib

import UIKit
import UserNotifications
import JitsiMeetSDK

private struct DPAGPreferencesMigrator {
    private init() {}

    private static let fileURL = DPAGConstantsGlobal.documentsDirectoryURL?.appendingPathComponent("preferences", isDirectory: false).appendingPathExtension("plist")

    static func needsMigration() -> Bool {
        if let fileURL = self.fileURL {
            return FileManager.default.fileExists(atPath: fileURL.path) == false || (try? Data(contentsOf: fileURL))?.count == 0
        }
        return false
    }

    static func canMigrate() -> Bool {
        UserDefaults.standard.object(forKey: DPAGPreferences.PropInt.kRateState.rawValue) != nil
    }

    static func migrate() {
        guard let fileURL = self.fileURL else { return }

        var dict: [String: Any] = [:]

        let preferences = UserDefaults.standard

        for prop in DPAGPreferences.PropString.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }
        for prop in DPAGPreferences.PropBool.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }
        for prop in DPAGPreferences.PropInt.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }
        for prop in DPAGPreferences.PropDate.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }
        for prop in DPAGPreferences.PropNumber.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }
        for prop in DPAGPreferences.PropAny.allCases {
            if let value = preferences.object(forKey: prop.rawValue) {
                dict[prop.rawValue] = value
            }
        }

        do {
            let plistData = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: PropertyListSerialization.WriteOptions())
            
            try plistData.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            try (fileURL as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
        } catch {
            DPAGLog(error, message: "Error writing preferences migration file")
        }
    }
}

open class DPAGAppDelegate: UIResponder, UIApplicationDelegate {
    public var window: UIWindow?
    var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var bgTask2: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var bgTask3: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    var dateToRemovePwdFromKeyChain: Date?
    var urlToHandle: URL?
    var notificationUpdateWorker: DPAGNotificationStateUpdateWorkerProtocol?
    var lockViews: [UIView & DPAGLockViewProtocol]?
    var databaseReady = false
    var coreDataThread: Foundation.Thread?
    var semaphore: DispatchSemaphore?
    var pushHandleMessageGuids: [String] = []
    var launchOptions: [AnyHashable: Any]?
    var backupStartDate: Date?
    var observerUserDefaults: NSObjectProtocol?
    var crashReporter: CrashReporter?
    var preferencesLoaded: Bool = false
    var syncHelper: DPAGSynchronizationHelperAddressbook?

    // MARK: AppLicationDelegate
    // 1. APPLICATION LAUNCH LIFE-TIME
    public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("willFinishLaunchingWithOptions: (ENTER)")
        do {
            try DPAGFunctionsGlobal.unlockChilkat(AppConfig.chilkatLicense)
            guard let sentryDsn = Bundle.main.object(forInfoDictionaryKey: "Sentry DSN") as? String else {
                throw PListError.failParsing
            }
            self.crashReporter = CrashReporterImpl(dsn: sentryDsn)
            try self.crashReporter?.startReporting()
        } catch PListError.failParsing {
            DPAGLog("   Sentry failed: Missing property in plist")
        } catch {
            DPAGLog(error, message: "willFinishLaunching failed")
        }
        DPAGLog("willFinishLaunchingWithOptions: (EXIT)")
        return true
    }
   
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DPAGLog("didFinishLaunchingWithOptions: (ENTER) applicationState: \(UIApplication.shared.applicationState.rawValue)")
        DPAGApplicationFacadeUIBase.sharedApplication = application
        if !self.preferencesLoaded {
            self.preferencesLoaded = DPAGApplicationFacade.preferences.setup()
        }
        if self.window == nil {
            self.initWindow(application, inBackgroundWithOptions: launchOptions)
        }
        // If the database is not ready, we should wait for it, otherwise we screw up the
        // app state
        waitForDatabase()
        guard let launchOptions = launchOptions else { return true }
        JitsiMeet.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
        DPAGLog("didFinishLaunchingWithOptions: (EXIT-2) applicationState: \(UIApplication.shared.applicationState.rawValue)")
        return true
    }

    // 2. APPLICATION FOREGROUNG/BACKGROUND CYCLE
    public func applicationWillEnterForeground(_ application: UIApplication) {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("applicationWillEnterForeground: (ENTER) applicationState: \(UIApplication.shared.applicationState.rawValue)")
        if !self.preferencesLoaded {
            self.preferencesLoaded = DPAGApplicationFacade.preferences.setup()
        }
        if self.window == nil {
            self.initWindow(application, inBackgroundWithOptions: nil)
        }
        // If the database is not ready, we should wait for it, otherwise we screw up the
        // app state
        // The problem is that starting iOS 14, applicationWillEnterForeground AND application:didFinishLaunchingWithOptions: may
        // come in weird orders
        waitForDatabase()
        self.appWillEnterForeground(application)
        DPAGLog("applicationWillEnterForeground: (EXIT) applicationState: \(UIApplication.shared.applicationState.rawValue)")
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("applicationDidBecomeActive: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            if let lockViews = self?.lockViews {
                for lockView in lockViews {
                    lockView.alpha = 0
                }
            }
        }, completion: { [weak self] _ in
            if let lockViews = self?.lockViews {
                for lockView in lockViews {
                    lockView.removeFromSuperview()
                    lockView.alpha = 1
                }
                while (self?.lockViews?.count ?? 0) > 1 {
                    self?.lockViews?.removeLast()
                }
            }
        })
        // Start monitoring the internet connection
        AFNetworkReachabilityManager.shared().startMonitoring()
    }

    public func applicationWillResignActive(_ application: UIApplication) {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("applicationWillResignActive: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        if let lockViewsFirst = self.lockViews?.first {
            lockViewsFirst.frame = self.window?.bounds ?? .zero
            lockViewsFirst.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate)"
            self.window?.addSubview(lockViewsFirst)
            if self.window?.rootViewController?.presentedViewController is DPAGLoginViewControllerProtocol {
                let lockViewLogin = DPAGUIHelper.setupLockViewLogin(frame: self.window?.bounds ?? .zero)
                lockViewLogin.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate + 1)"
                self.window?.addSubview(lockViewLogin)
                self.lockViews?.append(lockViewLogin)
            }
        }
        let lastWindow = UIApplication.shared.windows.last
        if lastWindow != self.window {
            let lockView = DPAGUIHelper.setupLockView(frame: lastWindow?.bounds ?? .zero)
            lockView.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate)"
            lastWindow?.addSubview(lockView)
            self.lockViews?.append(lockView)
            if self.window?.rootViewController?.presentedViewController is DPAGLoginViewControllerProtocol {
                let lockViewLogin = DPAGUIHelper.setupLockViewLogin(frame: lastWindow?.bounds ?? .zero)
                lockViewLogin.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate + 1)"
                lastWindow?.addSubview(lockViewLogin)
                self.lockViews?.append(lockViewLogin)
            }
        }
        if self.databaseReady {
            self.clearBadgeIfNecessary()
            NotificationCenter.default.post(name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
        }
    }

    public func applicationDidEnterBackground(_ application: UIApplication) {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("applicationDidEnterBackground: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        application.ignoreSnapshotOnNextApplicationLaunch()
        if self.databaseReady == false {
            return
        }
        self.performBlockInBackground {
            DPAGHelperEx.clearTempFolder()
        }
        var bLockApplication = false
        if DPAGApplicationFacade.preferences.lockApplicationImmediately {
            self.lockApplication()
            bLockApplication = true
        } else {
            if self.bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(self.bgTask)
                self.bgTask = .invalid
            }
            self.dateToRemovePwdFromKeyChain = nil
            let usePassword = DPAGApplicationFacade.preferences.passwordOnStartEnabled
            if usePassword, CryptoHelper.sharedInstance?.hasPrivateKey() ?? false, let account = DPAGApplicationFacade.cache.account, account.accountState == .confirmed {
                let delay = DPAGApplicationFacade.preferences.applicationLockDelay.rawValue
                let multiplier: CGFloat = min(9.5, CGFloat(delay) + 0.1)
                let dateToRemovePwdFromKeyChain = Date(timeInterval: TimeInterval(multiplier) * 60, since: Date())
                self.dateToRemovePwdFromKeyChain = dateToRemovePwdFromKeyChain
                self.bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                    DispatchQueue.main.async(execute: { [weak self] in
                        DPAGLog("background task stopped %@", "expired")
                        guard let strongSelf = self else { return }
                        UIApplication.shared.endBackgroundTask(strongSelf.bgTask)
                        strongSelf.bgTask = .invalid
                    })
                })
                let queue = DispatchQueue.global(qos: .default)
                queue.async { [weak self] in
                    guard let strongSelf = self else { return }
                    while let dateToRemovePwdFromKeyChain = strongSelf.dateToRemovePwdFromKeyChain,
                        UIApplication.shared.backgroundTimeRemaining > 5,
                        UIApplication.shared.backgroundTimeRemaining < 600_000 {
                        DPAGLog("Time left in background: %f", UIApplication.shared.backgroundTimeRemaining)
                        if dateToRemovePwdFromKeyChain.compare(Date()) == .orderedAscending {
                            // der block wird, wenn performBlockOnMainThread: verwendet wird, nicht mehr ausgeführt.
                            // daher dispatch_sync
                            DispatchQueue.main.sync(execute: { [weak self] in
                                self?.lockApplication()
                                DPAGSimsMeController.sharedInstance.deleteCachedData()
                            })
                            strongSelf.dateToRemovePwdFromKeyChain = nil
                            break
                        } else {
                            Thread.sleep(forTimeInterval: 1)
                        }
                    }
                    DPAGLog("PW background task stopped %@", "now")
                    UIApplication.shared.endBackgroundTask(strongSelf.bgTask)
                    strongSelf.bgTask = .invalid
                }
            }
        }
        if self.appWasUnlocked {
            // Speichern in den SharedContainer
            self.bgTask3 = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                DispatchQueue.main.async(execute: { [weak self] in
                    DPAGLog("background task 3 stopped %@", "expired")
                    guard let strongSelf = self else { return }
                    UIApplication.shared.endBackgroundTask(strongSelf.bgTask3)
                    strongSelf.bgTask3 = UIBackgroundTaskIdentifier.invalid
                })
            })
            let queue = DispatchQueue.global(qos: .default)
            queue.async { [weak self] in
                guard let strongSelf = self else { return }
                if DPAGApplicationFacade.preferences.isShareExtensionEnabled {
                    DPAGLog("SaveShareExtension started ")
                    do {
                        try DPAGApplicationFacade.sharedContainerSending.saveData(config: DPAGApplicationFacade.preferences.sharedContainerConfig)
                    } catch {
                        DPAGLog(error)
                    }
                    DPAGLog("SaveShareExtension finished ")
                } else {
                    DPAGApplicationFacade.sharedContainerSending.deleteData(config: DPAGApplicationFacade.preferences.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainerSending.fileName)
                }
                if DPAGApplicationFacade.preferences.previewPushNotification, DPAGApplicationFacade.preferences.backgroundAccessTokenSyncEnabled {
                    DPAGLog("SaveNotificationExtension started ")
                    do {
                        try DPAGApplicationFacade.sharedContainer.saveData(config: DPAGApplicationFacade.preferences.sharedContainerConfig)
                    } catch {
                        DPAGLog(error)
                    }
                    DPAGLog("SaveNotificationExtension finished ")
                } else {
                    DPAGApplicationFacade.sharedContainer.deleteData(config: DPAGApplicationFacade.preferences.sharedContainerConfig, filename: DPAGApplicationFacade.sharedContainer.fileName)
                }

                if bLockApplication {
                    DPAGSimsMeController.sharedInstance.deleteCachedData()
                }
                UIApplication.shared.endBackgroundTask(strongSelf.bgTask3)
                strongSelf.bgTask3 = .invalid
            }
        }
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        self.appWasUnlocked = false
    }

    // APPLICATION OPERATIONS CYCLE

    public func application(_ application: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        var isActiveState = 0
        let block = { isActiveState = UIApplication.shared.applicationState.rawValue }
        if Thread.current == Thread.main {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
        }
        DPAGLog("application: openURL applicationState: \(isActiveState)")
        DPAGLog("Start with URL")
        if self.databaseReady == false {
            DPAGLog("Database  not ready ")
            self.urlToHandle = url
            return false
        }
        DPAGLog("Database ready")
        var canHandle = false
        self.urlToHandle = nil
        if url.isFileURL || DPAGApplicationFacadeUI.urlHandler.hasMyUrlScheme(url) {
            if DPAGSimsMeController.sharedInstance.isWaitingForLogin {
                self.urlToHandle = url
            } else {
                let block = {
                    let viewControllers = DPAGApplicationFacadeUI.urlHandler.handleUrl(url)
                    if viewControllers.count > 0 {
                        canHandle = true
                        if DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.presentedViewController != nil {
                            DispatchQueue.main.async {
                                DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.dismiss(animated: false, completion: nil)
                            }
                        }
                        DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers(viewControllers, animated: true)
                    }
                }
                if (DPAGApplicationFacadeUI.urlHandler.shouldCreateInvitationBasedAccount(url)) {
                    self.performBlockOnMainThread {
                        let actionCancel = UIAlertAction(titleIdentifier: "alert.welcome.invitationbased-creation.buttonCancel", style: .cancel, handler: { _ in
                            canHandle = false
                        })
                        let actionOK = UIAlertAction(titleIdentifier: "alert.welcome.invitationbased-creation.buttonOk", style: .default, handler: { _ in
                            block()
                        })
                        DPAGApplicationFacadeUIBase.containerVC.presentAlert(alertConfig: UIViewController.AlertConfig(messageIdentifier: "alert.welcome.invitationbased-creation.message", cancelButtonAction: actionCancel, otherButtonActions: [actionOK]))
                    }
                } else {
                    block()
                }
            }
        }
        return canHandle
    }

    public func application(_ application: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        var orientations: UIInterfaceOrientationMask = .allButUpsideDown
        if let rootViewController = self.window?.rootViewController {
            orientations = rootViewController.supportedInterfaceOrientations
        }
        return orientations
    }

    public func application(_: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DPAGLog("handleEventsForBackgroundURLSession: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        DPAGApplicationFacade.requestWorker.handleEvents(forBackgroundURLSession: identifier, completionHandler: completionHandler)
    }

    // APPLICATION END CYCKE
    public func applicationWillTerminate(_ application: UIApplication) {
        DPAGApplicationFacadeUIBase.sharedApplication = application
        DPAGLog("applicationWillTerminate: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        AFNetworkReachabilityManager.shared().stopMonitoring()
        if self.databaseReady {
            DPAGSimsMeController.sharedInstance.deleteCachedData()
            DPAGApplicationFacade.cleanupModel()
        }
        if let observerUserDefaults = self.observerUserDefaults {
            NotificationCenter.default.removeObserver(observerUserDefaults)
        }
    }

    // MARK: end ApplicationDelegate
    
    public func initWindow(_: UIApplication, inBackgroundWithOptions launchOptions: [AnyHashable: Any]?) {
        DPAGLog("initWindow (ENTER)")
        self.launchOptions = launchOptions
        if UIApplication.shared.isProtectedDataAvailable {
            DPAGLog("   isProtectedDataAvailable == true")
            self.protectedDataAvailableNotification()
        } else {
            DPAGLog("   isProtectedDataAvailable == false")
            NotificationCenter.default.addObserver(self, selector: #selector(protectedDataAvailableNotification), name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        }
        DPAGLog("initWindow (EXIT)")
    }
    
    private func setupAppConfig() {
        AppConfig.applicationState = {
            var applicationState: UIApplication.State = .inactive
            let block = { applicationState = UIApplication.shared.applicationState }
            if Thread.current == Thread.main {
                block()
            } else {
                DispatchQueue.main.sync(execute: block)
            }
            return applicationState
        }
        AppConfig.backgroundTaskExecution = { block in
            var bgTask: UIBackgroundTaskIdentifier = .invalid
            bgTask = UIApplication.shared.beginBackgroundTask {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
            block()
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        AppConfig.statusBarOrientation = { UIApplication.shared.statusBarOrientation }
        AppConfig.openURL = { url in
            guard let url = url, UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        AppConfig.setIdleTimerDisabled = { disabled in
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = disabled
            }
        }
        AppConfig.appWindow = {
            UIApplication.shared.delegate?.window
        }
        AppConfig.setApplicationIconBadgeNumber = { badgeNumber in
            UIApplication.shared.applicationIconBadgeNumber = badgeNumber
        }
        AppConfig.isRegisteredForRemoteNotifications = {
            UIApplication.shared.isRegisteredForRemoteNotifications
        }
        AppConfig.registerForRemoteNotifications = {
            UIApplication.shared.registerForRemoteNotifications()
        }
        AppConfig.currentUserNotificationSettings = { block in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    block(nil)
                    return
                }
                block(settings)
            }
        }
        AppConfig.preferredContentSizeCategory = {
            UIApplication.shared.preferredContentSizeCategory
        }
        AppConfig.currentApplication = {
            UIApplication.shared
        }
    }

    @objc
    func protectedDataAvailableNotification() {
        DPAGLog("protectedDataAvailableNotification (ENTER)")
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window
        self.initAppInstance()
        self.setupAppConfig()
        NotificationCenter.default.removeObserver(self, name: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didCompleteLogin), name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(forceNotificationUpdate), name: DPAGStrings.Notification.Application.FORCE_NOTIFICATION_UPDATE, object: nil)
        window.makeKeyAndVisible()
        let rootVC = DPAGApplicationFacadeUIBase.rootContainerVC
        rootVC.rootViewController = DPAGApplicationFacadeUI.launchMigrationVC()
        window.rootViewController = rootVC
        self.window = window
        let applicationState = UIApplication.shared.applicationState
        let application = UIApplication.shared
        if !self.preferencesLoaded {
            self.preferencesLoaded = DPAGApplicationFacade.preferences.setup()
        }
        self.performBlockInBackground { [weak self] in
            self?.launchApplication(application, inBackgroundWithOptions: self?.launchOptions, applicationState: applicationState)
            self?.launchOptions = nil
        }
        // The launchApplication-Call above will run in background and initialize the DB, but since it is
        // running parallel to this thread, we need to wait until the DB is ready, before we can do anything further
        waitForDatabase()
        DPAGLog("protectedDataAvailableNotification (EXIT)")
    }

    @objc
    private func didCompleteLogin() {
        DPAGLog("didCompleteLogin")
        DPAGSimsMeController.sharedInstance.isWaitingForLogin = false
        DPAGApplicationFacade.model.setupDeviceData()
        DPAGApplicationFacade.model.update(with: nil)
        DPAGApplicationFacade.cache.initFetchedResultsController()
        DPAGApplicationFacade.cache.clearCache()
        DPAGApplicationFacade.preferences.resetPasswordTries()
        DPAGApplicationFacade.preferences.passwordInputWrongCounter = 0
        let rootViewController = DPAGSimsMeController.sharedInstance.startViewController()
        let viewControllers = self.handleUrl()
        if let rootViewController = rootViewController, rootViewController === DPAGSimsMeController.sharedInstance.chatsListViewController {
            if viewControllers.count > 0 {
                DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers(viewControllers, animated: false)
            } else if DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers.count == 0 || DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers.first != DPAGSimsMeController.sharedInstance.chatsListViewController {
                if Thread.current == Thread.main {
                    DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewController], animated: false)
                } else {
                    DispatchQueue.main.sync{
                        DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewController], animated: false)
                    }
                }
            }
        } else if let rootViewControllerMigration = rootViewController as? (UIViewController & DPAGMigrationViewControllerProtocol) {
            if Thread.current == Thread.main {
                  DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewControllerMigration], animated: false)
            } else {
                DispatchQueue.main.sync{
                    DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewControllerMigration], animated: false)
                }
            }
            return
        } else if let classForCoder = viewControllers.first?.classForCoder, let rootViewControllerCheck = rootViewController, rootViewControllerCheck.isKind(of: classForCoder) {
            if Thread.current == Thread.main {
                DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers(viewControllers, animated: false)
            } else {
                DispatchQueue.main.sync{
                    DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers(viewControllers, animated: false)
                }
            }
            return
        } else if let rootViewControllerNew = rootViewController, DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers.count == 0 || DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers.first != rootViewControllerNew {
            if Thread.current == Thread.main {
                DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewControllerNew], animated: false)
            } else {
                DispatchQueue.main.sync{
                    DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([rootViewControllerNew], animated: false)
                }
            }
        }
        DPAGSimsMeController.sharedInstance.performTasksOnAppStart()
    }

    func handleUrl() -> [UIViewController] {
        var retVal: [UIViewController] = []
        if let urlToHandle = self.urlToHandle {
            retVal = DPAGApplicationFacadeUI.urlHandler.handleUrl(urlToHandle)
            self.urlToHandle = nil
        }
        return retVal
    }

    public func initAppInstanceBA() {
        DPAGColorProvider.shared.updateProviderBA()
        DPAGImageProvider.shared.updateProviderBA()
        DPAGApplicationFacade.runtimeConfig = DPAGRuntimeConfigBA()
    }

    open func initAppInstance() {
        DPAGApplicationFacade.runtimeConfig = DPAGRuntimeConfigUI()
    }

    @objc
    func coreDataRunLoop() {
        autoreleasepool {
            Thread.current.name = "RootSavingContext Init"
            // Simulate slow starting Database-Migration
            // [NSThread sleepForTimeInterval:20]
            DPAGLog("Trying to start launchDB")
            DPAGApplicationFacade.setupModel()
            DPAGLog("setupModel Successfull")
            if DPAGPreferencesMigrator.needsMigration() {
                DPAGLog("Waiting for migration")
                if DPAGApplicationFacade.accountManager.hasAccount() {
                    for _ in 0 ... 10 {
                        DPAGLog("...Waiting for migration")
                        if DPAGPreferencesMigrator.canMigrate() {
                            break
                        }
                        Thread.sleep(forTimeInterval: TimeInterval(0.1))
                    }
                }
                DPAGLog("Migarting DB")
                DPAGPreferencesMigrator.migrate()
                DPAGLog("Migration ready")
            }
            self.databaseReady = true
            DPAGLog("Launch DB Ready")
            Thread.current.name = "RootSavingContext"
            if let semaphore = self.semaphore {
                semaphore.signal()
            }
            // Enter RunLoop
            let runLoop = RunLoop.current
            runLoop.add(NSMachPort(), forMode: RunLoop.Mode.default)
            CFRunLoopRun()
        }
    }

    func launchApplication(_ application: UIApplication, inBackgroundWithOptions launchOptions: [AnyHashable: Any]?, applicationState: UIApplication.State) {
        DPAGLog("launchApplication: (ENTER) applicationState: \(applicationState.rawValue)")
        self.databaseReady = false
        do {
            try DPAGFileHelper.initModel()
        } catch {
            DPAGLog("Launch: Set 'excludeFromBackup' failed - will try later...")
            DPAGLog(error)
        }
        DPAGLog("   initModel Done")
        self.semaphore = DispatchSemaphore(value: 0)
        self.coreDataThread = Thread(target: self, selector: #selector(coreDataRunLoop), object: nil)
        self.coreDataThread?.start()
        _ = self.semaphore?.wait(timeout: .distantFuture)
        DPAGLog("   coreData running")
        do {
            try DPAGFileHelper.changeDBProtection()
        } catch {
            
        }
        NotificationCenter.default.addObserver(self, selector: #selector(appUIReadyWithPrivateKey), name: DPAGStrings.Notification.Application.UI_IS_READY_WITH_PRIVATE_KEY, object: nil)
        if DPAGApplicationFacade.preferences.isBaMandant {
            DPAGApplicationFacade.preferences.readMDMValues()
        }
        let groupID = DPAGApplicationFacade.preferences.sharedContainerConfig.groupID
        let dbFullTextVersion = DPAGDBFullTextHelper.checkDBConnection(withGroupId: groupID)
        if dbFullTextVersion >= 0 {
            DPAGDBFullTextHelper.upgradeDB(withGroupId: groupID, fromVersion: dbFullTextVersion)
        }
        self.performBlockOnMainThread { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.window?.configureUI()
            strongSelf.setup()
            _ = strongSelf.waitForDatabase()
            DPAGSimsMeController.sharedInstance.setup()
            if launchOptions != nil, let userInfo = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
                DPAGSimsMeController.sharedInstance.handleUserInfo(userInfo, forApplication: application, wasInState: applicationState)
            }
            // Start monitoring the internet connection
            AFNetworkReachabilityManager.shared().startMonitoring()
            if DPAGApplicationFacade.preferences.isBaMandant {
                // Add Notification Center observer to be alerted of any change to NSUserDefaults.
                // Managed app configuration changes pushed down from an MDM server appear in NSUSerDefaults.
                strongSelf.observerUserDefaults = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { _ in
                    DPAGApplicationFacade.preferences.readMDMValues()
                })
            }
            strongSelf.syncAddressBook()
        }
        DPAGLog("launchApplication: (EXIT) applicationState: \(applicationState.rawValue)")
    }

    func setup() {
        DPAGLog("setup: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        DPAGUIHelper.setupAppAppearance()
        let lockView = DPAGUIHelper.setupLockView(frame: self.window?.bounds ?? CGRect.zero)
        self.lockViews = [lockView]
    }

    @objc
    private func forceNotificationUpdate() {
        self.notificationUpdateWorker = nil
    }

    private var appWasUnlocked = false

    @objc
    private func appUIReadyWithPrivateKey() {
        DPAGLog("appUIReadyWithPrivateKey: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        self.appWasUnlocked = true
        self.backupStartDate = Date().addingTimeInterval(30)
        // Update push notifications registration status
        if self.notificationUpdateWorker == nil {
            let state = DPAGApplicationFacade.preferences.notificationRegistrationState
            self.notificationUpdateWorker = DPAGApplicationFacadeUI.notificationStateUpdateWorker()
            self.notificationUpdateWorker?.delegate = self
            self.notificationUpdateWorker?.update(state)
        }
        self.clearBadgeIfNecessary()
        self.performBlockInBackground {
            DPAGApplicationFacade.couplingWorker.fetchOwnTempDevice()
            if DPAGApplicationFacade.preferences.hasPendingMessages() {
                DPAGApplicationFacade.couplingWorker.fetchPendingMessages()
            }
            if DPAGApplicationFacade.preferences[.kPublicOnlineState] == nil {
                DPAGApplicationFacade.profileWorker.setPublicOnlineState(enabled: true, withResponse: nil)
            }
//            DPAGApplicationFacade.companyAdressbook.updateFullTextStates()
        }
        // 30 Sekunden warten, bevor wir das Backup starten
        self.perform(#selector(checkAndStartBackup), with: self, afterDelay: 30)
        UNUserNotificationCenter.current().delegate = self
    }
    
    func syncAddressBook() {
        self.performBlockInBackground { [weak self] in
            if DPAGApplicationFacade.preferences.shouldSyncContancs() {
                self?.syncHelper = DPAGSynchronizationHelperAddressbook()
                self?.syncHelper?.syncPrivateAddressbookNoHUD(completion: { [weak self] in
                    if DPAGApplicationFacade.preferences.isBaMandant {
                        DPAGApplicationFacade.preferences.addressInformationsCompanyDate = Date(timeIntervalSince1970: TimeInterval(0))
                        self?.syncHelper?.syncCompanyAddressbookNoHUD(completion: { [weak self] in
                            self?.syncHelper = nil
                        })
                    }
                    self?.syncHelper = nil
                })
                DPAGApplicationFacade.preferences.updateLastDateReminderShown()
            }
        }
    }

    @objc
    func checkAndStartBackup() {
        self.performBlockInBackground { [weak self] in
            if (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
                return
            }
            if (self?.backupStartDate?.isInPast ?? true) == false {
                return
            }
            DPAGApplicationFacade.cache.checkInvalidMessages()
            if (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
                return
            }
            if AppConfig.applicationState() == .active {
                DPAGApplicationFacade.backupWorker.makeAutomaticBackup()
            }
        }
    }

    func lockApplication() {
        DPAGLog("lockApplication: applicationState: \(UIApplication.shared.applicationState.rawValue)")
        DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.isNavigationBarHidden = false
        CryptoHelper.sharedInstance?.deleteDecryptedPrivateKeyinKeyChain()
        DPAGLocalNotificationViewController.hideAllNotifications(false)
        if (self.window?.rootViewController?.presentedViewController is DPAGLoginViewControllerProtocol) == false {
            let lockViewLogin = DPAGUIHelper.setupLockViewLogin(frame: self.window?.bounds ?? .zero)
            lockViewLogin.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate + 1)"
            self.window?.addSubview(lockViewLogin)
            self.lockViews?.append(lockViewLogin)
        }
        let lastWindow = UIApplication.shared.windows.last
        if lastWindow != self.window {
            if (self.window?.rootViewController?.presentedViewController is DPAGLoginViewControllerProtocol) == false {
                let lockViewLogin = DPAGUIHelper.setupLockViewLogin(frame: lastWindow?.bounds ?? .zero)
                lockViewLogin.lockViewLabel?.accessibilityIdentifier = "\(Date().timeIntervalSinceReferenceDate + 1)"
                lastWindow?.addSubview(lockViewLogin)
                self.lockViews?.append(lockViewLogin)
            }
        }
    }

    @discardableResult
    func waitForDatabase() -> Bool {
        if self.databaseReady == false {
            DPAGLog("Database not ready")
            for _ in 0 ..< 1_000 {
                if self.databaseReady {
                    break
                }
                DPAGLog("Database still not ready")
                // Wenn die Datenbank noch nicht geladen wurde, dann 100 ms warten, insgesamt nicht mehr als 1 sekunden
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            }
        }
        if self.databaseReady == false {
            assert(false)
        }
        return self.databaseReady
    }

    public func appWillEnterForeground(_: UIApplication) {
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.WILL_ENTER_FOREGROUND, object: nil)
        var loginRequired = false
        if self.bgTask != UIBackgroundTaskIdentifier.invalid {
            DPAGLog("background task stopped %@", "on foreground")
            UIApplication.shared.endBackgroundTask(self.bgTask)
            self.bgTask = UIBackgroundTaskIdentifier.invalid
        }
        self.waitForDatabase()
        if self.databaseReady {
            if let dateToRemovePwdFromKeyChain = self.dateToRemovePwdFromKeyChain, dateToRemovePwdFromKeyChain.compare(Date()) == .orderedAscending {
                DPAGLog("Requesting login (password entry) because dateToRemovePwdFromKeyChain expired...")
                self.lockApplication()
                self.dateToRemovePwdFromKeyChain = nil
                loginRequired = true
            }
            if let deviceCrypto = CryptoHelper.sharedInstance, deviceCrypto.hasPrivateKey(), (try? deviceCrypto.aesKeyFileExists(forPasswordProtectedKey: true)) ?? false {
                if DPAGApplicationFacade.preferences.lockApplicationImmediately || loginRequired || (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
                    DPAGLog("1-Requesting login (password entry) because...")
                    if DPAGApplicationFacade.preferences.lockApplicationImmediately {
                        DPAGLog("1-.... lockApplicationImmediately")
                    }
                    if loginRequired {
                        DPAGLog("1-.... loginRequired")
                    }
                    if CryptoHelper.sharedInstance == nil {
                        DPAGLog("1-.... no CryptoHelper.sharedInstance")
                    }
                    if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
                        DPAGLog("1-.... isPrivateKeyDecrypted == false")
                    }
                    DPAGApplicationFacade.preferences.resetLockApplicationImmediately()
                    DPAGProgressHUD.sharedInstance.hide(false) {
                        DPAGSimsMeController.sharedInstance.logIn()
                    }
                } else if DPAGApplicationFacade.cache.account?.accountState == .confirmed {
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.PERFORM_TASKS_ON_APP_START, object: nil)
                }
            }
        }
    }

    func clearBadgeIfNecessary() {
        if UIApplication.shared.applicationIconBadgeNumber > 0 {
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            self.performBlockInBackground {
                let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
                    if let errorMessage = errorMessage {
                        DPAGLog(errorMessage)
                    }
                }
                DPAGApplicationFacade.requestWorker.resetBadge(withResponse: responseBlock)
            }
        }
    }

    // MARK: - Push Notifications

    public func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DPAGSimsMeController.sharedInstance.didFailToRegisterForRemoteNotificationsWithError(error)
    }

    public func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DPAGSimsMeController.sharedInstance.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
    }

    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        DPAGLog("didReceiveRemoteNotification With Handler:\n%@,\napplicationState: %@", LoggingHelper.stripNameFromPayload(userInfo), NSNumber(value: application.applicationState.rawValue))
        let applicationState = application.applicationState
        waitForDatabase()
        if applicationState == .inactive {
            DPAGLog("Inactive")
            // TODO: userInfo zwischenspeichern
            if DPAGSimsMeController.sharedInstance.pushNotificationUserInfo == nil {
                // We can't handle this right now, save it for later
                var notificationUserInfo = userInfo
                notificationUserInfo["applicationState"] = NSNumber(value: applicationState.rawValue)
                DPAGSimsMeController.sharedInstance.pushNotificationUserInfo = notificationUserInfo
            }
            completionHandler(.failed)
        } else if applicationState == .background {
            DPAGLog("Background")
            // Fetch  the Message
            if let messageGuid = userInfo["messageGuid"] as? String, messageGuid.hasPrefix(.messageChat) || messageGuid.hasPrefix(.messageGroup) || messageGuid.hasPrefix(.messagePrivateInternal) || messageGuid.hasPrefix(.messageInternal) {
                DPAGLog("Background Message %@", messageGuid)
                if self.pushHandleMessageGuids.contains(messageGuid) || DPAGApplicationFacade.model.httpUsername == nil {
                    completionHandler(.noData)
                    return
                }
                self.pushHandleMessageGuids.append(messageGuid)
                if self.pushHandleMessageGuids.count > 50 {
                    self.pushHandleMessageGuids.remove(at: 0)
                }
                self.performBlockInBackground {
                    DPAGApplicationFacade.requestWorker.fetchBackgroundMessage(messageGuid: messageGuid, userInfo: userInfo, fetchCompletionHandler: completionHandler)
                }
            } else {
                completionHandler(.noData)
            }
        } else {
            DPAGLog("Active")
            completionHandler(.noData)
        }
    }

// deprecated since iOS 10.0
//    public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], completionHandler: @escaping DPAGCompletion) {
//        DPAGLog("handleActionWithIdentifier:\n%@,\nuserInfo:\n%@,\napplicationState: %@", identifier ?? "noIdent", LoggingHelper.stripNameFromPayload(userInfo), NSNumber(value: application.applicationState.rawValue as Int))
//        let applicationState = application.applicationState
//        DispatchQueue.main.async {
//            self.waitForDatabase()
//            DPAGSimsMeController.sharedInstance.handleUserInfo(userInfo, forApplication: application, wasInState: applicationState)
//            completionHandler()
//        }
//    }

    // TODO: Add support for universal links
    public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb, let incomingURL = userActivity.webpageURL, let components = NSURLComponents(url: incomingURL, resolvingAgainstBaseURL: true) else { return false }

        // Check for specific URL components that you need.
        guard let path = components.path, let params = components.queryItems else { return false }
        print("path = \(path)")
        if let actualParams = params.first(where: { $0.name == "p" } )?.value, let signature = params.first(where: { $0.name == "q" })?.value {
            print("actualParams = \(actualParams)")
            print("signature = \(signature)")
            JitsiMeet.sharedInstance().application(application, continue: userActivity, restorationHandler: restorationHandler)
            return true

        } else {
            print("Either album name or photo index missing")
            JitsiMeet.sharedInstance().application(application, continue: userActivity, restorationHandler: restorationHandler)
            return false
        }
    }
}

// MARK: - DPAGNotificationWorkerDelegate

extension DPAGAppDelegate: DPAGNotificationWorkerDelegate {
    public func notificationSetupComplete() {
        self.notificationUpdateWorker = nil
    }

    public func notificationSetupDidFail() {
        self.notificationUpdateWorker = nil
    }
}

extension DPAGAppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler _: @escaping (UNNotificationPresentationOptions) -> Void) {
        DPAGSimsMeController.sharedInstance.pushNotificationUserInfo = notification.request.content.userInfo
    }
}
