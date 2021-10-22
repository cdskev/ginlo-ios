//
//  DPAGTableViewController.swift
// ginlo
//
//  Created by RBU on 28/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public protocol DPAGViewControllerWithReloadProtocol: AnyObject {
    var reloadOnAppear: Bool { get set }
}

public protocol DPAGTableViewControllerProtocol: AnyObject {
    var tableView: UITableView! { get }
}

public protocol DPAGTableViewControllerWithReloadProtocol: DPAGTableViewControllerProtocol & DPAGViewControllerWithReloadProtocol {}

public protocol DPAGTableViewControllerWithSearchProtocol: DPAGTableViewControllerProtocol, UISearchBarDelegate, UISearchControllerDelegate {
    var searchController: UISearchController? { get set }
    var searchResultsController: (UIViewController & DPAGSearchResultsViewControllerProtocol)? { get set }
}

open class DPAGTableViewControllerWithSearch: DPAGTableViewControllerBackground, DPAGTableViewControllerWithSearchProtocol {
    public var searchController: UISearchController?
    public var searchResultsController: (UIViewController & DPAGSearchResultsViewControllerProtocol)?
    
    public func configureSearchBarWithResultsController(_ searchResultsController: UIViewController & DPAGSearchResultsViewControllerProtocol, placeholder: String) {
        let searchController: UISearchController
        searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchBar.placeholder = DPAGLocalizedString(placeholder)
        searchController.searchBar.accessibilityIdentifier = placeholder
        if self.parent == nil || self.parent is UINavigationController {
            self.navigationItem.searchController = searchController
        } else {
            if let tableHeaderView = self.tableView.tableHeaderView {
                let stackView = UIStackView()
                stackView.alignment = .fill
                stackView.axis = .vertical
                stackView.distribution = .fill
                stackView.spacing = 0
                stackView.addArrangedSubview(tableHeaderView)
                stackView.addArrangedSubview(searchController.searchBar)
                self.tableView.tableHeaderView = stackView
            } else {
                self.tableView.tableHeaderView = searchController.searchBar
            }
        }
        self.searchController = searchController
        self.definesPresentationContext = true
        self.searchResultsController = searchResultsController
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.customizeSearchBar()
    }

    open func filterContent(searchText _: String, completion: @escaping () -> Void) {}

    private func customizeSearchBar() {
        guard let searchBar = self.searchController?.searchBar else { return }
        DPAGUIHelper.customizeSearchBar(searchBar)
    }
    
    override open func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.customizeSearchBar()
    }
}

extension DPAGTableViewControllerWithSearch: UISearchBarDelegate {
    public func searchBar(_: UISearchBar, textDidChange searchText: String) {
        self.searchResultsController?.searchBarText = searchText.lowercased()
        self.performBlockInBackground { [weak self] in
            self?.filterContent(searchText: searchText, completion: {
                if self?.searchResultsController?.view != nil {
                    self?.searchResultsController?.tableView.reloadData()
                }
            })
        }
    }
}

extension DPAGTableViewControllerWithSearch: UISearchControllerDelegate {
    open func willPresentSearchController(_: UISearchController) {}

    open func willDismissSearchController(_: UISearchController) {
        self.tableView.reloadData()
    }
}

public protocol DPAGSearchResultsViewControllerProtocol: AnyObject {
    var tableView: UITableView! { get }
    var searchBarText: String? { get set }
}

open class DPAGSearchResultsViewController: DPAGTableViewControllerBackground, DPAGSearchResultsViewControllerProtocol {
    public var searchBarText: String?

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view.accessibilityIdentifier = "\(type(of: self))".components(separatedBy: ".").last
    }

    override open func configureTableView() {
        super.configureTableView()
        self.tableView.keyboardDismissMode = .onDrag
    }

    private var doReload = false

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.doReload {
            self.tableView.reloadData()
        }
        self.doReload = true
    }
}

public protocol DPAGTableViewControllerWithRefreshProtocol: AnyObject {}

open class DPAGTableViewControllerBackground: DPAGViewControllerWithKeyboard {
    public var tableView: UITableView!

    public let refreshControl = UIRefreshControl()

    var constraintTableViewTop: NSLayoutConstraint?
    var constraintTableViewBottom: NSLayoutConstraint?

    public convenience init() {
        self.init(style: .plain)
    }

    public init(style: UITableView.Style) {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
        self.tableView = UITableView(frame: .zero, style: style)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.tableView.delegate = nil
        self.tableView.dataSource = nil
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.configureTableView()
    }

    override open
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
        self.tableView.backgroundColor = .clear
        self.tableView.reloadData()
    }

    @objc
    override open func preferredContentSizeChanged(_ aNotification: Notification?) {
        super.preferredContentSizeChanged(aNotification)
        if aNotification == nil {
            return
        }
        self.tableView.reloadData()
        self.tableViewEmpty?.setNeedsLayout()
        self.tableViewEmpty?.layoutIfNeeded()
    }

    open func configureTableView() {
        if self is DPAGTableViewControllerWithRefreshProtocol {
            self.tableView.refreshControl = self.refreshControl
        }
        self.extendedLayoutIncludesOpaqueBars = (self is DPAGSearchResultsViewControllerProtocol) == false
        self.tableView.backgroundColor = .clear
        self.tableView.delegate = self as? UITableViewDelegate
        self.tableView.dataSource = self as? UITableViewDataSource
        self.tableView.separatorStyle = .singleLine
        self.tableView.separatorColor = DPAGColorProvider.shared[.tableSeparator]
        self.view.addSubview(self.tableView)
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        let constraintTableViewTop: NSLayoutConstraint
        let constraintTableViewBottom: NSLayoutConstraint
        constraintTableViewTop = self.view.topAnchor.constraint(equalTo: self.tableView.topAnchor)
        constraintTableViewBottom = self.view.bottomAnchor.constraint(equalTo: self.tableView.bottomAnchor)
        NSLayoutConstraint.activate([
            constraintTableViewTop,
            constraintTableViewBottom,
            self.view.constraintLeading(subview: self.tableView),
            self.view.constraintTrailing(subview: self.tableView)
        ])
        self.constraintTableViewTop = constraintTableViewTop
        self.constraintTableViewBottom = constraintTableViewBottom
    }

    public func addBottomView(_ viewBottom: UIView) {
        guard let superview = self.tableView.superview else { return }
        viewBottom.translatesAutoresizingMaskIntoConstraints = false
        if let constraintTableViewBottom = self.constraintTableViewBottom {
            superview.removeConstraint(constraintTableViewBottom)
        }
        superview.addSubview(viewBottom)
        var constraints: [NSLayoutConstraint] = []
        constraints += superview.constraintsStackingBottom(subview: viewBottom)
        constraints.append(superview.constraintBottomToTop(bottomView: self.tableView, topView: viewBottom))
        NSLayoutConstraint.activate(constraints)
    }

    open var tableViewEmpty: UIView?

    public func showEmptyView() {
        if let tableViewEmpty = self.tableViewEmpty, tableViewEmpty.superview == nil {
            self.tableView.tableHeaderView?.isHidden = true
            self.tableView.superview?.insertSubview(tableViewEmpty, aboveSubview: self.tableView)
            tableViewEmpty.translatesAutoresizingMaskIntoConstraints = false
            self.tableView.superview?.addConstraintsFill(subview: tableViewEmpty)
        }
    }

    public func hideEmptyView() {
        self.tableViewEmpty?.removeFromSuperview()
        self.tableView.tableHeaderView?.isHidden = false
    }
}
