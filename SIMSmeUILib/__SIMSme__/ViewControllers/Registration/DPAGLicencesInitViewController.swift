//
//  DPAGLicencesInitViewController.swift
// ginlo
//
//  Created by RBU on 20/06/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import StoreKit
import UIKit

private class DPAGPurchaseHelper: NSObject {
    static let sharedInstance: DPAGPurchaseHelper = DPAGPurchaseHelper()

    private var productRequest: SKProductsRequest?
    private weak var productRequestDelegate: SKProductsRequestDelegate?

    func startProductsRequest(productIdentifiers: Set<String>, productRequestDelegate: SKProductsRequestDelegate?) {
        self.productRequest?.cancel()
        self.productRequest = nil
        self.productRequestDelegate = productRequestDelegate
        self.productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        self.productRequest?.delegate = self
        self.productRequest?.start()
    }
}

extension DPAGPurchaseHelper: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.productRequestDelegate?.productsRequest(request, didReceive: response)
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.productRequestDelegate?.request?(request, didFailWithError: error)
    }

    func requestDidFinish(_ request: SKRequest) {
        self.productRequestDelegate?.requestDidFinish?(request)
    }
}

protocol DPAGLicenceViewControllerProtocol: AnyObject {
    func checkLicence()
    func checkCompanyManagement()
    func showAcceptedRequiredViewController(_ vc: UIViewController)
    func checkedLicenceWithEarlierDate()
    func checkedLicenceWithNoDate()
    func showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError)
    func presentAlert(alertConfig: UIViewController.AlertConfig) -> UIAlertController
}

extension DPAGLicenceViewControllerProtocol {
    func checkCompanyManagement() {
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(false) { _ in
            let responseBlock: (String?, String?, String?, Bool, DPAGAccountCompanyManagedState) -> Void = { [weak self] _, errorMessage, companyName, _, accountStateManaged in
                if errorMessage != nil {
                    DPAGProgressHUD.sharedInstance.hide(false)
                } else {
                    switch accountStateManaged {
                    case .requested:
                        DispatchQueue.main.async { [weak self] in
                            self?.requestAccountManagement(forCompany: companyName, completion: { [weak self] in
                                do {
                                    try DPAGApplicationFacade.accountManager.ensureCompanyRecoveryPassword()
                                } catch {
                                    DPAGLog(error)
                                }
                                self?.checkLicence()
                            })
                        }
                    case .accepted, .acceptedEmailRequired, .acceptedEmailFailed, .acceptedPhoneRequired, .acceptedPhoneFailed, .declined, .acceptedPendingValidation, .accountDeleted, .unknown:
                        DPAGProgressHUD.sharedInstance.hide(false)
                    }
                }
            }
            DPAGApplicationFacade.companyAdressbook.checkCompanyManagement(withResponse: responseBlock)
        }
    }

    private func requestAccountManagement(forCompany companyName: String?, completion: @escaping () -> Void) {
        if AppConfig.appWindow()??.rootViewController?.presentedViewController == nil {
            DPAGProgressHUD.sharedInstance.hide(false, completion: { [weak self] in
                let message = DPAGLocalizedString("business.alert.accountManagementRequested.message")
                let actionDecline = UIAlertAction(titleIdentifier: "business.alert.accountManagementRequested.btnDecline.title", style: .cancel, handler: { _ in
                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                        let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                guard self != nil else { return }
                                if let errorMessage = errorMessage {
                                    self?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
                                }
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
                                    self?.showErrorAlertCheck(alertConfig: UIViewController.AlertConfigError(messageIdentifier: errorMessage))
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
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                guard self != nil else { return }
                                switch accountStateManaged {
                                case .acceptedEmailRequired:
                                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitEMailController) {
                                        (vc as? DPAGViewControllerWithCompletion)?.completion = completion
                                        self?.showAcceptedRequiredViewController(vc)
                                    }
                                case .acceptedPhoneRequired:
                                    if let vc = DPAGApplicationFacade.preferences.viewControllerForIdent(DPAGWhiteLabelNextView.dpagProfileViewController_startCompanyProfilInitPhoneNumberController) {
                                        (vc as? DPAGViewControllerWithCompletion)?.completion = completion
                                        self?.showAcceptedRequiredViewController(vc)
                                    }
                                default:
                                    completion()
                                }
                            }
                        }
                        DPAGApplicationFacade.companyAdressbook.acceptCompanyManagement(withResponse: responseBlock)
                    }
                })
                _ = self?.presentAlert(alertConfig: UIViewController.AlertConfig(titleIdentifier: "business.alert.accountManagementRequested.title", messageIdentifier: String(format: message, companyName ?? "??"), otherButtonActions: [actionDecline, actionAccept]))
            })
        } else {
            DPAGProgressHUD.sharedInstance.hide(false, completion: completion)
        }
    }

    func checkLicence() {
        DPAGPurchaseWorker.getPurchasedProductsWithResponse { [weak self] responseObject, _, errorMessage in
            guard let strongSelf = self else { return }
            if errorMessage == nil, let responseArray = responseObject as? [[String: Any]], responseArray.isEmpty == false, let responseDict = responseArray.first, let ident = responseDict["ident"] as? String, ident == "usage" {
                if let valid = responseDict["valid"] as? String, let dateValid = DPAGFormatter.date.date(from: valid), dateValid.isEarlierThan(Date()) {
                    strongSelf.checkedLicenceWithEarlierDate()
                } else {
                    strongSelf.checkedLicenceWithNoDate()
                }
            }
        }
    }
}

