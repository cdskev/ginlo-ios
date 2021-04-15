//
//  DPAGContactsListHeaderView.swift
//  SIMSmeUIContactsLib
//
//  Created by Robert Burchert on 27.11.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGContactsListHeaderViewProtocol: AnyObject {
    var searchController: UISearchController? { get set }

    func setCount(_ count: Int, source: String, showSearch: Bool)
    func setPreferredMaxLayoutWidth(_ width: CGFloat)
}

class DPAGContactsListHeaderView: UIView, DPAGContactsListHeaderViewProtocol {
    weak var searchController: UISearchController?

    @IBOutlet private var labelCount: UILabel! {
        didSet {
            self.labelCount.font = UIFont.kFontTitle1
            self.labelCount.textColor = DPAGColorProvider.shared[.labelText]
            self.labelCount.textAlignment = .center
        }
    }

    @IBOutlet private var labelSource: UILabel! {
        didSet {
            self.labelSource.font = UIFont.kFontHeadline
            self.labelSource.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSource.textAlignment = .center
            self.labelSource.numberOfLines = 0
        }
    }

    @IBOutlet private var labelSearch: UILabel! {
        didSet {
            self.labelSearch.font = UIFont.kFontSubheadline
            self.labelSearch.textColor = DPAGColorProvider.shared[.labelText]
            self.labelSearch.textAlignment = .center
            self.labelSearch.numberOfLines = 0
            self.labelSearch.text = DPAGLocalizedString("settings.companyprofile.contactsoverview.searchLabel")
        }
    }

    @IBOutlet private var btnSearch: UIButton! {
        didSet {
            self.btnSearch.configureButton()
            self.btnSearch.setTitle(DPAGLocalizedString("settings.companyprofile.contactsoverview.searchButton.title"), for: .normal)
            self.btnSearch.addTargetClosure { [weak self] _ in
                self?.searchController?.searchBar.becomeFirstResponder()
            }
        }
    }

    func setCount(_ count: Int, source: String, showSearch: Bool) {
        let contactKey = count == 1 ? "settings.companyprofile.contactsoverview.counterLabel.singular" : "settings.companyprofile.contactsoverview.counterLabel"
        self.labelCount.text = String(format: DPAGLocalizedString(contactKey), "\(count)")
        self.labelSource.text = String(format: DPAGLocalizedString("settings.companyprofile.contactsoverview.sourceLabel"), source)

        self.labelSearch.superview?.isHidden = (showSearch == false)
    }

    func setPreferredMaxLayoutWidth(_ width: CGFloat) {
        self.labelCount.preferredMaxLayoutWidth = width - 32
        self.labelSearch.preferredMaxLayoutWidth = width - 32
        self.labelSource.preferredMaxLayoutWidth = width - 32

        let height = self.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        var headerFrame = self.frame

        // Comparison necessary to avoid infinite loop
        if height != headerFrame.size.height {
            headerFrame.size.height = height
            self.frame = headerFrame
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelCount.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSource.textColor = DPAGColorProvider.shared[.labelText]
                self.labelSearch.textColor = DPAGColorProvider.shared[.labelText]
                self.backgroundColor = .clear
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
