//
//  DPAGShowDestructionTextViewController.swift
// ginlo
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGShowDestructionTextViewControllerProtocol: DPAGDestructionViewControllerProtocol {}

class DPAGShowDestructionTextViewController: DPAGDestructionViewController, UITableViewDataSource, UITableViewDelegate, DPAGChatStreamMenuDelegate, DPAGShowDestructionTextViewControllerProtocol {
    static let cellIdentifierTextLeft = "cellIdentifierTextLeft"
    static let cellIdentifierTextRight = "cellIdentifierTextRight"
    static let cellIdentifierPlaceHolder = "cellIdentifierPlaceHolder"

    var touchStart: CGFloat = 0
    var touchDifference: CGFloat = 0

    weak var longPressCell: (UITableViewCell & DPAGMessageCellProtocol)?

    var tableView: UITableView = UITableView(frame: .zero, style: .plain)

    lazy var sizingCellLeft: (UITableViewCell & DPAGSimpleMessageCellProtocol)? = {
        self.tableView.dequeueReusableCell(withIdentifier: DPAGShowDestructionTextViewController.cellIdentifierTextLeft) as? (UITableViewCell & DPAGSimpleMessageCellProtocol)
    }()

    lazy var sizingCellRight: (UITableViewCell & DPAGSimpleMessageCellProtocol)? = {
        self.tableView.dequeueReusableCell(withIdentifier: DPAGShowDestructionTextViewController.cellIdentifierTextRight) as? (UITableViewCell & DPAGSimpleMessageCellProtocol)
    }()

    override init(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String) {
        super.init(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.view.isMultipleTouchEnabled = false

        self.setUpTextView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.configureSelfDestruction()

        self.readyToStart = true
    }

    override func removeContent() {
        self.tableView.removeFromSuperview()
    }

    func setUpTextView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageSimpleLeftNib(), forCellReuseIdentifier: DPAGShowDestructionTextViewController.cellIdentifierTextLeft)
        self.tableView.register(DPAGApplicationFacadeUI.cellMessageSimpleRightNib(), forCellReuseIdentifier: DPAGShowDestructionTextViewController.cellIdentifierTextRight)

        self.tableView.frame = self.contentView.bounds
        self.contentView.addSubview(self.tableView)

        self.tableView.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.isScrollEnabled = false

        [
            self.contentView.constraintLeading(subview: self.tableView),
            self.contentView.constraintTrailing(subview: self.tableView),
            self.contentView.constraintBottomToTop(bottomView: self.tableView, topView: self.selfdestructionFooter),
            self.contentView.constraintTop(subview: self.tableView)
        ].activate()
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.tableView.backgroundColor = DPAGColorProvider.shared[.chatDetailsBackground]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    func numberOfSections(in _: UITableView) -> Int { 1 }
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int { 3 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 || indexPath.row == 2 {
            if let cell = tableView.dequeueReusableCell(withIdentifier: DPAGShowDestructionTextViewController.cellIdentifierPlaceHolder) {
                return cell
            }

            let cell = UITableViewCell(style: .default, reuseIdentifier: DPAGShowDestructionTextViewController.cellIdentifierPlaceHolder)

            cell.accessibilityIdentifier = "cellSpacer-\(indexPath.row)"
            cell.backgroundColor = UIColor.clear
            cell.contentView.backgroundColor = UIColor.clear
            cell.selectionStyle = .none

            return cell
        } else if let cellText = tableView.dequeueReusableCell(withIdentifier: self.decryptedMessage.isOwnMessage ? DPAGShowDestructionTextViewController.cellIdentifierTextRight : DPAGShowDestructionTextViewController.cellIdentifierTextLeft) as? (UITableViewCell & DPAGSimpleMessageCellProtocol) {
            cellText.accessibilityIdentifier = "cell-text"
            cellText.configureCellWithMessage(self.decryptedMessage, forHeightMeasurement: false)
            cellText.streamMenuDelegate = self

            cellText.setNeedsUpdateConstraints()
            cellText.updateConstraintsIfNeeded()

            return cellText
        }

        return UITableViewCell(style: .default, reuseIdentifier: "Dummy")
    }

    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var cellHeight = self.heightForMessageCell()

