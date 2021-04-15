//
//  Date+Extensions.swift
//  SIMSmeCore
//
//  Created by Evgenii Kononenko on 17.07.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

// swiftlint:disable function_default_parameter_at_end
import Foundation

extension Date {
    private static let calendar = Calendar.current

    static func dateDifference(startDate: Date, endDate: Date = Date(), component: Calendar.Component) -> Int {
        let difference = self.dateDifference(startDate: startDate, endDate: endDate, components: [component])
        return difference.value(for: component) ?? 0
    }

    static func dateDifference(startDate: Date, endDate: Date = Date(), components: [Calendar.Component]) -> DateComponents {
        if components.isEmpty {
            return DateComponents()
        }

        let components = Set(components)
        let difference = Date.calendar.dateComponents(components, from: startDate, to: endDate)
        return difference
    }

    private static let DATE_COMPONENTS: Set<Calendar.Component> = [.year, .month, .day, .weekOfYear, .hour, .minute, .second, .weekday, .weekdayOrdinal]

    private static let D_MINUTE = 60
    private static let D_HOUR = 3_600
    private static let D_DAY = 86_400
    private static let D_WEEK = 604_800
    private static let D_YEAR = 31_556_926

    private func isEqualToDateIgnoringTime(_ aDate: Date) -> Bool {
        let components1 = Calendar.current.dateComponents(Date.DATE_COMPONENTS, from: self)
        let components2 = Calendar.current.dateComponents(Date.DATE_COMPONENTS, from: aDate)

        return components1.year == components2.year && components1.month == components2.month && components1.day == components2.day
    }

    public func isToday() -> Bool {
        self.isEqualToDateIgnoringTime(Date())
    }

    public func isTomorrow() -> Bool {
        self.isEqualToDateIgnoringTime(Date.tomorrow)
    }

    public func isYesterday() -> Bool {
        self.isEqualToDateIgnoringTime(Date.yesterday)
    }

    public static var tomorrow: Date {
        Date.withDaysFromNow(1)
    }

    public static var yesterday: Date {
        Date.withDaysFromNow(-1)
    }

    public static func withDaysFromNow(_ days: Int) -> Date {
        Date().addingDays(days)
    }

    public func addingDays(_ days: Int) -> Date {
        let aTimeInterval = self.timeIntervalSinceReferenceDate + TimeInterval(Date.D_DAY * days)
        let newDate = Date(timeIntervalSinceReferenceDate: aTimeInterval)

        return newDate
    }

    public func addingHours(_ dHours: Int) -> Date {
        let aTimeInterval = self.timeIntervalSinceReferenceDate + TimeInterval(Date.D_HOUR * dHours)
        let newDate = Date(timeIntervalSinceReferenceDate: aTimeInterval)

        return newDate
    }

    public func addingMinutes(_ minutes: Int) -> Date {
        let aTimeInterval = self.timeIntervalSinceReferenceDate + TimeInterval(Date.D_MINUTE * minutes)
        let newDate = Date(timeIntervalSinceReferenceDate: aTimeInterval)

        return newDate
    }

    public func isEarlierThan(date: Date) -> Bool {
        self.compare(date) == .orderedAscending
    }

    public func isLaterThan(date: Date) -> Bool {
        self.compare(date) == .orderedDescending
    }

    public var isInFuture: Bool {
        self.isLaterThan(date: Date())
    }

    public var isInPast: Bool {
        self.isEarlierThan(date: Date())
    }

    public func days(before date: Date) -> Int {
        let ti = date.timeIntervalSince(self)

        return Int(ti / TimeInterval(Date.D_DAY))
    }

    public func days(after date: Date) -> Int {
        let ti = self.timeIntervalSince(date)

        return Int(ti / TimeInterval(Date.D_DAY))
    }

    public func minutes(before aDate: Date) -> Int {
        let ti = Double(aDate.timeIntervalSince(self))

        return Int(ti / Double(Date.D_MINUTE))
    }

    public func distanceInDays(to anotherDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: anotherDate)

        return components.day ?? 0
    }

    public func isEarlierThan(_ aDate: Date) -> Bool {
        self.compare(aDate) == .orderedAscending
    }
}
