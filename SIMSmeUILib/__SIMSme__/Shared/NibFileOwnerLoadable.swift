//
//  NibFileOwnerLoadable.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public protocol NibFileOwnerLoadable: AnyObject {
    static var nib: UINib { get }
}

public extension NibFileOwnerLoadable where Self: UIView {
    static var nib: UINib {
        UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    func instantiateFromNib() -> UIView? {
        let view = Self.nib.instantiate(withOwner: self, options: nil).first as? UIView
        return view
    }

    func loadNibContent() {
        guard let view = instantiateFromNib() else {
            fatalError("Failed to instantiate nib \(Self.nib)")
        }
        view.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(view)
        self.addConstraintsFill(subview: view)
    }
}
