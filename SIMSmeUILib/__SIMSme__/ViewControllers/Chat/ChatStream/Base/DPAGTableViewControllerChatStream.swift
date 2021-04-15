//
//  DPAGTableViewControllerChatStream.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 16.09.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGTableViewControllerChatStream: DPAGViewControllerBackground {
    lazy var stackViewAll: UIStackView? = UIStackView()
    lazy var stackViewTableView: DPAGStackView? = DPAGStackView()
    lazy var tableViewView: DPAGStackViewContentView? = DPAGStackViewContentView()
    lazy var tableViewSearchResultsView: DPAGStackViewContentView? = DPAGStackViewContentView()

    var tableViewEmpty: UIView?

    var refreshControl: UIRefreshControl? {
        didSet {
            if let refreshControl = self.refreshControl {
                self.tableView.refreshControl = refreshControl
            }
        }
    }
    private let tableStyle: UITableView.Style
    lazy var tableView: DPAGTableView! = DPAGTableView(frame: .zero, style: self.tableStyle)

    convenience init() {
        self.init(style: .plain)
    }

    init(style: UITableView.Style) {
        self.tableStyle = style
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        self.tableView.delegate = nil
        self.tableView.dataSource = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureTableView()
    }

    func configureTableView() {
        self.tableView.delegate = self as? UITableViewDelegate
        self.tableView.dataSource = self as? UITableViewDataSource
        let stackViewAll = UIStackView()
        let stackViewTableView = DPAGStackView()
        let tableViewView = DPAGStackViewContentView()
        let tableViewSearchResultsView = DPAGStackViewContentView()
        stackViewAll.distribution = .fill
        stackViewAll.alignment = .fill
        stackViewAll.spacing = 0
        stackViewAll.axis = .vertical
        stackViewTableView.distribution = .fill
        stackViewTableView.alignment = .fill
        stackViewTableView.spacing = 0
        stackViewTableView.axis = .vertical
        self.view.addSubview(stackViewAll)
        stackViewAll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.view.centerXAnchor.constraint(equalTo: stackViewAll.centerXAnchor),
            self.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: stackViewAll.topAnchor),
            self.view.bottomAnchor.constraint(equalTo: stackViewAll.bottomAnchor),
            self.view.leadingAnchor.constraint(equalTo: stackViewAll.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: stackViewAll.trailingAnchor)
        ])
        stackViewAll.addArrangedSubview(stackViewTableView)
        tableViewView.addSubview(self.tableView)
        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        tableViewView.addConstraintsFill(subview: self.tableView)
        tableViewView.addSubview(tableViewSearchResultsView)
        tableViewSearchResultsView.translatesAutoresizingMaskIntoConstraints = false
        tableViewView.addConstraintsFill(subview: tableViewSearchResultsView)
        tableViewSearchResultsView.alpha = 0
        tableView.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
        stackViewTableView.addArrangedSubview(tableViewView)
        if let tableViewEmpty = self.tableViewEmpty {
            stackViewAll.insertArrangedSubview(tableViewEmpty, at: 0)
            tableViewEmpty.isHidden = true
        }
        self.tableView.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
        self.stackViewAll = stackViewAll
        self.stackViewTableView = stackViewTableView
        self.tableViewView = tableViewView
        self.tableViewSearchResultsView = tableViewSearchResultsView
        self.tableView.prefetchDataSource = self as? UITableViewDataSourcePrefetching
    }

    override func preferredContentSizeChanged(_ aNotification: Notification?) {
        if aNotification == nil {
            return
        }
        self.tableView.reloadData()
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DPAGLog("stream base appeared")
        self.tableView.isContentOffsetAnimated = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let indexPaths = self.tableView.indexPathsForVisibleRows else { return }
        for indexPath in indexPaths {
            if self.tableView.contentOffset.y <= self.tableView.rectForRow(at: indexPath).origin.y {
                coordinator.animate(alongsideTransition: { [weak self] _ in
                    self?.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                }, completion: { _ in
                })
                break
            }
        }
    }

    func showEmptyView() {
        if let tableViewEmpty = self.tableViewEmpty {
            self.stackViewTableView?.isHidden = true
            tableViewEmpty.isHidden = false
            tableViewEmpty.superview?.layoutIfNeeded()
        }
    }

    func hideEmptyView() {
        if let tableViewEmpty = self.tableViewEmpty {
            self.stackViewTableView?.isHidden = false
            tableViewEmpty.isHidden = true
            tableViewEmpty.superview?.layoutIfNeeded()
        }
    }

    @objc
    func handleTableViewTapped() {}

    override func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        tableView.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
        self.tableView.reloadData()
    }
}
