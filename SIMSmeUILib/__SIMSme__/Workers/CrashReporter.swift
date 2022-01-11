//
//  CrashReporter.swift
//  SIMSmeUILib
//
//  Created by Maxime Bentin on 17.05.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation
import Sentry
import SIMSmeCore

public protocol CrashReporter {
  func startReporting() throws
}

public class CrashReporterImpl: CrashReporter {
  private let dsn: String
  
  public init(dsn: String) {
    self.dsn = dsn
  }
  
  public func startReporting() throws {
    SentrySDK.start { options in
      if let dictionary = Bundle.main.infoDictionary, let bundleId = dictionary["CFBundleIdentifier"] as? String, let shortVersion = dictionary["CFBundleShortVersionString"] as? String {
        options.releaseName = bundleId + "-" + shortVersion
      }
      // if we can't get the shortVersion from Info.plist, the releaseName will be something like "apps.ginloba@3.6.2+96350"
      options.dsn = self.dsn
      options.debug = true
      options.beforeSend = { event in
        if event.message.contains("NSInternalInconsistencyException") {
          NSLog("NSInternalInconsistencyException")
          return nil
        }
        return event
      }
    }
    SentrySDK.setUser(nil)
  }
}
