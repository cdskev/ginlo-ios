//
//  TouchTransparentView.swift
//  SIMSme
//
//  Created by RBU on 10/05/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public class TouchTransparentView: UIView {
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        if hitView == self {
            return nil
        }

        return hitView
    }
}
