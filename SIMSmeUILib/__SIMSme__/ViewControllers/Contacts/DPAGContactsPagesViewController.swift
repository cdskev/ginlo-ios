//
//  DPAGCompanyContactsOverViewController.swift
//  SIMSme
//
//  Created by Yves Hetzer on 27.10.16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

extension DPAGContactsPagesBaseViewController {}

class DPAGContactsPagesBaseViewController: DPAGViewController, DPAGContactsPagesBaseViewControllerProtocol {
    @IBOutlet private var contentView: UIView!

    private let pageViewController: UIPageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private(set) var searchController: UISearchController?
    private(set) var searchResultsController: (UIViewController & DPAGContactsSearchResultsViewControllerProtocol)?

    @IBOutlet var stackView: UIStackView!
    @IBOutlet var viewButtonFrame: UIView?
    @IBOutlet private var button0: UIButton? {
        didSet {
            self.button0?.setTitle(nil, for: .normal)
//            self.button0?.setTitle(DPAGLocalizedString("settings.companyprofile.contactsoverview.button1").uppercased(), for: .normal)
            self.button0?.setImage(DPAGImageProvider.shared[.kImageContactsPrivate], for: .normal)
            self.configureButtonPage(button: self.button0)

            self.button0?.addTargetClosure { [weak self] _ in
                self?.button0?.isSelected = true
                self?.button1?.isSelected = false
                self?.button2?.isSelected = false
                self?.button0?.tintColor = DPAGColorProvider.shared[.buttonTintSelectedNoBackground]
                self?.button1?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self?.button2?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]

                self?.pageChangeRequest(self?.page0)
            }
        }
    }

    @IBOutlet private var button1: UIButton? {
        didSet {
            self.button1?.setTitle(nil, for: .normal)
//            self.button1?.setTitle(DPAGLocalizedString("settings.companyprofile.contactsoverview.button2").uppercased(), for: .normal)
            self.button1?.setImage(DPAGImageProvider.shared[.kImageContactsDomain], for: .normal)
            self.configureButtonPage(button: self.button1)

            self.button1?.addTargetClosure { [weak self] _ in
                self?.button0?.isSelected = false
                self?.button1?.isSelected = true
                self?.button2?.isSelected = false
                self?.button0?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self?.button1?.tintColor = DPAGColorProvider.shared[.buttonTintSelectedNoBackground]
                self?.button2?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]

                self?.pageChangeRequest(self?.page1)
            }
        }
    }

    @IBOutlet private var button2: UIButton? {
        didSet {
            self.button2?.setTitle(nil, for: .normal)
//            self.button2?.setTitle(DPAGLocalizedString("settings.companyprofile.contactsoverview.button2").uppercased(), for: .normal)
            self.button2?.setImage(DPAGImageProvider.shared[.kImageContactsCompany], for: .normal)
            self.configureButtonPage(button: self.button2)

            self.button2?.addTargetClosure { [weak self] _ in
                self?.button0?.isSelected = false
                self?.button1?.isSelected = false
                self?.button2?.isSelected = true
                self?.button0?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self?.button1?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
                self?.button2?.tintColor = DPAGColorProvider.shared[.buttonTintSelectedNoBackground]

                self?.pageChangeRequest(self?.page2)
            }
        }
    }

    private func configureButtonPage(button: UIButton?) {
        button?.tintColor = DPAGColorProvider.shared[.buttonTintNoBackground]
        button?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .normal)
        button?.setTitleColor(DPAGColorProvider.shared[.buttonTintNoBackground], for: .selected)
        button?.titleLabel?.font = UIFont.kFontFootnote
        button?.setBackgroundImage(UIImage.tabControlImageSelected(height: 56), for: .selected)
    }

    var page0: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?
    var page1: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?
    var page2: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?
    var pages: [UIViewController & DPAGContactsSelectionBaseViewControllerProtocol] = []

    weak var progressHUDSyncInfo: DPAGProgressHUDWithLabelProtocol?

    let contactsSelected: DPAGSearchListSelection<DPAGContact>

    init(contactsSelected: DPAGSearchListSelection<DPAGContact>) {
        self.contactsSelected = contactsSelected

        super.init(nibName: "DPAGContactsPagesViewController", bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.configureGui()
    }

    func configureGui() {
        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        if let pages = self as? DPAGContactsPagesViewControllerProtocol {
            self.page0 = pages.createPage0()
            self.page1 = pages.createPage1()
            self.page2 = pages.createPage2()
        }
        if let page = self.page0 {
            self.pages.append(page)
            self.pageViewController.setViewControllers([page], direction: .forward, animated: false, completion: nil)
        }
        if let page = self.page1 {
            self.pages.append(page)
        } else {
            self.button1?.superview?.isHidden = true
        }
        if let page = self.page2 {
            self.pages.append(page)
        } else {
            self.button2?.superview?.isHidden = true
        }
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.pageViewController.view.frame = self.contentView.bounds
        self.contentView.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
        self.configureNavigationBar()
        self.configureSearchBar()
        self.button0?.isSelected = true
        self.button1?.isSelected = false
        self.button2?.isSelected = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    private func configureSearchBar() {
        let placeholder = "android.serach.placeholder"
        let searchResultsController: UIViewController & DPAGContactsSearchResultsViewControllerProtocol
        if AppConfig.isShareExtension {
            searchResultsController = DPAGApplicationFacadeUIContacts.contactsPagesSearchResultsVC(delegate: self, emptyViewDelegate: nil)
        } else {
            searchResultsController = DPAGApplicationFacadeUIContacts.contactsPagesSearchResultsVC(delegate: self, emptyViewDelegate: self)
        }
        let searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchBar.placeholder = DPAGLocalizedString(placeholder)
        searchController.searchBar.accessibilityIdentifier = placeholder
        searchController.searchBar.delegate = self
        searchController.delegate = self
        DPAGUIHelper.customizeSearchBar(searchController.searchBar)
        if self.parent is UINavigationController {
            self.navigationItem.searchController = searchController
            self.definesPresentationContext = true
            if #available(iOS 13.0, *) {
                self.extendedLayoutIncludesOpaqueBars = true
                self.edgesForExtendedLayout = .all
            }
        } else {
            let searchBarFrameView = UIView()
            searchBarFrameView.constraintHeight(44).activate()
            searchBarFrameView.addSubview(searchController.searchBar)
            self.stackView.insertArrangedSubview(searchBarFrameView, at: 0)
            self.definesPresentationContext = false
        }
        self.searchController = searchController
        self.pages.forEach { $0.searchResultsController = searchResultsController }
    }

    func configureNavigationBar() {}

    private var currentPage: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        ((self.button0?.isSelected ?? false) ? self.page0 : ((self.button1?.isSelected ?? false) ? self.page1 : self.page2))
    }

    func pageChangeRequest(_ page: (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)?) {
        guard let pageSet = page ?? self.currentPage else { return }
        let block = { [weak self] in
            self?.title = pageSet.title
        }
        self.pages.forEach { $0.searchController?.isActive = false }
        var direction: UIPageViewController.NavigationDirection = .forward
        if self.pageViewController.viewControllers?.first != pageSet {
            if pageSet === self.page0 {
                direction = .reverse
            } else if pageSet === self.page2 {
                direction = .forward
            } else if pageSet === self.page1 {
                direction = self.pageViewController.viewControllers?.first == self.page0 ? .forward : .reverse
            }
            pageSet.tableView.reloadData()
            self.pageViewController.setViewControllers([pageSet], direction: direction, animated: true) { _ in
                block()
            }
        } else {
            block()
        }
    }

    func updateTitle() {
        let pageSet = self.currentPage
        self.title = pageSet?.title
    }
}

