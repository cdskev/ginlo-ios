//
//  ClosureWrapper.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public typealias UIButtonTargetClosure = (UIButton) -> Void
public typealias UIStepperTargetClosure = (UIStepper) -> Void
public typealias UISwitchTargetClosure = (UISwitch) -> Void
public typealias UISegmentedControlTargetClosure = (UISegmentedControl) -> Void
public typealias UIDatePickerTargetClosure = (UIDatePicker) -> Void

class ClosureWrapper: NSObject {
    fileprivate var closureButton: UIButtonTargetClosure?
    fileprivate var closureStepper: UIStepperTargetClosure?
    fileprivate var closureSwitch: UISwitchTargetClosure?
    fileprivate var closureSegmentedControl: UISegmentedControlTargetClosure?
    fileprivate var closureDatePicker: UIDatePickerTargetClosure?

    init(closureButton: @escaping UIButtonTargetClosure) {
        self.closureButton = closureButton
    }

    init(closureStepper: @escaping UIStepperTargetClosure) {
        self.closureStepper = closureStepper
    }

    init(closureSwitch: @escaping UISwitchTargetClosure) {
        self.closureSwitch = closureSwitch
    }

    init(closureSegmentedControl: @escaping UISegmentedControlTargetClosure) {
        self.closureSegmentedControl = closureSegmentedControl
    }

    init(closureDatePicker: @escaping UIDatePickerTargetClosure) {
        self.closureDatePicker = closureDatePicker
    }
}

extension UIButton {
    private enum AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    private var targetClosure: UIButtonTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ClosureWrapper else { return nil }
            return closureWrapper.closureButton
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.targetClosure, ClosureWrapper(closureButton: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    public func addTargetClosure(closure: @escaping UIButtonTargetClosure) {
        self.targetClosure = closure
        self.addTarget(self, action: #selector(UIButton.closureAction), for: .touchUpInside)
    }

    @objc
    private func closureAction() {
        guard let targetClosure = self.targetClosure else { return }
        targetClosure(self)
    }
}

extension UIStepper {
    private enum AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    private var targetClosure: UIStepperTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ClosureWrapper else { return nil }
            return closureWrapper.closureStepper
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.targetClosure, ClosureWrapper(closureStepper: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    public func addTargetClosure(closure: @escaping UIStepperTargetClosure) {
        self.targetClosure = closure
        self.addTarget(self, action: #selector(UIStepper.closureAction), for: .valueChanged)
    }

    @objc
    private func closureAction() {
        guard let targetClosure = self.targetClosure else { return }
        targetClosure(self)
    }
}

public extension UISwitch {
    private enum AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    private var targetClosure: UISwitchTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ClosureWrapper else { return nil }
            return closureWrapper.closureSwitch
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.targetClosure, ClosureWrapper(closureSwitch: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func addTargetClosure(closure: @escaping UISwitchTargetClosure) {
        self.targetClosure = closure
        self.addTarget(self, action: #selector(UISwitch.closureAction), for: .valueChanged)
    }

    @objc
    private func closureAction() {
        guard let targetClosure = self.targetClosure else { return }
        targetClosure(self)
    }
}

public extension UISegmentedControl {
    private enum AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    private var targetClosure: UISegmentedControlTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ClosureWrapper else { return nil }
            return closureWrapper.closureSegmentedControl
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.targetClosure, ClosureWrapper(closureSegmentedControl: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func addTargetClosure(closure: @escaping UISegmentedControlTargetClosure) {
        self.targetClosure = closure
        self.addTarget(self, action: #selector(UISegmentedControl.closureAction), for: .valueChanged)
    }

    @objc
    private func closureAction() {
        guard let targetClosure = self.targetClosure else { return }
        targetClosure(self)
    }
}

public extension UIDatePicker {
    private enum AssociatedKeys {
        static var targetClosure = "targetClosure"
    }

    private var targetClosure: UIDatePickerTargetClosure? {
        get {
            guard let closureWrapper = objc_getAssociatedObject(self, &AssociatedKeys.targetClosure) as? ClosureWrapper else { return nil }
            return closureWrapper.closureDatePicker
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.targetClosure, ClosureWrapper(closureDatePicker: newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func addTargetClosure(closure: @escaping UIDatePickerTargetClosure) {
        self.targetClosure = closure
        self.addTarget(self, action: #selector(UIDatePicker.closureAction), for: .valueChanged)
    }

    @objc
    private func closureAction() {
        guard let targetClosure = self.targetClosure else { return }
        targetClosure(self)
    }
}
