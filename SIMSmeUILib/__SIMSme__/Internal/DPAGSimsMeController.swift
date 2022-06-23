//
// Created by mg on 20.09.13.
// Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import MagicalRecord
import SIMSmeCore
import UIKit
import UserNotifications

struct DPAGSimsMeControllerCacheVersions {
  var updateServerConfig = true
  var updateMandanten = true
  var updateChannels = true
  var updateServices = true
  var updateCompanyLayout = true
  var updateCompanyMDMConfig = true
  var updateBlocked = true
  var updatePrivateIndex = true
  var updateConfirmedIdentities = true
  var updateCompanyIndex = true
  
  var cacheVersionServerConfigServer: String = ""
  var cacheVersionMandantenServer: String = ""
  var cacheVersionCompanyLayoutServer: String = ""
  var cacheVersionCompanyMDMConfigServer: String = ""
  var cacheVersionChannelsServer: String = ""
  var cacheVersionServicesServer: String = ""
  var cacheVersionGetBlockedServer: String = ""
  var cacheVersionPrivateIndexServer: String = ""
  var cacheVersionConfirmedIdentitiesServer: String = ""
  var cacheVersionCompanyIndexServer: String = ""
  
  static func parseServerResponse(_ responseObject: Any?) -> DPAGSimsMeControllerCacheVersions {
    var cacheVersions = DPAGSimsMeControllerCacheVersions()
    if let dict = responseObject as? [String: String] {
      // Server Configuration
      if let cacheVersionServer = dict[DPAGServerCacheKey.getConfiguration.rawValue] {
        cacheVersions.cacheVersionServerConfigServer = cacheVersionServer
      }
      if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionServerConfig] {
        cacheVersions.updateServerConfig = cacheVersionLocal != cacheVersions.cacheVersionServerConfigServer
      }
      // Mandanten
      if let cacheVersionServer = dict[DPAGServerCacheKey.getMandanten.rawValue] {
        cacheVersions.cacheVersionMandantenServer = cacheVersionServer
      }
      if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionMandanten] {
        cacheVersions.updateMandanten = cacheVersionLocal != cacheVersions.cacheVersionMandantenServer
      }
      if let cacheVersionServer = dict[DPAGServerCacheKey.listPrivateIndex.rawValue] {
        cacheVersions.cacheVersionPrivateIndexServer = cacheVersionServer
      }
      if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionPrivateIndex] {
        cacheVersions.updatePrivateIndex = cacheVersionLocal != cacheVersions.cacheVersionPrivateIndexServer
      }
      if let cacheVersionServer = dict[DPAGServerCacheKey.getConfirmedIdentities.rawValue] {
        cacheVersions.cacheVersionConfirmedIdentitiesServer = cacheVersionServer
      }
      if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionConfirmedIdentities] {
        cacheVersions.updateConfirmedIdentities = cacheVersionLocal != cacheVersions.cacheVersionConfirmedIdentitiesServer
      }
      if DPAGApplicationFacade.preferences.isBaMandant {
        cacheVersions.updateChannels = false
        cacheVersions.updateServices = false
        // BA Company Layout
        if let cacheVersionServer = dict[DPAGServerCacheKey.getCompanyLayout.rawValue] {
          cacheVersions.cacheVersionCompanyLayoutServer = cacheVersionServer
        }
        if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionCompanyLayout] {
          cacheVersions.updateCompanyLayout = cacheVersionLocal != cacheVersions.cacheVersionCompanyLayoutServer
        }
        // AppSettings(MDM Config)
        if let cacheVersionServer = dict[DPAGServerCacheKey.getCompanyAppSettings.rawValue] {
          cacheVersions.cacheVersionCompanyMDMConfigServer = cacheVersionServer
        }
        if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionCompanyMDMConfig] {
          cacheVersions.updateCompanyMDMConfig = cacheVersionLocal != cacheVersions.cacheVersionCompanyMDMConfigServer
        }
        if let cacheVersionServer = dict[DPAGServerCacheKey.listCompanyIndex.rawValue] {
          cacheVersions.cacheVersionCompanyIndexServer = cacheVersionServer
        }
        if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionCompanyIndex] {
          cacheVersions.updateCompanyIndex = cacheVersionLocal != cacheVersions.cacheVersionCompanyIndexServer
        }
      } else {
        cacheVersions.updateCompanyLayout = false
        cacheVersions.updateCompanyMDMConfig = false
        // PK Channels
        if let cacheVersionServer = dict[DPAGServerCacheKey.getChannels.rawValue] {
          cacheVersions.cacheVersionChannelsServer = cacheVersionServer
        }
        if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionChannels] {
          cacheVersions.updateChannels = cacheVersionLocal != cacheVersions.cacheVersionChannelsServer
        }
        // PK Services
        if let cacheVersionServer = dict[DPAGServerCacheKey.getServices.rawValue] {
          cacheVersions.cacheVersionServicesServer = cacheVersionServer
        }
        if let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionServices] {
          cacheVersions.updateServices = cacheVersionLocal != cacheVersions.cacheVersionServicesServer
        }
      }
      if DPAGApplicationFacade.preferences.supportMultiDevice {
        if let cacheVersionServer = dict[DPAGServerCacheKey.getBlocked.rawValue] {
          cacheVersions.cacheVersionGetBlockedServer = cacheVersionServer
        }
        let cacheVersionLocal = DPAGApplicationFacade.preferences[.kCacheVersionGetBlocked]
        cacheVersions.updateBlocked = cacheVersions.cacheVersionGetBlockedServer != cacheVersionLocal
        if let cacheVersionServer = dict[DPAGServerCacheKey.getAutoGeneratedMessages.rawValue] {
          DPAGApplicationFacade.preferences.markMessagesAsReadEnabled = (cacheVersionServer == "1")
        }
        if let cacheVersionServer = dict[DPAGServerCacheKey.getPublicOnlineState.rawValue] {
          DPAGApplicationFacade.preferences.publicOnlineStateEnabled = (cacheVersionServer == "1")
        }
      }
    } else {
      if DPAGApplicationFacade.preferences.isBaMandant == false {
        cacheVersions.updateCompanyLayout = false
        cacheVersions.updateCompanyMDMConfig = false
        if DPAGApplicationFacade.preferences.isChannelsAllowed == false {
          cacheVersions.updateChannels = false
        }
        //                if DPAGApplicationFacade.preferences.isServicesAllowed == false {
        cacheVersions.updateServices = false
        //                }
      } else {
        cacheVersions.updateChannels = false
        cacheVersions.updateServices = false
      }
    }
    return cacheVersions
  }
}

public class DPAGSimsMeController: NSObject {
  public static let sharedInstance = DPAGSimsMeController()
  
  public var isWaitingForLogin = false
  var isSyncConfigVersionsRunning = false
  public var pushNotificationUserInfo: [AnyHashable: Any]?
  weak var notificationDelegate: DPAGRegisterNotificationDelegate?
  var confirmAccountViewController: UIViewController?
  var welcomeViewController: (UIViewController & DPAGWelcomeViewControllerProtocol)?
  fileprivate var _chatsListViewController: (UIViewController & DPAGChatsListViewControllerProtocol & DPAGNewChatDelegate)?
  