extension DPAGContactsPagesBaseViewController: DPAGViewControllerWithReloadProtocol {
    var reloadOnAppear: Bool {
        get {
            let pageSet = self.currentPage as? DPAGViewControllerWithReloadProtocol
            return pageSet?.reloadOnAppear ?? false
        }
        set {
            self.pages.forEach { ($0 as? DPAGViewControllerWithReloadProtocol)?.reloadOnAppear = newValue }
        }
    }
}

extension DPAGContactsPagesBaseViewController: DPAGContactsSearchEmptyViewDelegate {
    func handleSearch() {
        let pageSet = self.currentPage as? DPAGContactsSearchEmptyViewDelegate
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) {
                pageSet?.handleSearch()
            }
        } else {
            pageSet?.handleSearch()
        }
    }

    func handleInvite() {
        let pageSet = self.currentPage as? DPAGContactsSearchEmptyViewDelegate
        if let searchController = self.searchController, searchController.isActive {
            searchController.dismiss(animated: true) {
                pageSet?.handleInvite()
            }
        } else {
            pageSet?.handleInvite()
        }
    }
}

extension DPAGContactsPagesBaseViewController: DPAGContactsSelectionPagesViewControllerDelegate {
    func didSelectMultiPerson(_: DPAGContact) {}

    func didUnselectMultiPerson(_: DPAGContact) {}
}

