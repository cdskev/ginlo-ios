//
//  DPAGInfoOverviewViewController.swift
// ginlo
//
//  Created by RBU on 27/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGInfoOverviewViewController: DPAGSettingsTableViewControllerBase, DPAGViewControllerNavigationTitleBig {
  private enum Rows: Int, CaseCountable {
    case faq,
         support,
         about,
         privacy,
         terms,
         license,
         companyDetails
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.navigationItem.title = DPAGLocalizedString("settings.title.information")
  }
  
  private func isGerman() -> Bool {
    Locale.current.identifier == "de_DE"
  }
  
  fileprivate func isShowingDPAGApps() -> Bool {
    (self.isGerman() && DPAGApplicationFacade.preferences.showDPAGApps) || (DPAGApplicationFacade.preferences.isWhiteLabelBuild == false && (DPAGApplicationFacade.preferences.serverConfiguration?[DPAGSettingServerConfiguration.kShowBusinessPromotion.rawValue] != nil))
  }
}

extension DPAGInfoOverviewViewController: UITableViewDataSource {
  func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    Rows.caseCount
  }
  
  func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell? = self.cellForDisclosureRow(indexPath)
    cell?.detailTextLabel?.attributedText = nil
    switch Rows.forIndex(indexPath.row) {
      case .faq:
        cell?.textLabel?.text = DPAGLocalizedString("settings.faq")
        cell?.accessibilityIdentifier = "cell-settings.faq"
      case .about:
        cell?.textLabel?.text = DPAGLocalizedString("settings.aboutSimsme")
        cell?.accessibilityIdentifier = "cell-settings.aboutSimsme"
      case .privacy:
        cell?.textLabel?.text = DPAGLocalizedString("settings.privacy")
        cell?.accessibilityIdentifier = "cell-settings.privacy"
      case .terms:
        cell?.textLabel?.text = DPAGLocalizedString("settings.termsandcondition")
        cell?.accessibilityIdentifier = "cell-settings.termsandcondition"
      case .license:
        cell?.textLabel?.text = DPAGLocalizedString("settings.license")
        cell?.accessibilityIdentifier = "cell-settings.license"
      case .companyDetails:
        cell?.textLabel?.text = DPAGLocalizedString("settings.companydetails")
        cell?.accessibilityIdentifier = "cell-settings.companydetails"
      case .support:
        cell?.textLabel?.text = DPAGLocalizedString("settings.support")
        cell?.accessibilityIdentifier = "cell-settings.support"
    }
    return cell ?? self.cellForHiddenRow(indexPath)
  }
  
  func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
    0
  }
}

extension DPAGInfoOverviewViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    var controller: UIViewController?
    switch Rows.forIndex(indexPath.row) {
      case .faq:
        AppConfig.openURL(URL(string: DPAGLocalizedString("settings.faq.url")))
      case .about:
        controller = DPAGApplicationFacadeUISettings.aboutSimsMeVC()
      case .privacy:
        let urlPrivacy = DPAGLocalizedString("settings.privacy.url")
        AppConfig.openURL(URL(string: urlPrivacy))
      case .terms:
        let urlTermsAndConditions = DPAGLocalizedString("settings.termsandcondition.url")
        AppConfig.openURL(URL(string: urlTermsAndConditions))
      case .license:
        controller = DPAGApplicationFacadeUISettings.licenceVC()
      case .companyDetails:
        let urlImprint = DPAGLocalizedString("settings.companydetails.URL")
        AppConfig.openURL(URL(string: urlImprint))
      case .support:
        controller = DPAGApplicationFacadeUISettings.supportVC()
    }
    if let controller = controller {
      self.navigationController?.pushViewController(controller, animated: true)
    }
  }
  
  func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//    switch Rows.forIndex(indexPath.row) {
//      case .faq:
//        guard DPAGApplicationFacade.preferences.isBaMandant else { return 0 }
//      case .about, .privacy, .terms, .license, .companyDetails, .support:
//        break
//    }
    return UITableView.automaticDimension
  }
}
