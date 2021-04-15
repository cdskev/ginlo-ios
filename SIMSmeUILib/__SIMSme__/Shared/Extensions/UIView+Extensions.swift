//
//  UIView+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public extension UIView {
    func superview<T>(of type: T.Type) -> T? {
        self.superview as? T ?? self.superview.flatMap { $0.superview(of: type) }
    }

    func subviews<T>(of type: T.Type) -> [T] {
        var retVal: [T] = []

        for subview in self.subviews {
            retVal.append(contentsOf: subview.subviews(of: type))
        }
        if let view = self as? T {
            retVal.append(view)
        }
        return retVal
    }

    func subview<T>(of type: T.Type) -> T? {
        self.subviews(of: type).first
    }

    // MARK: - LayoutConstraints

    func addConstraintsFill(subview: UIView, padding: CGFloat = 0) {
        NSLayoutConstraint.activate(self.constraintsFill(subview: subview, padding: padding))
    }

    func constraintsFill(subview: UIView, padding: CGFloat = 0) -> [NSLayoutConstraint] {
        [
            self.centerXAnchor.constraint(equalTo: subview.centerXAnchor),
            self.topAnchor.constraint(equalTo: subview.topAnchor, constant: -padding),
            self.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding),
            self.leadingAnchor.constraint(equalTo: subview.leadingAnchor, constant: -padding),
            self.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding)
        ]
    }

    func addConstraintsFillSafeArea(subview: UIView, padding: CGFloat = 0) {
        NSLayoutConstraint.activate(self.constraintsFillSafeArea(subview: subview, padding: padding))
    }

    func constraintsFillSafeArea(subview: UIView, padding: CGFloat = 0) -> [NSLayoutConstraint] {
        [
            self.safeAreaLayoutGuide.centerXAnchor.constraint(equalTo: subview.centerXAnchor),
            self.safeAreaLayoutGuide.topAnchor.constraint(equalTo: subview.topAnchor, constant: -padding),
            self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding),
            self.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: subview.leadingAnchor, constant: -padding),
            self.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding)
        ]
    }

    func addConstraintsStackingBottom(subview: UIView, padding: CGFloat = 0) {
        NSLayoutConstraint.activate(self.constraintsStackingBottom(subview: subview, padding: padding))
    }

    func constraintsStackingBottom(subview: UIView, padding: CGFloat = 0) -> [NSLayoutConstraint] {
        [
            self.centerXAnchor.constraint(equalTo: subview.centerXAnchor),
            self.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding),
            self.leadingAnchor.constraint(equalTo: subview.leadingAnchor, constant: -padding),
            self.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding)
        ]
    }

    func constraintTop(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.topAnchor.constraint(equalTo: subview.topAnchor, constant: -padding)
        constraint.priority = priority
        return constraint
    }

    func constraintTopSafeArea(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.safeAreaLayoutGuide.topAnchor.constraint(equalTo: subview.topAnchor, constant: -padding)
        constraint.priority = priority
        return constraint
    }

    func constraintBottom(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding)
        constraint.priority = priority
        return constraint
    }

    func constraintBottomSafeArea(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: subview.bottomAnchor, constant: padding)
        constraint.priority = priority
        return constraint
    }

    func constraintBottomGreaterThan(subview: UIView, padding: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.bottomAnchor.constraint(greaterThanOrEqualTo: subview.bottomAnchor, constant: padding)
        return constraint
    }

    func constraintBottomSafeAreaGreaterThan(subview: UIView, padding: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.safeAreaLayoutGuide.bottomAnchor.constraint(greaterThanOrEqualTo: subview.bottomAnchor, constant: padding)
        return constraint
    }

    func constraintLeading(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.leadingAnchor.constraint(equalTo: subview.leadingAnchor, constant: -padding)
        constraint.priority = priority
        return constraint
    }

    func constraintTrailing(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding)
        constraint.priority = priority
        return constraint
    }

    func constraintLeadingSafeArea(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: subview.leadingAnchor, constant: -padding)
        constraint.priority = priority
        return constraint
    }

    func constraintTrailingSafeArea(subview: UIView, padding: CGFloat = 0, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: subview.trailingAnchor, constant: padding)
        constraint.priority = priority
        return constraint
    }

    func constraintCenterX(subview: UIView) -> NSLayoutConstraint {
        self.centerXAnchor.constraint(equalTo: subview.centerXAnchor)
    }

    func constraintCenterY(subview: UIView) -> NSLayoutConstraint {
        self.centerYAnchor.constraint(equalTo: subview.centerYAnchor)
    }

    func constraintHeight(_ height: CGFloat, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.heightAnchor.constraint(equalToConstant: height)

        constraint.priority = priority

        return constraint
    }

    func constraintWidth(_ width: CGFloat, priority: UILayoutPriority = UILayoutPriority.required) -> NSLayoutConstraint {
        let constraint = self.widthAnchor.constraint(equalToConstant: width)

        constraint.priority = priority

        return constraint
    }

    func constraintBottomToTop(bottomView: UIView, topView: UIView, padding: CGFloat = 0) -> NSLayoutConstraint {
        bottomView.bottomAnchor.constraint(equalTo: topView.topAnchor, constant: -padding)
    }

    func constraintTrailingLeading(trailingView: UIView, leadingView: UIView, padding: CGFloat = 0) -> NSLayoutConstraint {
        trailingView.trailingAnchor.constraint(equalTo: leadingView.leadingAnchor, constant: -padding)
    }
}

public extension UIView.AnimationOptions {
    init(curve: UIView.AnimationCurve) {
        switch curve {
        case .easeIn:
            self = [.curveEaseIn, .beginFromCurrentState]
        case .easeOut:
            self = [.curveEaseOut, .beginFromCurrentState]
        case .easeInOut:
            self = [.curveEaseInOut, .beginFromCurrentState]
        default:
            self = [.curveLinear, .beginFromCurrentState]
        }
    }
}