  public var chatsListViewController: UIViewController & DPAGChatsListViewControllerProtocol & DPAGNewChatDelegate {
    if let chatsListVC = self._chatsListViewController {
      return chatsListVC
    }
    let chatsListVC = DPAGApplicationFacadeUI.chatsListVC()
    self._chatsListViewController = chatsListVC
    // Lazy Getter, um den View zu initialisieren....
    _ = chatsListVC.view.isHidden
    return chatsListVC
  }
  
  var executingFirstRunAfterUpdate: Bool?
  var pushToChatEnabled = false
  var syncHelper: DPAGSynchronizationHelperAddressbook?
  
  override init() {
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground(_:)), name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(resetApplication(_:)), name: DPAGStrings.Notification.Application.SECURITY_RESET_APP, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(didHideLoginView), name: DPAGStrings.Notification.Application.DID_HIDE_LOGIN, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(performTasksOnAppStart), name: DPAGStrings.Notification.Application.PERFORM_TASKS_ON_APP_START, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(updateTestLicenseDate), name: DPAGStrings.Notification.Licence.LICENCE_UPDATE_TESTLICENCE_DATE, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(showDeleteProfileVC), name: DPAGStrings.Notification.Account.SHOW_DELETE_PROFILE_VC, object: nil)
    DPAGApplicationFacade.isResetingAccount = false
    self.pushToChatEnabled = true
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func updateLayoutColors() {
    DPAGUIHelper.setupAppAppearance()
  }
  
  @objc
  private func showDeleteProfileVC() {
    DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.visibleViewController?.navigationController?.pushViewController(DPAGApplicationFacadeUISettings.deleteProfileVC(showAccountID: false), animated: true)
  }
  
  @objc
  private func resetApplication(_ aNotification: Notification?) {
    AppConfig.setApplicationIconBadgeNumber(0)
    DPAGApplicationFacade.isResetingAccount = true
    let blockResetBackground = { [weak self] in
      DPAGApplicationFacadeUI.newMessageNotifier.stopRequesting()
      DPAGApplicationFacade.accountManager.resetAccount()
      DPAGApplicationFacade.preferences.resetFirstRunAfterUpdate()
      self?.executingFirstRunAfterUpdate = nil
      DPAGApplicationFacade.isResetingAccount = false
    }
    DPAGProgressHUD.sharedInstance.hide(false) {
      DPAGLog("nav controller %@", DPAGApplicationFacadeUIBase.containerVC.mainNavigationController)
      NotificationCenter.default.post(name: DPAGStrings.Notification.Application.FORCE_NOTIFICATION_UPDATE, object: nil)
      AppConfig.appWindow()??.rootViewController?.presentedViewController?.dismiss(animated: false, completion: nil)
      if DPAGApplicationFacade.preferences.isBaMandant {
        DPAGApplicationFacade.preferences.setDefaults()
        self.updateLayoutColors()
      }
      DPAGApplicationFacadeUIBase.rootContainerVC.presentedViewController?.dismiss(animated: false, completion: nil)
      DPAGApplicationFacadeUIBase.containerVC.presentedViewController?.dismiss(animated: false, completion: nil)
      DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.presentedViewController?.dismiss(animated: false, completion: nil)
      DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.visibleViewController?.presentedViewController?.dismiss(animated: false, completion: nil)
      DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.dismiss(animated: false, completion: nil)
      if UIDevice.current.userInterfaceIdiom == .pad {
        DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.presentedViewController?.dismiss(animated: false, completion: nil)
        DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.visibleViewController?.presentedViewController?.dismiss(animated: false, completion: nil)
        DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.dismiss(animated: false, completion: nil)
        self.setupIPad()
      } else {
        DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([DPAGApplicationFacadeUIRegistration.introVC()], animated: false)
      }
      self.welcomeViewController = nil
      self.confirmAccountViewController = nil
      self._chatsListViewController = nil
      if aNotification?.object == nil {
        self.performBlockInBackground(blockResetBackground)
      } else {
        blockResetBackground()
      }
    }
    self.isWaitingForLogin = false
    DPAGApplicationFacadeUIBase.loginVC.mustChangePassword = false
  }
  
  public func startViewController() -> UIViewController? {
    if let nextViewController = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagSimsMeController_startViewController) {
      return nextViewController
    }
    guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) else {
      return DPAGApplicationFacadeUIRegistration.introVC()
    }
    if account.accountState == .waitForConfirm {
      if self.confirmAccountViewController == nil {
        self.confirmAccountViewController = DPAGApplicationFacadeUIRegistration.confirmAccountVC(confirmationCode: DPAGApplicationFacade.preferences.bootstrappingConfirmationCode)
      }
      return self.confirmAccountViewController
    } else if let accountID = contact.accountID, contact.nickName == nil {
      if self.welcomeViewController == nil || self.welcomeViewController?.accountGuid != account.guid {
        self.welcomeViewController = DPAGApplicationFacadeUIRegistration.welcomeVC(account: account.guid, accountID: accountID, phoneNumber: contact.phoneNumber, emailAddress: contact.eMailAddress, emailDomain: contact.eMailDomain, checkUsage: true)
      }
      return self.welcomeViewController
    } else {
      if let migrationViewController = DPAGApplicationFacadeUI.migrationVC() {
        return migrationViewController
      }
      if DPAGApplicationFacadeUIBase.loginVC.mustChangePassword {
        return DPAGApplicationFacadeUISettings.changePasswordVC()
      } else {
        return self.chatsListViewController
      }
    }
  }
  
  public func handleUserInfo(_ dictionary: [AnyHashable: Any], forApplication application: UIApplication?, wasInState applicationState: UIApplication.State) {
    DPAGLog("app did start with push notification or got one in foreground\n%@", LoggingHelper.stripNameFromPayload(dictionary))
    if self.isWaitingForLogin {
      if applicationState == .inactive, self.pushNotificationUserInfo == nil {
        // We can't handle this right now, save it for later
        var notificationUserInfo = dictionary
        notificationUserInfo["applicationState"] = NSNumber(value: applicationState.rawValue)
        self.pushNotificationUserInfo = notificationUserInfo
      }
    } else {
      self.pushNotificationUserInfo = nil
      if let aps = dictionary["aps"] as? [String: Any], let badge = aps["badge"] as? NSNumber {
        AppConfig.setApplicationIconBadgeNumber(badge.intValue)
      }
      if let action = dictionary["action"] as? String {
        if action == DPAGStrings.Notification.Push.NEW_MESSAGES.rawValue {
          var applicationState = application?.applicationState
          if let applicationStateNumber = dictionary["applicationState"] as? NSNumber, let applicationStateNumberValue = UIApplication.State(rawValue: applicationStateNumber.intValue) {
            applicationState = applicationStateNumberValue
          }
          if applicationState != .active {
            self.handlePushForNewMessage(userInfo: dictionary)
          }
        }
      }
    }
  }
  
  fileprivate func chatDelegate() -> DPAGNewChatDelegate? {
    for viewController in DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers {
      if let viewControllerNewChatDelegate = viewController as? DPAGNewChatDelegate {
        return viewControllerNewChatDelegate
      }
    }
    return self.chatsListViewController
  }
  
  fileprivate func dismissPresentedViewControllers(_ allPresentedViewControllers: [UIViewController], animated: Bool, completionInBackground: Bool?, completion: DPAGCompletion?) {
    if let topmostController = allPresentedViewControllers.count > 0 ? allPresentedViewControllers.first : nil {
      topmostController.dismiss(animated: true) { [weak self] in
        var allPresentedViewControllersNew = allPresentedViewControllers
        allPresentedViewControllersNew.removeFirst()
        self?.dismissPresentedViewControllers(allPresentedViewControllersNew, animated: animated, completionInBackground: completionInBackground, completion: completion)
      }
    } else {
      if completion != nil {
        if completionInBackground ?? false {
          self.performBlockInBackground {
            completion?()
          }
        } else {
          self.performBlockOnMainThread {
            completion?()
          }
        }
      }
    }
  }
  
  func dismissAllPresentedNavigationControllers(_ animated: Bool, completionInBackground: Bool?, completion: DPAGCompletion?) {
    let allPresentedViewControllers = DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.allPresentedViewControllers().sorted { (obj1, obj2) -> Bool in
      (obj1.presentedZIndex?.intValue ?? 0) <= (obj2.presentedZIndex?.intValue ?? 0)
    }
    self.dismissPresentedViewControllers(allPresentedViewControllers, animated: animated, completionInBackground: completionInBackground, completion: completion)
  }
  
  fileprivate func handlePushForNewMessage(userInfo dictionary: [AnyHashable: Any]?) {
    let senderGuid = dictionary?["senderGuid"] as? String
    if self.chatsListViewController.isModelLoaded == false {
      self.performBlockInBackground { [weak self] in
        Thread.sleep(forTimeInterval: 0.3)
        self?.performBlockOnMainThread { [weak self] in
          self?.handlePushForNewMessage(userInfo: dictionary)
        }
      }
      return
    }
    if let locKey = ((dictionary?["aps"] as? [AnyHashable: Any])?["alert"] as? [AnyHashable: Any])?["loc-key"] as? String {
      if locKey == "push.newCN" {
        if self.pushToChatEnabled, let senderGuid = senderGuid {
          self.pushToChatEnabled = false
          // Private message
          if let channel = DPAGApplicationFacade.cache.channel(for: senderGuid), channel.isSubscribed {
            DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
              self?.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
                Thread.sleep(forTimeInterval: 1)
                DPAGChatHelper.openChatStreamView(senderGuid, navigationController: self?.chatsListViewController.navigationController, startChatWithUnconfirmedContact: true, showMessage: dictionary?["messageGuid"] as? String, draftText: nil) { _ in
                  DPAGProgressHUD.sharedInstance.hide(true)
                }
              }
            }
          }
          return
        }
      } else if locKey == "push.newPN" || locKey == "push.newPNex" || locKey == "push.newPNexHigh" {
        if self.pushToChatEnabled, let senderGuid = senderGuid {
          self.pushToChatEnabled = false
          // Private message
          if let contact = DPAGApplicationFacade.cache.contact(for: senderGuid), let streamGuid = contact.streamGuid, contact.isConfirmed {
            DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
              self?.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
                Thread.sleep(forTimeInterval: 1)
                if contact.isDeleted { // Check if contact is really deleted (MELO-454)
                  self?.performBlockInBackground {
                    DPAGApplicationFacade.updateKnownContactsWorker.getAccountInfo(accountGuid: senderGuid, withProfile: true, withTempDevice: true) { _, _, errorMessage in
                      if errorMessage == nil {
                        contact.setIsDeleted(false)
                        DPAGApplicationFacade.contactsWorker.unDeleteContact(withContactGuid: senderGuid)
                      }
                      self?.performBlockOnMainThread {
                        DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self?.chatsListViewController.navigationController, startChatWithUnconfirmedContact: true, showMessage: dictionary?["messageGuid"] as? String, draftText: nil) { _ in
                          DPAGProgressHUD.sharedInstance.hide(true)
                        }
                      }
                    }
                  }
                  return
                }
                DPAGChatHelper.openChatStreamView(streamGuid, navigationController: self?.chatsListViewController.navigationController, startChatWithUnconfirmedContact: true, showMessage: dictionary?["messageGuid"] as? String, draftText: nil) { _ in
                  DPAGProgressHUD.sharedInstance.hide(true)
                }
              }
            }
            return
          }
          if let group = DPAGApplicationFacade.cache.group(for: senderGuid), group.isConfirmed {
            DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
              self?.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
                Thread.sleep(forTimeInterval: 1)
                DPAGChatHelper.openChatStreamView(senderGuid, navigationController: self?.chatsListViewController.navigationController, startChatWithUnconfirmedContact: true, showMessage: dictionary?["messageGuid"] as? String, draftText: nil) { _ in
                  DPAGProgressHUD.sharedInstance.hide(true)
                }
              }
            }
            return
          }
          // Wenn wir hier sind, dann ist die Nachricht von einem nicht bestaetigten Account
          DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
            self?.dismissAllPresentedNavigationControllers(true, completionInBackground: false) {
              DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(DPAGSimsMeController.sharedInstance.chatsListViewController, addViewController: nil) {
                DPAGSimsMeController.sharedInstance.chatsListViewController.tableView.scrollRectToVisible(.zero, animated: true)
                DPAGProgressHUD.sharedInstance.hide(true)
              }
            }
          }
        }
      } else if locKey == "push.groupInv" || locKey == "push.groupInvEx" || locKey == "push.managedRoomInv" || locKey == "push.managedRoomInvEx" || locKey == "push.restrictedRoomInv" || locKey == "push.restrictedRoomInvEx" {
        if self.pushToChatEnabled {
          self.pushToChatEnabled = false
          DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
            self?.dismissAllPresentedNavigationControllers(true, completionInBackground: false) {
              DPAGApplicationFacadeUIBase.containerVC.showTopMainViewController(DPAGSimsMeController.sharedInstance.chatsListViewController, addViewController: nil) {
                DPAGSimsMeController.sharedInstance.chatsListViewController.tableView.scrollRectToVisible(.zero, animated: true)
                DPAGProgressHUD.sharedInstance.hide(true)
              }
            }
          }
        }
        return
      }
    } else if self.pushToChatEnabled, let senderGuid = senderGuid {
      self.pushToChatEnabled = false
      // Private message
      if let channel = DPAGApplicationFacade.cache.channel(for: senderGuid), channel.isSubscribed {
        DPAGProgressHUD.sharedInstance.show(true) { [weak self] _ in
          self?.dismissAllPresentedNavigationControllers(true, completionInBackground: true) { [weak self] in
            Thread.sleep(forTimeInterval: 1)
            DPAGChatHelper.openChatStreamView(senderGuid, navigationController: self?.chatsListViewController.navigationController, startChatWithUnconfirmedContact: true, showMessage: dictionary?["messageGuid"] as? String, draftText: nil) { _ in
              DPAGProgressHUD.sharedInstance.hide(true)
            }
          }
        }
      }
      return
    }
  }
  
  public func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
    DPAGLog("didFailToRegisterForRemoteNotificationsWithError: ")
    DPAGLog(error.localizedDescription)
    let deviceToken = DPAGStrings.Notification.Push.TOKEN_FAILED.rawValue
    self.checkTokenAndUpdate(deviceToken)
    self.notificationDelegate?.didFailToRegisterForRemoteNotifications(error)
    self.notificationDelegate = nil
  }
  
  func askForPushPreview() {
    if DPAGApplicationFacade.preferences.didAskForPushPreview == false,
       DPAGApplicationFacade.preferences.previewPushNotification == false, (DPAGApplicationFacade.cache.account?.accountState ?? .unknown) == .confirmed {
      let title = "settings.pushpreview.askafterinstall"
      let message = "settings.pushpreview.askafterinstall.hint"
      DPAGApplicationFacade.preferences.didAskForPushPreview = true
      let actionLater = UIAlertAction(titleIdentifier: "settings.pushpreview.askafterinstall.later", style: .cancel, handler: { _ in })
      let actionNow = UIAlertAction(titleIdentifier: "settings.pushpreview.askafterinstall.now", style: .default, handler: { _ in
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
          let responseBlock: DPAGServiceResponseBlock = { _, _, errorMessage in
            DPAGProgressHUD.sharedInstance.hide(true) {
              if let errorMessage = errorMessage {
                AppConfig.appWindow()??.rootViewController?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
              } else {
                DPAGApplicationFacade.preferences.previewPushNotification = true
              }
            }
          }
          DPAGNotificationWorker.setPreviewPushNotificationEnabled(true, withResponse: responseBlock)
        }
      })
      AppConfig.appWindow()??.rootViewController?.presentAlert(
        alertConfig: UIViewController.AlertConfig(
          titleIdentifier: title,
          messageIdentifier: message,
          cancelButtonAction: actionLater,
          otherButtonActions: [actionNow]
        )
      )
    }
  }
  
  public func didRegisterForRemoteNotificationsWithDeviceToken(_ data: Data) {
    let deviceToken = data.hexEncodedString()
    DPAGLog("didRegisterForRemoteNotification: \(data), %@", deviceToken)
    self.checkTokenAndUpdate(deviceToken)
    self.notificationDelegate?.didRegisterForRemoteNotifications()
    self.notificationDelegate = nil
    self.askForPushPreview()
  }
  
  public func logIn() {
    self.isWaitingForLogin = true
    DPAGApplicationFacadeUIBase.loginVC.loginRequest(withTouchID: true) {}
  }
  
  public func deleteCachedData() {
    DPAGLog("deleteCachedData")
    DPAGApplicationFacade.cache.clearCache()
    CryptoHelper.sharedInstance?.resetCryptoHelper()
    DPAGHelperEx.clearTempFolder()
  }
  
  private func setupIPad() {
    let navVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: DPAGApplicationFacadeUIRegistration.introVC())
    navVC.modalPresentationStyle = .custom
    navVC.transitioningDelegateZooming = DPAGApplicationFacadeUIBase.defaultAnimatedTransitioningDelegate()
    navVC.transitioningDelegate = navVC.transitioningDelegateZooming
    DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.modalPresentationStyle = .custom
    DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.present(navVC, animated: true, completion: nil)
    
  }
  public func setup() {
    let blockIntro = {
      DPAGApplicationFacade.cache.initFetchedResultsController()
      if UIDevice.current.userInterfaceIdiom == .pad {
        guard let windowRef = AppConfig.appWindow(), let window = windowRef else { return }
        (window.rootViewController as? DPAGRootContainerViewControllerProtocol)?.rootViewController = DPAGApplicationFacadeUIBase.containerVC
        self.setupIPad()
      } else {
        DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController.setViewControllers([DPAGApplicationFacadeUIRegistration.introVC()], animated: false)
        self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.containerVC.mainNavigationController)
      }
    }
    // !!! DO NOT USE CACHE !!!
    let accountStateSetup = DPAGApplicationFacade.accountManager.accountStateSetup()
    guard accountStateSetup != .unknown else {
      DPAGLog("setup with no account")
      blockIntro()
      return
    }
    guard DPAGApplicationFacade.accountManager.isFirstRunOrBrokenSetup() == false else {
      DPAGLog("setup with isFirstRun true")
      blockIntro()
      return
    }
    if accountStateSetup == .recoverBackup {
      let introViewController = DPAGApplicationFacadeUIRegistration.introVC()
      DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([introViewController], animated: false)
      self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.containerVC.mainNavigationController)
      self.resetApplication(nil)
    } else if accountStateSetup == .waitForConfirm {
      let confirmAccountViewController = DPAGApplicationFacadeUIRegistration.confirmAccountVC()
      DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.setViewControllers([confirmAccountViewController], animated: false)
      if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
        DPAGApplicationFacade.model.setupDeviceData()
        DPAGApplicationFacade.model.update(with: nil)
        DPAGApplicationFacade.cache.initFetchedResultsController()
        self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.containerVC.mainNavigationController)
      } else {
        self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.loginVC)
        self.isWaitingForLogin = true
      }
    } else {
      if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
        CryptoHelper.sharedInstance?.deleteDecryptedPrivateKeyinKeyChain()
      }
      if DPAGApplicationFacade.preferences.touchIDEnabled == false {
        CryptoHelper.sharedInstance?.deleteDecryptedPrivateKeyForTouchID()
      }
      if DPAGApplicationFacade.preferences.lockApplicationImmediately == false, DPAGApplicationFacade.preferences.passwordOnStartEnabled == false, CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
        self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.containerVC.mainNavigationController)
        NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DID_COMPLETE_LOGIN, object: nil)
        self.didHideLoginView()
      } else {
        DPAGLog("2-Requesting login (password entry) because...")
        if DPAGApplicationFacade.preferences.lockApplicationImmediately {
          DPAGLog("2-.... lockApplicationImmediately")
        }
        if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
          DPAGLog("2-.... paswordOnStartEnabled")
        }
        if CryptoHelper.sharedInstance == nil {
          DPAGLog("2-.... no CryptoHelper.sharedInstance")
        }
        if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
          DPAGLog("2-.... isPrivateKeyDecrypted == false")
        }
        DPAGApplicationFacade.preferences.resetLockApplicationImmediately()
        self.showSplash(destinationViewController: DPAGApplicationFacadeUIBase.loginVC)
        CryptoHelper.sharedInstance?.resetCryptoHelper()
        self.isWaitingForLogin = true
      }
    }
  }
  
  fileprivate func checkTokenAndUpdate(_ deviceToken: String) {
    if CryptoHelper.sharedInstance?.isPrivateKeyDecrypted() ?? false {
      let knownToken = DPAGApplicationFacade.preferences.deviceToken
      let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
      let apnIdentifierKnown = DPAGApplicationFacade.preferences.apnIdentifier
      let apnIdentifierDevice = DPAGApplicationFacade.preferences.apnIdentifierWithBundleIdentifier(bundleIdentifier ?? "SIMSme", deviceToken: deviceToken)
      let isFirstRunAfterUpdate = self.isFirstRunAfterUpdate()
      if isFirstRunAfterUpdate || knownToken != deviceToken || knownToken == deviceToken || apnIdentifierKnown != apnIdentifierDevice || DPAGApplicationFacade.preferences.needsDeviceTokenSynchronization() {
        do {
          try DPAGApplicationFacade.accountManager.ensureAccountProfilKey()
        } catch {
          DPAGLog(error)
        }
        DPAGApplicationFacade.preferences.deviceToken = deviceToken
        DPAGApplicationFacade.preferences.apnIdentifier = apnIdentifierDevice
        self.performBlockInBackground {
          if isFirstRunAfterUpdate, DPAGApplicationFacade.preferences.isShareExtensionEnabled == false {
            do {
              try DPAGApplicationFacade.devicesWorker.createShareExtensionDevice(withResponse: nil)
            } catch {
              DPAGLog(error)
            }
          }
          do {
            try DPAGApplicationFacade.requestWorker.setDeviceData()
            DPAGLog("IMDAT::: checkTokenAndUpdate:: deviceToken = \(deviceToken), ==> success")
          } catch {
            DPAGLog(error)
          }
        }
      }
    }
  }
  
  @objc
  func appDidBecomeActive() {
    DPAGApplicationFacade.cache.reinitCaches()
  }
  
  @objc
  func appDidEnterBackground(_: Any?) {
    self.pushNotificationUserInfo = nil
    self.pushToChatEnabled = true
    self.executingFirstRunAfterUpdate = false
  }
  
  fileprivate func showSplash(destinationViewController: UIViewController) {
    guard let windowRef = AppConfig.appWindow(), let window = windowRef else { return }
    if destinationViewController == DPAGApplicationFacadeUIBase.loginVC {
      DPAGApplicationFacadeUIBase.loginVC.loginRequest(withTouchID: true) {
        (window.rootViewController as? DPAGRootContainerViewControllerProtocol)?.rootViewController = DPAGApplicationFacadeUIBase.containerVC
      }
    } else {
      UIView.transition(with: window, duration: TimeInterval(UINavigationController.hideShowBarDuration), options: .transitionCrossDissolve, animations: {
        let oldState = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        (window.rootViewController as? DPAGRootContainerViewControllerProtocol)?.rootViewController = DPAGApplicationFacadeUIBase.containerVC
        UIView.setAnimationsEnabled(oldState)
      }, completion: { _ in
      })
    }
    self.handleSplashStart()
  }
  
  func registerRemotePushNotifications(_ delegate: DPAGRegisterNotificationDelegate) {
    if AppConfig.isSimulator {
      return
    } else {
      DPAGLog("registerRemotePushNotifications: ")
      NSLog("registerRemotePushNotifications: ")
      self.notificationDelegate = delegate
      let center = UNUserNotificationCenter.current()
      center.delegate = nil
      center.requestAuthorization(options: [.sound, .alert, .badge]) { [weak self] _, error in
        if error == nil {
          self?.performBlockOnMainThread {
            AppConfig.registerForRemoteNotifications()
          }
        }
      }
      if AppConfig.isRegisteredForRemoteNotifications() {
        DPAGLog("isRegisteredForRemoteNotifications returns true: ")
      }
    }
  }
  
  func syncConfigVersions() {
    if DPAGApplicationFacade.preferences.needsConfigSynchronization(), !self.isSyncConfigVersionsRunning {
      self.isSyncConfigVersionsRunning = true
      DPAGApplicationFacade.requestWorker.getConfigVersions { [weak self] responseObject, errorCode, errorMessage in
        guard errorMessage == nil else {
          if errorCode == "service.sslError" {
            self?.performBlockOnMainThread {
              (AppConfig.appWindow()??.rootViewController)?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: "service.sslError"))
            }
          }
          self?.isSyncConfigVersionsRunning = false
          return
        }
        let cacheVersions = DPAGSimsMeControllerCacheVersions.parseServerResponse(responseObject)
        let isCompanyManaged = DPAGApplicationFacade.cache.account?.companyPublicKey != nil
        let updateCount = (cacheVersions.updateServerConfig ? 1 : 0) + (cacheVersions.updateMandanten ? 1 : 0) + (cacheVersions.updateChannels ? 1 : 0) + (cacheVersions.updateServices ? 1 : 0) + (cacheVersions.updateCompanyLayout && isCompanyManaged ? 1 : 0) + (cacheVersions.updateCompanyMDMConfig && isCompanyManaged ? 1 : 0) + (cacheVersions.updateBlocked ? 1 : 0) + (cacheVersions.updatePrivateIndex ? 1 : 0) + (cacheVersions.updateConfirmedIdentities ? 1 : 0) + (cacheVersions.updateCompanyIndex && isCompanyManaged ? 1 : 0)
        
        DPAGApplicationFacade.preferences[.kLastConfigSynchronizationCounter] = updateCount
        if updateCount == 0 {
          DPAGApplicationFacade.preferences.updateLastConfigSynchronization()
        }
        if cacheVersions.updateServerConfig {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.requestWorker.getConfiguration { responseObject, _, errorMessage in
            guard errorMessage == nil, let responseDict = responseObject as? [AnyHashable: Any] else { return }
            DPAGApplicationFacade.preferences.serverConfiguration = responseDict
            DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(DPAGPreferences.PropString.kCacheVersionServerConfig, cacheVersionServer: cacheVersions.cacheVersionServerConfigServer)
          }
        }
        if cacheVersions.updateMandanten {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.requestWorker.getMandanten { responseObject, _, errorMessage in
            guard errorMessage == nil, let responseArray = responseObject as? [[AnyHashable: Any]] else { return }
            var mandanten: [DPAGMandant] = []
            for responseItemDict in responseArray {
              if let dictMandant = responseItemDict["Mandant"] as? [AnyHashable: Any] {
                if let mandant = DPAGMandant(dict: dictMandant) {
                  mandanten.append(mandant)
                }
              }
            }
            DPAGApplicationFacade.preferences.mandanten = mandanten
            DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionMandanten, cacheVersionServer: cacheVersions.cacheVersionMandantenServer)
          }
        }
        if cacheVersions.updateChannels {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.feedWorker.updatedFeedListWithFeedsToUpdate(forFeedType: .channel) { _, channelGuidsToUpdate, errorMessage in
            guard errorMessage == nil else { return }
            if channelGuidsToUpdate.count > 0 {
              DPAGApplicationFacade.feedWorker.updateFeeds(feedGuids: channelGuidsToUpdate, feedType: .channel) { _, _, errorMessage in
                if errorMessage == nil {
                  DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionChannels, cacheVersionServer: cacheVersions.cacheVersionChannelsServer)
                }
              }
            } else {
              DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionChannels, cacheVersionServer: cacheVersions.cacheVersionChannelsServer)
            }
          }
        }
        //                if cacheVersions.updateServices {
        //                    Thread.sleep(forTimeInterval: 1)
        //                    DPAGApplicationFacade.feedWorker.updatedFeedListWithFeedsToUpdate(forFeedType: .service) { _, serviceGuidsToUpdate, errorMessage in
        //                        guard errorMessage == nil else { return }
        //                        if serviceGuidsToUpdate.count > 0 {
        //                            DPAGApplicationFacade.feedWorker.updateFeeds(feedGuids: serviceGuidsToUpdate, feedType: .service) { _, _, errorMessage in
        //                                if errorMessage == nil {
        //                                    DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionServices, cacheVersionServer: cacheVersions.cacheVersionServicesServer)
        //                                }
        //                            }
        //                        } else {
        //                            DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionServices, cacheVersionServer: cacheVersions.cacheVersionServicesServer)
        //                        }
        //                    }
        //                }
        if cacheVersions.updateCompanyLayout, isCompanyManaged {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.requestWorker.getCompanyLayout { responseObject, _, errorMessage in
            if errorMessage == nil, let responseDict = responseObject as? [AnyHashable: Any] {
              guard let dict = responseDict["CompanyLayout"] as? [AnyHashable: Any] else { return }
              DPAGApplicationFacade.preferences.setCompanyLayout(dict)
              self?.performBlockOnMainThread {
                self?.updateLayoutColors()
                NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_COLORS_UPDATED, object: nil)
              }
              guard let logoDict = responseDict["CompanyLogo"] as? [AnyHashable: Any] else { return }
              guard let checksumLogo = logoDict["checksum"] as? String else {
                if DPAGApplicationFacade.preferences.removeCompanyLogo() {
                  NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_LOGO_UPDATED, object: nil)
                }
                DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionCompanyLayout, cacheVersionServer: cacheVersions.cacheVersionCompanyLayoutServer)
                return
              }
              if checksumLogo != DPAGApplicationFacade.preferences.companyLogoChecksum() {
                DPAGApplicationFacade.requestWorker.getCompanyLogo { responseObject, _, errorMessage in
                  if errorMessage == nil, let responseDict = responseObject as? [AnyHashable: Any] {
                    guard let dict = responseDict["CompanyLogo"] as? [AnyHashable: Any], let data = dict["data"] as? String else { return }
                    DPAGApplicationFacade.preferences.setCompanyLogo(data, checksum: checksumLogo)
                    DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionCompanyLayout, cacheVersionServer: cacheVersions.cacheVersionCompanyLayoutServer)
                    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.DESIGN_LOGO_UPDATED, object: nil)
                  }
                }
              } else {
                DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionCompanyLayout, cacheVersionServer: cacheVersions.cacheVersionCompanyLayoutServer)
              }
            }
          }
        }
        if cacheVersions.updateCompanyMDMConfig, isCompanyManaged {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.requestWorker.getCompanyConfig { responseObject, _, errorMessage in
            if errorMessage == nil, let responseDict = responseObject as? [AnyHashable: Any], let dict = responseDict["CompanyMdmConfig"] as? [AnyHashable: Any], let encryptedConfig = dict["data"] as? String, let iv = dict["iv"] as? String {
              if let account = DPAGApplicationFacade.cache.account {
                do {
                  if try DPAGApplicationFacade.preferences.setCompanyConfig(encryptedConfig, iv: iv, companyAesKey: account.aesKeyCompany) {
                    DPAGApplicationFacade.preferences.cacheVersionTaskCompleted(.kCacheVersionCompanyMDMConfig, cacheVersionServer: cacheVersions.cacheVersionCompanyMDMConfigServer)
                  }
                } catch {
                  DPAGLog(error)
                }
              }
            }
          }
        }
        if cacheVersions.updateBlocked {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.contactsWorker.updateBlockedWithServer(cacheVersionGetBlockedServer: cacheVersions.cacheVersionGetBlockedServer)
        }
        if cacheVersions.updatePrivateIndex {
          Thread.sleep(forTimeInterval: 1)
          do {
            try DPAGApplicationFacade.contactsWorker.updatePrivateIndexWithServer(cacheVersionPrivateIndexServer: cacheVersions.cacheVersionPrivateIndexServer)
          } catch {
            DPAGLog(error)
          }
        }
        if cacheVersions.updateConfirmedIdentities {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.accountManager.updateConfirmedIdentitiesWithServer(cacheVersionConfirmedIdentitiesServer: cacheVersions.cacheVersionConfirmedIdentitiesServer)
        }
        if cacheVersions.updateCompanyIndex, isCompanyManaged {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.companyAdressbook.updateCompanyIndexWithServer(cacheVersionCompanyIndexServer: cacheVersions.cacheVersionCompanyIndexServer)
        }
        if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), (contact.eMailDomain?.isEmpty ?? true) == false {
          if DPAGApplicationFacade.preferences.needsDomainIndexSynchronisation() {
            Thread.sleep(forTimeInterval: 1)
            DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
          }
        }
        self?.isSyncConfigVersionsRunning = false
      }
    } else {
      self.isSyncConfigVersionsRunning = true
      if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), (contact.eMailDomain?.isEmpty ?? true) == false {
        if DPAGApplicationFacade.preferences.needsDomainIndexSynchronisation() {
          Thread.sleep(forTimeInterval: 1)
          DPAGApplicationFacade.companyAdressbook.updateDomainIndexWithServer()
        }
      }
      self.isSyncConfigVersionsRunning = false
    }
  }
  
  @objc
  public func performTasksOnAppStart() {
    self.performBlockInBackground {
      if let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid) {
        if contact.accountID == nil {
          DPAGApplicationFacade.accountManager.updateAccountID(accountGuid: account.guid)
        }
        if DPAGApplicationFacade.preferences.isBackupDisabled, DPAGApplicationFacade.preferences.backupLastFile != nil, let ownAccountId = contact.accountID {
          do {
            try DPAGApplicationFacade.backupWorker.deleteBackups(accountID: ownAccountId)
          } catch {
            DPAGLog(error)
          }
          DPAGApplicationFacade.preferences.backupLastFile = nil
        }
        if account.companyPublicKey != nil, account.aesKeyCompanyUserData == nil {
          DPAGApplicationFacade.profileWorker.getCompanyInfo(withResponse: nil)
        }
        if DPAGApplicationFacade.preferences.simsmePublicKey == nil {
          DPAGApplicationFacade.preferences.createSimsmeRecoveryInfos()
        } else {
          do {
            try DPAGApplicationFacade.preferences.ensureRecoveryBlobs()
          } catch {
            DPAGLog(error)
          }
        }
        if !DPAGApplicationFacade.preferences.didSetDeviceName, let ownGuid = DPAGApplicationFacade.model.ownDeviceGuid {
          DPAGApplicationFacade.devicesWorker.renameDevice(ownGuid, newName: UIDevice.current.name) { _, _, errorMessage in
            if errorMessage == nil {
              DPAGApplicationFacade.preferences.didSetDeviceName = true
            }
          }
        }
        if DPAGApplicationFacade.preferences.needsBackgroundAccessTokenSynchronization {
          self.performBlockOnMainThread { [weak self] in
            self?.createBackgroundAccessToken()
          }
        }
      }
      self.syncConfigVersions()
      let blockPurchase = {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), (contact.nickName?.isEmpty ?? true) == false else { return }
        if DPAGApplicationFacade.preferences.isBaMandant == false {
          return
        }
        let responseBlock: DPAGServiceResponseBlock = { [weak self] responseObject, _, errorMessage in
          if (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
            return
          }
          if errorMessage != nil {
            return
          }
          if let responseDict = (responseObject as? [[String: Any]])?.first,
             let ident = responseDict["ident"] as? String,
             ident == "usage" {
            let valid = responseDict["valid"]
            if valid == nil || valid is NSNull || (valid is String && ((valid as? String)?.isEmpty ?? true)) {
              return
            }
            if let validString = valid as? String, let dateValid = DPAGFormatter.dateServer.date(from: validString) {
              let dateDistance = Date().distanceInDays(to: dateValid)
              DPAGApplicationFacade.preferences.setLicenseValidDate(validString)
              if dateDistance > 6 {
                return
              }
              if dateDistance >= 0 {
                self?.performBlockOnMainThread {
                  let actionExtend = UIAlertAction(titleIdentifier: "business.alert.usage_soon_expired.btnExtend.title", style: .default, handler: { _ in
                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
                      if let vcConsumer = vc as? DPAGLicencesInitConsumer {
                        vcConsumer.setDateValid(dateValid)
                      }
                      let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                      AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                    }
                  })
                  AppConfig.appWindow()??.rootViewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.usage_soon_expired.title", messageIdentifier: "business.alert.usage_soon_expired.message", cancelButtonAction: .cancelDefault, otherButtonActions: [actionExtend]))
                }
                return
              }
            }
          }
          self?.performBlockOnMainThread {
            let actionExtend = UIAlertAction(titleIdentifier: "business.alert.usage_expired.btnExtend.title", style: .default, handler: { _ in
              if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
                if let vcConsumer = vc as? DPAGLicencesInitConsumer {
                  vcConsumer.setDateValid(Date.distantPast)
                }
                let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
              }
            })
            AppConfig.appWindow()??.rootViewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.usage_expired.title", messageIdentifier: "business.alert.usage_expired.message", otherButtonActions: [actionExtend]))
          }
        }
        DPAGPurchaseWorker.getPurchasedProductsWithResponse(responseBlock)
      }
      
      if DPAGApplicationFacade.preferences.isBaMandant {
        guard let account = DPAGApplicationFacade.cache.account, let contact = DPAGApplicationFacade.cache.contact(for: account.guid), (contact.nickName?.isEmpty ?? true) == false else { return }
        let responseBlock: (String?, String?, String?, Bool, DPAGAccountCompanyManagedState) -> Void = { [weak self] _, errorMessage, companyName, _, accountStateManaged in
          if errorMessage != nil || (CryptoHelper.sharedInstance?.isPrivateKeyInMemory() ?? false) == false {
            blockPurchase()
          } else {
            switch accountStateManaged {
              case .requested:
                self?.performBlockOnMainThread { [weak self] in
                  self?.requestAccountManagement(forCompany: companyName, completion: {
                    self?.performBlockInBackground {
                      do {
                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                      } catch {
                        DPAGLog(error)
                      }
                      blockPurchase()
                    }
                  })
                }
              case .accepted:
                self?.performBlockInBackground {
                  if let account = DPAGApplicationFacade.cache.account {
                    if account.aesKeyCompany == nil {
                      DPAGApplicationFacade.requestWorker.requestEncryptionInfo(withResponse: { _, _, _ in })
                    }
                  }
                  do {
                    try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                  } catch {
                    DPAGLog(error)
                  }
                  DPAGApplicationFacade.preferences.isCompanyManagedState = true
                  blockPurchase()
                }
              case .acceptedEmailRequired:
                DPAGApplicationFacade.preferences.isCompanyManagedState = true
                if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                  (vc as? DPAGViewControllerWithCompletion)?.completion = {
                    self?.performBlockInBackground {
                      do {
                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                      } catch {
                        DPAGLog(error)
                      }
                      blockPurchase()
                    }
                  }
                  let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                  AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                }
              case .acceptedEmailFailed:
                DPAGApplicationFacade.preferences.isCompanyManagedState = true
                if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                  (vc as? DPAGCompanyProfilConfirmEMailControllerSkipDelegate)?.skipToEmailValidation = true
                  (vc as? DPAGViewControllerWithCompletion)?.completion = {
                    self?.performBlockInBackground {
                      do {
                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                      } catch {
                        DPAGLog(error)
                      }
                      blockPurchase()
                    }
                  }
                  let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                  AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                }
              case .acceptedPhoneRequired:
                DPAGApplicationFacade.preferences.isCompanyManagedState = true
                // TODO: Move this to main Thread
                self?.performBlockOnMainThread {
                  if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                    (vc as? DPAGViewControllerWithCompletion)?.completion = {
                      self?.performBlockInBackground {
                        do {
                          try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                        } catch {
                          DPAGLog(error)
                        }
                        blockPurchase()
                      }
                    }
                    let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                    AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                  }
                }
              case .acceptedPhoneFailed:
                DPAGApplicationFacade.preferences.isCompanyManagedState = true
                if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                  (vc as? DPAGCompanyProfilConfirmPhoneNumberControllerSkipDelegate)?.skipToPhoneNumberValidation = true
                  (vc as? DPAGViewControllerWithCompletion)?.completion = {
                    self?.performBlockInBackground {
                      do {
                        try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                      } catch {
                        DPAGLog(error)
                      }
                      blockPurchase()
                    }
                  }
                  let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                  AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                }
              case .declined, .unknown, .accountDeleted, .acceptedPendingValidation:
                self?.performBlockInBackground {
                  blockPurchase()
                }
            }
          }
        }
        DPAGApplicationFacade.companyAdressbook.checkCompanyManagement(withResponse: responseBlock)
      } else {
        blockPurchase()
      }
      self.updateTestLicenseDate()
    }
    NotificationCenter.default.post(name: DPAGStrings.Notification.Application.UI_IS_READY_WITH_PRIVATE_KEY, object: nil)
  }
  
  func createBackgroundAccessToken() {
    DPAGLog("createBackgroundAccessToken: ")
    self.performBlockInBackground {
      let responseBlock: DPAGServiceResponseBlock = { responseObject, _, errorMessage in
        if let errorMessage = errorMessage {
          DPAGLog(errorMessage)
        } else {
          if let response = responseObject as? [String] {
            if let backgroundToken = response.first {
              DPAGApplicationFacade.preferences.backgroundAccessToken = backgroundToken
            }
          }
        }
      }
      DPAGApplicationFacade.requestWorker.createBackgroundAccessToken(withResponse: responseBlock)
    }
  }
  
  func requestAccountManagement(forCompany companyName: String?, completion: @escaping () -> Void) {
    if AppConfig.appWindow()??.rootViewController?.presentedViewController == nil {
      let message = DPAGLocalizedString("business.alert.accountManagementRequested.message")
      let actionDecline = UIAlertAction(titleIdentifier: "business.alert.accountManagementRequested.btnDecline.title", style: .cancel, handler: { _ in
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
          let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
            if let errorMessage = errorMessage {
              DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                guard self != nil else { return }
                (AppConfig.appWindow()??.rootViewController)?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                completion()
              }
              return
            }
            guard self != nil else { return }
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
              guard self != nil else { return }
              completion()
            }
          }
          DPAGApplicationFacade.companyAdressbook.declineCompanyManagement(withResponse: responseBlock)
        }
      })
      let actionAccept = UIAlertAction(titleIdentifier: "business.alert.accountManagementRequested.btnAccept.title", style: .default, handler: { _ in
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
          let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
            if let errorMessage = errorMessage {
              DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                guard self != nil else { return }
                (AppConfig.appWindow()??.rootViewController)?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                completion()
              }
              return
            }
            guard self != nil else { return }
            let accountStateManaged: DPAGAccountCompanyManagedState = DPAGApplicationFacade.cache.account?.companyManagedState ?? .unknown
            switch accountStateManaged {
              case .accepted, .acceptedEmailFailed, .acceptedPhoneFailed, .acceptedEmailRequired, .acceptedPhoneRequired, .acceptedPendingValidation:
                DPAGApplicationFacade.preferences.isCompanyManagedState = true
                DPAGApplicationFacade.profileWorker.getCompanyInfo(withResponse: nil)
              case .accountDeleted, .declined, .requested, .unknown:
                break
            }
            NotificationCenter.default.post(name: DPAGStrings.Notification.Account.CONFIRMED_IDENTITIES_CHANGED, object: nil)
            DPAGApplicationFacade.preferences.setTestLicenseDaysLeft("0")
            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
              guard self != nil else { return }
              switch accountStateManaged {
                case .acceptedEmailRequired:
                  if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                    (vc as? DPAGViewControllerWithCompletion)?.completion = completion
                    let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                    AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                  }
                case .acceptedPhoneRequired:
                  if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                    (vc as? DPAGViewControllerWithCompletion)?.completion = completion
                    let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
                    AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
                  }
                case .accepted:
                  self?.syncHelper = DPAGSynchronizationHelperAddressbook()
                  self?.syncHelper?.syncDomainAndCompanyAddressbook(completion: { [weak self] in
                    self?.syncHelper = nil
                    completion()
                  }, completionOnError: { [weak self] (_: String?, errorMessage: String) in
                    self?.syncHelper = nil
                    (AppConfig.appWindow()??.rootViewController)?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                    completion()
                  })
                default:
                  completion()
              }
            }
          }
          DPAGApplicationFacade.companyAdressbook.acceptCompanyManagement(withResponse: responseBlock)
        }
      })
      AppConfig.appWindow()??.rootViewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.accountManagementRequested.title", messageIdentifier: String(format: message, companyName ?? "??"), otherButtonActions: [actionDecline, actionAccept]))
    } else {
      completion()
    }
  }
  
  @objc
  private func updateTestLicenseDate() {
    if DPAGApplicationFacade.preferences.isBaMandant {
      DPAGApplicationFacade.requestWorker.getTestVoucherInfo { responseObject, _, _ in
        if let daysLeft = (responseObject as? [AnyHashable: Any])?["daysLeft"] as? String {
          DPAGApplicationFacade.preferences.setTestLicenseDaysLeft(daysLeft)
        }
      }
    }
  }
  
  func showPurchaseIfPossible() {
    if AppConfig.appWindow()??.rootViewController?.presentedViewController == nil {
      self.performBlockOnMainThread {
        let actionExtend = UIAlertAction(titleIdentifier: "business.alert.usage_expired.btnExtend.title", style: .default, handler: { _ in
          if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagLicenseInitViewController) {
            if let vcConsumer = vc as? DPAGLicencesInitConsumer {
              vcConsumer.setDateValid(Date.distantPast)
            }
            let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
            AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
          }
        })
        AppConfig.appWindow()??.rootViewController?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.usage_expired.title", messageIdentifier: "business.alert.usage_expired.message", otherButtonActions: [actionExtend]))
      }
    }
  }
  
  @objc
  private func cleanUpPrimaryData() {
    self.performBlockInBackground {
      DPAGAttachmentWorker.cleanUpPrimaryData()
    }
  }
  
  // MARK: - Splash delegate
  
  private func handleSplashStart() {
    let isFirstRun = DPAGApplicationFacade.accountManager.isFirstRunOrBrokenSetup()
    if isFirstRun {
      AppConfig.setApplicationIconBadgeNumber(0)
      DPAGApplicationFacade.preferences.setDefaults()
      DPAGApplicationFacade.accountManager.resetDatabase()
    }
  }
  
  func canShowStatusBarNotification() -> Bool {
    AppConfig.applicationState() == .active && self.isWaitingForLogin == false && (DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.topViewController is DPAGWelcomeViewControllerProtocol) == false && (DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.topViewController is DPAGConfirmAccountViewControllerProtocol) == false
  }
  
  func isFirstRunAfterUpdate() -> Bool {
    if self.executingFirstRunAfterUpdate == nil {
      self.executingFirstRunAfterUpdate = DPAGApplicationFacade.preferences.isFirstRunAfterUpdate()
    }
    return self.executingFirstRunAfterUpdate ?? false
  }
  
  @objc
  private func didHideLoginView() {
    if let startViewControllerChatsList = self.startViewController() as? DPAGChatsListViewControllerProtocol, let viewControllerMainFirst = DPAGApplicationFacadeUIBase.containerVC.mainNavigationController.viewControllers.first, startViewControllerChatsList === self.chatsListViewController, self.chatsListViewController == viewControllerMainFirst, let pushNotificationUserInfo = self.pushNotificationUserInfo {
      self.handleUserInfo(pushNotificationUserInfo, forApplication: AppConfig.currentApplication(), wasInState: AppConfig.applicationState())
    }
  }
  
  public func checkForPush() {
    if let pushNotificationUserInfo = self.pushNotificationUserInfo {
      self.handleUserInfo(pushNotificationUserInfo, forApplication: AppConfig.currentApplication(), wasInState: AppConfig.applicationState())
    }
  }
}