class DPAGLicencesInitViewController: DPAGViewControllerBackground, DPAGLicencesInitConsumer, DPAGLicenceViewControllerProtocol {
    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackViewScroll: UIStackView!
    @IBOutlet private var stackViewLicences: UIStackView!
    @IBOutlet private var stackViewLicenceItems: UIStackView!

    @IBOutlet private var labelTitle: UILabel! {
        didSet {
            self.labelTitle.text = DPAGLocalizedString("licenceInit.licencesNoFound.headline")
            self.labelTitle.font = UIFont.kFontTitle1
            self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
            self.labelTitle.numberOfLines = 0
        }
    }

    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.font = UIFont.kFontSubheadline
            self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            let bundleIdentifier = DPAGMandant.default.name
            self.labelDescription.text = String(format: DPAGLocalizedString("licenceInit.licencesNoFound.description"), bundleIdentifier)
            self.labelDescription.numberOfLines = 0
        }
    }

    @IBOutlet private var btnDeleteAccount: UIButton! {
        didSet {
            self.btnDeleteAccount.accessibilityIdentifier = "btnDeleteAccount"
            self.btnDeleteAccount.configureButtonDestructive()
            self.btnDeleteAccount.addTarget(self, action: #selector(handleDeleteAccount), for: .touchUpInside)
            self.btnDeleteAccount.setTitle(DPAGLocalizedString("licenceInit.licencesNoFound.btnDeleteAccount"), for: .normal)
        }
    }
	
    @IBOutlet private var btnRestorePurchases: UIButton! {
        didSet {
            self.btnRestorePurchases.accessibilityIdentifier = "btnRestorePurchases"
            self.btnRestorePurchases.configureButton()
            self.btnRestorePurchases.addTarget(self, action: #selector(handleRestorePurchases), for: .touchUpInside)
            self.btnRestorePurchases.setTitle(DPAGLocalizedString("licenceInit.licencesNoFound.btnRestorePurchases"), for: .normal)
        }
    }

    @IBOutlet private var btnCodeInput: UIButton! {
        didSet {
            self.btnCodeInput.accessibilityIdentifier = "btnCodeInput"
            self.btnCodeInput.configureButton()
            self.btnCodeInput.addTarget(self, action: #selector(handleCodeInput), for: .touchUpInside)
            self.btnCodeInput.setTitle(DPAGLocalizedString("licenceInit.licencesNoFound.btnCodeInput"), for: .normal)
        }
    }

    @IBOutlet private var activityIndicator: UIActivityIndicatorView?

    private var dateValidation: Date?

    func setDateValid(_ dateValid: Date?) {
        self.dateValidation = dateValid
    }

    private var licences: [DPAGLicence] = []
    private var licencesLoaded = false

    private var transactionObserverRegistered = false

    init() {
        super.init(nibName: "DPAGLicencesInitViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.title = DPAGLocalizedString("licenceInit.title")
        var constraints: [NSLayoutConstraint] = []
        if let dateValid = self.dateValidation {
            let viewLicencesUsage = UIView()
            let viewBorder = UIView()
            let stackViewUsageAll = UIStackView()
            let stackViewUsageDate = UIStackView()
            let labelLicence = UILabel()
            let labelLicencesUsage = UILabel()
            let labelLicencesUsageDate = UILabel()

            viewLicencesUsage.addSubview(viewBorder)
            viewLicencesUsage.addSubview(stackViewUsageAll)
            viewBorder.translatesAutoresizingMaskIntoConstraints = false
            stackViewUsageAll.translatesAutoresizingMaskIntoConstraints = false
            constraints += viewLicencesUsage.constraintsFill(subview: stackViewUsageAll, padding: 16)
            constraints += [
                viewLicencesUsage.leadingAnchor.constraint(equalTo: viewBorder.leadingAnchor, constant: 0),
                viewLicencesUsage.trailingAnchor.constraint(equalTo: viewBorder.trailingAnchor, constant: 0),
                viewBorder.heightAnchor.constraint(equalToConstant: 0.5),
                viewLicencesUsage.bottomAnchor.constraint(equalTo: viewBorder.bottomAnchor, constant: 0)
            ]
            viewBorder.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            stackViewUsageAll.axis = .vertical
            stackViewUsageAll.alignment = .fill
            stackViewUsageAll.distribution = .fill
            stackViewUsageAll.spacing = 16

            stackViewUsageDate.axis = .horizontal
            stackViewUsageDate.alignment = .fill
            stackViewUsageDate.distribution = .fill
            stackViewUsageDate.spacing = 8

            stackViewUsageAll.addArrangedSubview(labelLicence)
            stackViewUsageAll.addArrangedSubview(stackViewUsageDate)

            stackViewUsageDate.addArrangedSubview(labelLicencesUsage)
            stackViewUsageDate.addArrangedSubview(labelLicencesUsageDate)

            labelLicencesUsage.text = DPAGLocalizedString("licenceInit.licencesUsage.label")
            labelLicencesUsage.textColor = DPAGColorProvider.shared[.labelText]
            labelLicencesUsage.font = UIFont.kFontBody

            labelLicencesUsageDate.font = UIFont.kFontBody
            labelLicencesUsageDate.textColor = DPAGColorProvider.shared[.labelText]

            labelLicence.text = DPAGLocalizedString("licenceInit.expired.title")
            labelLicence.font = UIFont.kFontCaption1
            labelLicence.textColor = DPAGColorProvider.shared[.labelText]

            if Date().isEarlierThan(dateValid) {
                labelLicencesUsageDate.text = String(format: DPAGLocalizedString("licenceInit.licencesUsage.validTillFormat"), DateFormatter.localizedString(from: dateValid, dateStyle: .short, timeStyle: .none))
                labelLicencesUsageDate.textColor = DPAGColorProvider.shared[.labelText]
            } else {
                labelLicencesUsageDate.text = DPAGLocalizedString("licenceInit.licencesUsage.nonValid")
                labelLicencesUsageDate.textColor = DPAGColorProvider.shared[.labelDestructive]
            }

            labelLicencesUsage.adjustsFontSizeToFitWidth = true
            labelLicencesUsage.setContentHuggingPriority(.defaultLow, for: .horizontal)
            labelLicencesUsageDate.setContentHuggingPriority(UILayoutPriority.defaultLow + 1, for: .horizontal)
            self.stackViewScroll.insertArrangedSubview(viewLicencesUsage, at: 0)
            if self.presentingViewController != nil, (self.navigationController?.viewControllers.count ?? 0) == 1 {
                if Date().isEarlierThan(dateValid) {
                    self.setLeftBackBarButtonItem(action: #selector(dismissViewController))
                }
                self.labelTitle.text = DPAGLocalizedString("licenceInit.expired.headline")
                let bundleIdentifier = DPAGMandant.default.name
                self.labelDescription.text = String(format: DPAGLocalizedString("licenceInit.expired.description"), bundleIdentifier)
            }
        } else {
            let viewLicencesNotFound = UIView()
            let stackView = UIStackView()
            let labelLicencesNotFound = UILabel()
            let imageViewLicencesNotFound = UIImageView(image: DPAGImageProvider.shared[.kImageButtonAlert])

            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.distribution = .fill
            stackView.spacing = 16
            viewLicencesNotFound.addSubview(stackView)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            imageViewLicencesNotFound.contentMode = .scaleAspectFit
            imageViewLicencesNotFound.tintColor = DPAGColorProvider.shared[.alertDestructiveTint]
            labelLicencesNotFound.text = DPAGLocalizedString("licenceInit.licencesNoFound.alert_message")
            labelLicencesNotFound.textColor = DPAGColorProvider.shared[.alertDestructiveTint]
            labelLicencesNotFound.font = UIFont.kFontFootnote
            labelLicencesNotFound.numberOfLines = 0
            viewLicencesNotFound.backgroundColor = DPAGColorProvider.shared[.alertDestructiveBackground]
            stackView.addArrangedSubview(imageViewLicencesNotFound)
            stackView.addArrangedSubview(labelLicencesNotFound)
            constraints += viewLicencesNotFound.constraintsFill(subview: stackView, padding: 16)
            constraints += [
                imageViewLicencesNotFound.constraintWidth(60),
                imageViewLicencesNotFound.constraintHeight(50)
            ]
            self.stackViewScroll.insertArrangedSubview(viewLicencesNotFound, at: 0)
        }

        NSLayoutConstraint.activate(constraints)
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelTitle.textColor = DPAGColorProvider.shared[.labelText]
                self.labelDescription.textColor = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func showAcceptedRequiredViewController(_ vc: UIViewController) {
        self.navigationController?.pushViewController(vc, animated: true)
        //                                        let nextVC = DPAGApplicationFacadeUIBase.navVC(rootViewController: vc)
        //
        //                                        AppConfig.appWindow()??.rootViewController?.present(nextVC, animated: true, completion: nil)
    }

    func checkedLicenceWithEarlierDate() {
        self.performBlockOnMainThread { [weak self] in
            self?.setLeftBackBarButtonItem(action: #selector(DPAGLicencesInitViewController.dismissViewController))
        }
    }

    func checkedLicenceWithNoDate() {
        self.performBlockOnMainThread { [weak self] in

            self?.setLeftBackBarButtonItem(action: #selector(DPAGLicencesInitViewController.dismissViewController))
        }
    }

    private func registerTransactionObserver() {
        if !self.transactionObserverRegistered {
            SKPaymentQueue.default().add(self)
            self.transactionObserverRegistered = true
        }
    }

    private func unregisterTransactionObserver() {
        if self.transactionObserverRegistered {
            SKPaymentQueue.default().remove(self)
            self.transactionObserverRegistered = false
        }
    }

    @objc
    private func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.licencesLoaded == false, self.activityIndicator?.superview != nil {
            self.activityIndicator?.startAnimating()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.licencesLoaded == false {
            self.performBlockInBackground { [weak self] in
                self?.loadLicences()
                self?.registerTransactionObserver()
            }
        } else {
            self.registerTransactionObserver()
        }
        self.checkCompanyManagement()
        self.performBlockInBackground { [weak self] in
            self?.checkLicence()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.unregisterTransactionObserver()
    }

    override func appWillEnterForeground() {
        super.appWillEnterForeground()
        self.checkCompanyManagement()
        self.performBlockInBackground { [weak self] in
            self?.checkLicence()
        }
    }

    private func loadLicences() {
        DPAGPurchaseWorker.getProductsWithResponse { responseObject, _, errorMessage in
            if let errorMessage = errorMessage {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                }
                // responseBlock(nil, errorMessage)
            } else if let products = responseObject as? [Any] {
                var productRequests: Set<String> = Set<String>()
                for product in products {
                    if let productOuterDict = product as? [String: Any] {
                        if let productDict = productOuterDict["Product"] as? [String: AnyObject] {
                            /* Product =     {
                             duration = 365
                             feature = usage
                             feature = usage
                             guid = "8:{b412e86d-57f2-4bad-af8f-aace5a7e89af}"
                             ident = testOneYear
                             mandant = ba
                             os = iOS; */

							if let productOS = productDict["os"] as? String, productOS != "iOS" {
								continue
							}
							
                            let licence = DPAGLicence()
                            licence.guid = productDict["guid"] as? String
                            licence.productId = productDict["productId"] as? String
                            licence.feature = productDict["feature"] as? String
                            licence.duration = productDict["duration"] as? NSNumber

                            guard let productId = licence.productId else {
                                continue
                            }

                            if licence.feature != "usage" {
                                continue
                            }

                            let validDate = Date.withDaysFromNow(licence.duration?.intValue ?? 0)
                            licence.description = String(format: DPAGLocalizedString("licenceInit.licence.validTillFormat"), DateFormatter.localizedString(from: validDate, dateStyle: .short, timeStyle: .none))
                            productRequests.insert(productId)
                            self.licences.append(licence)
                        }
                    }
                }
                DPAGPurchaseHelper.sharedInstance.startProductsRequest(productIdentifiers: productRequests, productRequestDelegate: self)
            } else {
                DPAGProgressHUD.sharedInstance.hide(true)
            }
        }
    }

    private func showLicences() {
        self.activityIndicator?.stopAnimating()
        self.activityIndicator?.isHidden = true
        var count = 0
        for licence in self.licences {
            if let licenceView = DPAGApplicationFacadeUIRegistration.viewLicenceItem() {
                licenceView.licence = licence
                licenceView.accessibilityIdentifier = "licenceView-\(count)"
                licenceView.purchaseDelegate = self
                self.stackViewLicenceItems.addArrangedSubview(licenceView)
                count += 1
            }
        }
        self.stackViewLicences.layoutIfNeeded()
    }

    private func purchase(_ licence: DPAGLicence) {
        if let appleProduct = licence.appleProduct {
            let payment = SKPayment(product: appleProduct)
            SKPaymentQueue.default().add(payment)
        }
    }

    @objc
    private func handleRestorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    @objc
    private func handleCodeInput() {
        let vc = DPAGApplicationFacadeUIRegistration.licencesInputVC()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    @objc
    private func handleDeleteAccount() {
        let block: DPAGPasswordRequest = { success in
            if success {
                NotificationCenter.default.post(name: DPAGStrings.Notification.Account.SHOW_DELETE_PROFILE_VC, object: nil)
            }
        }
        DPAGApplicationFacadeUIBase.loginVC.requestPassword(withTouchID: false, completion: block)
    }
}

extension DPAGLicencesInitViewController: DPAGLicenceItemViewDelegate {
    func handlePurchase(licence: DPAGLicence?) {
        if let licence = licence {
            self.purchase(licence)
        }
    }
}

extension DPAGLicencesInitViewController: SKProductsRequestDelegate, SKPaymentTransactionObserver {
    func productsRequest(_: SKProductsRequest, didReceive response: SKProductsResponse) {
        for validproduct in response.products {
            for license in self.licences where validproduct.productIdentifier == license.productId {
                license.appleProduct = validproduct
                license.label = validproduct.localizedTitle
            }
        }
        self.licences = self.licences.filter({ (license) -> Bool in
            license.appleProduct != nil
        })
        self.performBlockOnMainThread { [weak self] in
            self?.licencesLoaded = true
            self?.showLicences()
        }
    }

    func paymentQueue(_: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DPAGLog("Received Payment Transaction Response from Apple")
        for transaction in transactions {
            switch transaction.transactionState {
                case .purchased:
                    DPAGLog("Product Purchased")
                    guard let receiptUrl = Bundle.main.appStoreReceiptURL, let receipt: Data = try? Data(contentsOf: receiptUrl) else { break }
                    let receiptdata = receipt.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
                    let productId = transaction.payment.productIdentifier
                    let transactionid = transaction.transactionIdentifier
                    let responseBlock: DPAGServiceResponseBlock = { [weak self] _, _, errorMessage in
                        if let errorMessage = errorMessage {
                            DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                            }
                        } else {
                            self?.performBlockOnMainThread { [weak self] in
                                SKPaymentQueue.default().finishTransaction(transaction)
                                if let strongSelf = self {
                                    SKPaymentQueue.default().remove(strongSelf)
                                }
                                self?.performBlockInBackground {
                                    NotificationCenter.default.post(name: DPAGStrings.Notification.Licence.LICENCE_UPDATE_TESTLICENCE_DATE, object: nil)
                                }
                                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
                                    self?.dismiss(animated: true, completion: nil)
                                }
                            }
                        }
                    }
                    DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                        DPAGPurchaseWorker.registerPurchase(productId, andTransaction: transactionid, andReceipt: receiptdata, withResponse: responseBlock)
                    }
                case .failed:
                    DPAGLog("Purchased Failed")
                    SKPaymentQueue.default().finishTransaction(transaction)
                default:
                    break
            }
        }
    }
}
