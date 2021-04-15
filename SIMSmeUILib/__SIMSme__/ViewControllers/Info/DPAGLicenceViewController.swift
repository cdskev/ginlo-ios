//
//  DPAGLicenceViewController.swift
//  SIMSme
//
//  Created by RBU on 27/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGLicenceViewController: DPAGViewControllerBackground {
    private var scrollView: UIScrollView = UIScrollView()
    private var stackView: UIStackView = UIStackView()
    private var titleArray: [String] = []
    private var descriptionArray: [String] = []
    private var attributes: [NSAttributedString.Key: Any] = [:]

    init() {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.parseLisencePlist()

        let itemCount = self.titleArray.count

        for i in 0 ..< itemCount {
            self.addStackView(headline: self.headline(self.titleArray[i]), description: self.extendedDescription(self.descriptionArray[i]))
        }

        let paragraphStyles = NSMutableParagraphStyle()

        paragraphStyles.alignment = .justified // To justified text
        // paragraphStyles.firstLineHeadIndent      = 5    // IMP: must have a value to make it work
        self.attributes = [.paragraphStyle: paragraphStyles]

        self.prepareViews()

        self.title = DPAGLocalizedString("settings.license")
    }

    private func prepareViews() {
        let viewRoot = UIView()

        viewRoot.translatesAutoresizingMaskIntoConstraints = false

        self.view.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        self.view.addSubview(viewRoot)
        self.view.addConstraintsFillSafeArea(subview: viewRoot)

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false

        viewRoot.addSubview(self.scrollView)

        viewRoot.addConstraintsFill(subview: self.scrollView)

        self.scrollView.addSubview(self.stackView)
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addConstraintsFill(subview: self.stackView, padding: 16)

        // self.automaticallyAdjustsScrollViewInsets = true

        self.stackView.distribution = .fill
        self.stackView.alignment = .fill
        self.stackView.axis = .vertical
        self.stackView.spacing = 20
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

    private func parseLisencePlist() {
        if let resPath = Bundle(for: type(of: self)).resourcePath {
            let pathToPlist = String(format: "%@/licenses.plist", resPath)

            if let plistDictionary = NSDictionary(contentsOfFile: pathToPlist), let titles = plistDictionary["licenseTitle"] as? [String], let descriptions = plistDictionary["licenseDescription"] as? [String] {
                self.titleArray = titles
                self.descriptionArray = descriptions
            }
        }
    }

    private func extendedDescription(_ description: String) -> UITextView {
        let plistDesc = UITextView()

        let attributedString = NSAttributedString(string: description, attributes: self.attributes)

        plistDesc.attributedText = attributedString
        plistDesc.font = UIFont.kFontFootnote
        plistDesc.textColor = DPAGColorProvider.shared[.textFieldText]
        plistDesc.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        plistDesc.translatesAutoresizingMaskIntoConstraints = false
        plistDesc.isEditable = false
        NSLayoutConstraint.activate([plistDesc.constraintHeight(171)])

        return plistDesc
    }

    private func addStackView(headline: UILabel, description: UIView) {
        let stackView = UIStackView()

        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.axis = .vertical
        stackView.spacing = 13

        stackView.addArrangedSubview(headline)
        stackView.addArrangedSubview(description)

        self.stackView.addArrangedSubview(stackView)
    }

    private func headline(_ title: String) -> UILabel {
        let plistTitleLabel = UILabel()

        plistTitleLabel.text = title
        plistTitleLabel.lineBreakMode = .byWordWrapping
        plistTitleLabel.numberOfLines = 0
        plistTitleLabel.font = UIFont.kFontHeadline
        plistTitleLabel.textColor = DPAGColorProvider.shared[.labelText]

        return plistTitleLabel
    }
}