extension DPAGContactsPagesBaseViewController: DPAGContactsSearchViewControllerDelegate {
    func didSelectContact(contact: DPAGContact) {
        let pageSet = self.currentPage
        if let searchController = self.searchController, searchController.isActive {
            self.performBlockInBackground {
                Thread.sleep(forTimeInterval: 0.2)
                self.performBlockOnMainThread {
                    searchController.dismiss(animated: true) {
                        (pageSet as? DPAGContactsSearchViewControllerDelegate)?.didSelectContact(contact: contact)
                    }
                }
            }
        } else {
            (pageSet as? DPAGContactsSearchViewControllerDelegate)?.didSelectContact(contact: contact)
        }
    }
}

extension DPAGContactsPagesBaseViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let pageSet = self.currentPage
        pageSet?.searchBar?(searchBar, textDidChange: searchText)
    }
}

extension DPAGContactsPagesBaseViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        if !(self.parent is UINavigationController) {
            self.viewButtonFrame?.isHidden = true
            self.stackView.layoutIfNeeded()
            (self.parent?.parent as? DPAGReceiverSelectionViewControllerProtocol)?.willPresentSearchController?(searchController)
        }
        let pageSet = self.currentPage
        pageSet?.willPresentSearchController?(searchController)
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        if !(self.parent is UINavigationController) {
            self.viewButtonFrame?.isHidden = false
            self.stackView.layoutIfNeeded()
            (self.parent?.parent as? DPAGReceiverSelectionViewControllerProtocol)?.willDismissSearchController?(searchController)
        }
        let pageSet = self.currentPage
        pageSet?.willDismissSearchController?(searchController)
    }
}

class DPAGContactsPagesViewController: DPAGContactsPagesBaseViewController {}

protocol DPAGContactsSelectionPagesViewControllerDelegate: AnyObject {
    func didSelectMultiPerson(_ person: DPAGContact)
    func didUnselectMultiPerson(_ person: DPAGContact)
}

extension DPAGContactsCompanyPagesViewController: DPAGContactsOptionsProtocol {
    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}

class DPAGContactsCompanyPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGViewControllerNavigationTitleBig {
    override func viewDidLoad() {
        super.viewDidLoad()
        if AppConfig.isShareExtension == false {
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
        }
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsCompanyPageVC(contactsSelected: self.contactsSelected)
    }
}

extension DPAGContactsDomainPagesViewController: DPAGContactsOptionsProtocol {
    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}

class DPAGContactsDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGViewControllerNavigationTitleBig {
    override func viewDidLoad() {
        super.viewDidLoad()
        if AppConfig.isShareExtension == false {
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
        }
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsDomainPageVC(contactsSelected: self.contactsSelected)
    }
}

extension DPAGContactsCompanyDomainPagesViewController: DPAGContactsOptionsProtocol {
    @objc
    private func handleOptions() {
        if let modelVC = self.page0 as? DPAGContactsOptionsViewControllerProtocol {
            self.handleOptions(presentingVC: self, modelVC: modelVC, barButtonItem: self.navigationItem.rightBarButtonItem)
        }
    }
}

class DPAGContactsCompanyDomainPagesViewController: DPAGContactsPagesBaseViewController, DPAGContactsPagesViewControllerProtocol, DPAGViewControllerNavigationTitleBig {
    override func viewDidLoad() {
        super.viewDidLoad()
        if AppConfig.isShareExtension == false {
            self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kEllipsisCircle], action: #selector(handleOptions), accessibilityLabelIdentifier: "navigation.options")
        }
    }

    func createPage0() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol) {
        DPAGApplicationFacadeUIContacts.contactsPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage2() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsCompanyPageVC(contactsSelected: self.contactsSelected)
    }

    func createPage1() -> (UIViewController & DPAGContactsSelectionBaseViewControllerProtocol)? {
        DPAGApplicationFacadeUIContacts.contactsDomainPageVC(contactsSelected: self.contactsSelected)
    }
}
