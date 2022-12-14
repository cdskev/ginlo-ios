//
//  SettingsContentBuilder.swift
//  SIMSmeUISettingsLib
//

import SIMSmeCore

struct SettingsSection {
  var items: [SettingsRow]
}

struct SettingsRow {
  var name: String
  var selection: SettingsSelection
  var accessibilityId: String?
}

class SettingsContentBuilder {
  func settingsSections() -> [SettingsSection] {
    var sections = [SettingsSection]()
    sections.append(profileSection())
    sections.append(securitySection())
    sections.append(navigationSection())
    sections.append(otherSection())
    sections.append(helpSection())
    sections.append(releaseNotesSection())
    return sections
  }
  
  private func profileSection() -> SettingsSection {
    let section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("settings.accountDetails"), selection: .profileSettings, accessibilityId: "")
    ])
    return section
  }
  
  private func securitySection() -> SettingsSection {
    let section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("settings.password"), selection: .passwordSettings, accessibilityId: "cell-settings.password"),
      SettingsRow(name: DPAGLocalizedString("settings.chatPrivacy"), selection: .privacySettings, accessibilityId: "cell-settings.chatPrivacy")
    ])
    return section
  }
  
  private func navigationSection() -> SettingsSection {
    var section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("contacts.overViewViewControllerTitle"), selection: .contacts, accessibilityId: "cell-contacts"),
      SettingsRow(name: DPAGLocalizedString("settings.mediaFiles"), selection: .files, accessibilityId: "cell-media")
    ])
    if DPAGApplicationFacade.preferences.supportMultiDevice {
      section.items.append(SettingsRow(name: DPAGLocalizedString("settings.devicesTitle"), selection: .devices, accessibilityId: "cell-devices"))
    }
    if DPAGApplicationFacade.preferences.isBaMandant == false {
      section.items.append(SettingsRow(name: DPAGLocalizedString("channel.list.title"), selection: .channels, accessibilityId: "cell-channels"))
    }
    return section
  }
  
  private func otherSection() -> SettingsSection {
    let section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("settings.chat"), selection: .chatsSettings, accessibilityId: "cell-settings.chat"),
      SettingsRow(name: DPAGLocalizedString("settings.autoDownload"), selection: .autoDownloadSettings, accessibilityId: "cell-settings.autoDownload"),
      SettingsRow(name: DPAGLocalizedString("settings.notifications"), selection: .notificationSettings, accessibilityId: "cell-settings.notifications")
    ])
    return section
  }
  
  private func helpSection() -> SettingsSection {
    let section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("settings.title.information"), selection: .help, accessibilityId: "cell-settings.title.information")
    ])
    return section
  }
  
  private func releaseNotesSection() -> SettingsSection {
    let section = SettingsSection(items: [
      SettingsRow(name: DPAGLocalizedString("settings.title.release_notes"), selection: .releaseNotes, accessibilityId: "cell-settings.title.information")
    ])
    return section
  }
}
