//
//  DPAGConstantsGlobal.swift
// ginlo
//
//  Created by RBU on 10/11/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

public extension DPAGConstantsGlobal {
    static let kButtonHeight: CGFloat = 48
    static let kPadding: CGFloat = 20
    static let kContactCellHeight: CGFloat = 84

    static let kTableSectionHeaderGroupedHeight: CGFloat = 38

    static let kDurationHideLogin: TimeInterval = 0.2

    static let kBadgeSize: CGFloat = 20
    static let kBadgeSizeHeader: CGFloat = 28
}

public func DPAGLocalizedString(_ key: String, comment: String? = nil) -> String {
    DPAGFunctionsGlobal.DPAGLocalizedString(key, comment: comment)
}

public class UIKeyboardAnimationInfo {
    public let animationDuration: TimeInterval
    public let animationCurve: UIView.AnimationCurve
    public let keyboardRectEnd: CGRect

    public init(aNotification: Notification?, view: UIView) {
        if let userInfo = aNotification?.userInfo {
            DPAGLog("keyboard animation: %@", userInfo)

            if let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
                self.keyboardRectEnd = view.convert(keyboardEndFrame, to: nil)
            } else {
                self.keyboardRectEnd = .zero
            }

            if let durationInfo = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber {
                self.animationDuration = TimeInterval(durationInfo.doubleValue)
            } else {
                self.animationDuration = TimeInterval(UINavigationController.hideShowBarDuration)
            }

            if let animationCurveInfo = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber, let aCurve = UIView.AnimationCurve(rawValue: animationCurveInfo.intValue) {
                self.animationCurve = aCurve
            } else {
                self.animationCurve = UIView.AnimationCurve.easeInOut
            }
        } else {
            self.animationDuration = TimeInterval(UINavigationController.hideShowBarDuration)
            self.animationCurve = UIView.AnimationCurve.easeInOut
            self.keyboardRectEnd = CGRect.zero
        }
    }
}
