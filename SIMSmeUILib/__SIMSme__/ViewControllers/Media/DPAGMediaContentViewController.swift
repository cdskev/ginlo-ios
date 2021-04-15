//
//  DPAGMediaContentViewController.swift
//  SIMSme
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGMediaContentViewController: DPAGViewControllerBackground, DPAGMediaContentViewControllerProtocol {
    let mediaResource: DPAGMediaResource
    weak var customDelegate: DPAGMediaDetailViewDelegate?
    var index: Int

    init(index: Int, mediaResource: DPAGMediaResource) {
        self.index = index
        self.mediaResource = mediaResource
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUpGui()
        self.updateMediaResource()
    }

    func setUpGui() {}

    func updateMediaResource() {}

    @objc
    func handleSingleTap(_: UITapGestureRecognizer) {
        self.customDelegate?.contentViewRecognizedSingleTap(self)
    }

    func preparePresentationWithZoomingRect(_: CGRect) {}
    func animatePresentationZoomingRect(_: CGRect) {}
    func completePresentationZoomingRect(_: CGRect) {}
    func prepareDismissalWithZoomingRect(_: CGRect) {}
    func animateDismissalZoomingRect(_: CGRect) {}
    func completeDismissalZoomingRect(_: CGRect) {}
    func mediaResourceShown() -> DPAGMediaResource? { self.mediaResource }
}