        if indexPath.row == 0 || indexPath.row == 2 {
            let insets = self.tableView.contentInset
            let heightToFill = (self.tableView.frame.size.height - insets.top - insets.bottom) - cellHeight

            if heightToFill <= 0 {
                cellHeight = 1
            } else {
                cellHeight = heightToFill / 2
            }
        }
        return cellHeight
    }

    func heightForMessageCell() -> CGFloat {
        if let sizingCell = self.decryptedMessage.isOwnMessage ? self.sizingCellRight : self.sizingCellLeft {
            sizingCell.configureCellWithMessage(self.decryptedMessage, forHeightMeasurement: true)
            sizingCell.setCellContactLabel(self.decryptedMessage.nickName, textColor: nil)

            sizingCell.setNeedsUpdateConstraints()
            sizingCell.updateConstraintsIfNeeded()

            return sizingCell.calculateHeightForConfiguredSizingCellWidth(self.tableView.bounds.width)
        }
        return 0
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if !self.hasSelfDestructionStarted, self.readyToStart {
            if !self.messageDeleted, self.decryptedMessage.sendOptions?.countDownSelfDestruction != nil {
                self.countDownStarted()
            }

            self.updateTouchState(true)

            if !self.hasSelfDestructionStarted {
                if !(self.countdownTimer?.isValid ?? false) {
                    self.countdownTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateCountdownLabel), userInfo: nil, repeats: true)
                }
                if !(self.scrollTimer?.isValid ?? false), self.tableView.contentSize.height > self.tableView.frame.size.height {
                    self.scrollTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(scroll), userInfo: nil, repeats: true)

                    if let aTouch = touches.first {
                        self.touchStart = aTouch.location(in: self.view).y
                    }
                }
            }
            self.selfdestructionFooter.isHidden = false
        }
    }

    @objc
    func scroll() {
        if self.touchDifference > 20 {
            var scrollPoint = self.tableView.contentOffset

            scrollPoint = CGPoint(x: scrollPoint.x, y: max(0, scrollPoint.y - self.touchDifference / 2))

            self.tableView.contentOffset = scrollPoint
        } else if self.touchDifference < -20 {
            let diffMaxScroll = (self.tableView.contentSize.height - self.tableView.frame.size.height + self.tableView.contentInset.top + self.tableView.contentInset.bottom)

            var scrollPoint = self.tableView.contentOffset

            scrollPoint = CGPoint(x: scrollPoint.x, y: min(diffMaxScroll, scrollPoint.y - self.touchDifference / 2))

            self.tableView.contentOffset = scrollPoint
        }
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.touchStart = 0
            self.scrollTimer?.invalidate()
            self.touchDifference = 0

            self.updateTouchState(false)
        }
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.touchStart = 0
            self.scrollTimer?.invalidate()
            self.touchDifference = 0

            self.updateTouchState(false)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            if let touchPoint = touches.first?.location(in: self.view) {
                self.touchDifference = self.touchStart - touchPoint.y
            }
        }
    }

    func longPress(_ recognizer: UILongPressGestureRecognizer, withCell cell: UITableViewCell & DPAGMessageCellProtocol) {
        if recognizer.state == .began {
            self.longPressCell = cell
        }
    }

    func isEditingEnabled() -> Bool {
        false
    }

    func menuItemsForCell(_: DPAGMessageCellProtocol) -> [UIMenuItem] {
        let retVal = [UIMenuItem(title: DPAGLocalizedString("chat.message.action.copy"), action: #selector(copySelectedCell))]

        return retVal
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    @objc
    func copySelectedCell() {
        self.longPressCell?.copySelectedCell()
    }
}
