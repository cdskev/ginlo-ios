//
//  DPAGFormatter.swift
//  SIMSmeCore
//
//  Created by RBU on 08.03.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

public class DPAGFormatter: NSObject {
    public static let dateFilename: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"

        return formatter
    }()

    public static let date: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZ"

        return formatter
    }()

    public static let dateServer: DateFormatter = {
        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZ"

        return formatter
    }()

    public static let fileSize: ByteCountFormatter = {
        let formatter = ByteCountFormatter()

        formatter.countStyle = .binary

        return formatter
    }()

    public static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()

        formatter.doesRelativeDateFormatting = false

        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter
    }()

    public static let messageSectionDateRelativ: DateFormatter = {
        let formatter = DateFormatter()

        formatter.doesRelativeDateFormatting = true

        formatter.dateStyle = .short
        formatter.timeStyle = .none

        return formatter
    }()

    public static var messageSectionDate: DateFormatter = {
        let formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd"

        return formatter
    }()

    public static var dateTimeCitationFormatter: DateFormatter {
        let df = DateFormatter()

        df.doesRelativeDateFormatting = true
        df.dateStyle = .short
        df.timeStyle = .short

        return df
    }
}
