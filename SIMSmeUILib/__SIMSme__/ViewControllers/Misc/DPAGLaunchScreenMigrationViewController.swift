//
//  DPAGLaunchScreenMigrationViewController.swift
// ginlo
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGLaunchScreenMigrationViewController: DPAGViewController {
    @IBOutlet var labelInfo: UILabel! {
        didSet {
            self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
            self.labelInfo.isHidden = false
            self.labelInfo.text = "" // DPAGLocalizedString("migration.title")
            self.labelInfo.numberOfLines = 0
        }
    }

    @IBOutlet var activityIndicator: UIActivityIndicatorView! {
        didSet {
            self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
        }
    }

    init() {
        let nibName = "DPAGLaunchScreenMigrationViewController"

        super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let launchScreenStoryboard = UIStoryboard(name: "Launch Screen", bundle: nil)
        if let launchScreenViewController = launchScreenStoryboard.instantiateInitialViewController(),
            let launchScreenView = launchScreenViewController.view {
            launchScreenView.translatesAutoresizingMaskIntoConstraints = false
            self.view.insertSubview(launchScreenView, at: 0)
            self.view.addConstraintsFill(subview: launchScreenView)
            self.addChild(launchScreenViewController)
        }
    }
    
    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.labelInfo.textColor = DPAGColorProvider.shared[.labelText]
                self.activityIndicator.color = DPAGColorProvider.shared[.labelText]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }
}
