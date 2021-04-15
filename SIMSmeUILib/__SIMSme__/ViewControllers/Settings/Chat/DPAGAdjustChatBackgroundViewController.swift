//
//  DPAGAdjustChatBackgroundViewController.swift
//  SIMSme
//
//  Created by RBU on 26/10/15.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGAdjustChatBackgroundViewController: DPAGViewController {
    private var image: UIImage?
    private var imageLandscape: UIImage?

    private weak var imageView: UIImageView?
    private weak var delegate: DPAGAdjustChatBackgroundDelegate?

    init(image: UIImage, imageLandscape: UIImage?, delegate: DPAGAdjustChatBackgroundDelegate?) {
        self.image = image
        self.imageLandscape = imageLandscape
        self.delegate = delegate

        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        self.setUpGui()
    }

    private func setUpGui() {
        let imageView = UIImageView(frame: self.view.bounds)

        imageView.contentMode = .scaleAspectFill
        imageView.image = self.image
        imageView.clipsToBounds = true
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.view.addSubview(imageView)

        self.imageView = imageView

        self.setRightBarButtonItem(image: DPAGImageProvider.shared[.kImageBarButtonNavCheck], action: #selector(chooseImagePressed), accessibilityLabelIdentifier: "navigation.done")
    }

    @objc
    private func chooseImagePressed() {
        if let image = self.image {
            self.delegate?.didSelectImage(image, imageLandscape: self.imageLandscape, from: self.navigationController, fromAlbum: true)
            self.image = nil
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in

            let orientation = AppConfig.statusBarOrientation()

            self?.updateCustomBackgroundToOrientation(orientation)

        }, completion: nil)
    }

    private func updateCustomBackgroundToOrientation(_ io: UIInterfaceOrientation) {
        if self.imageLandscape == nil {
            return
        }

        if let customBackgroundImage = io.isPortrait ? self.image : self.imageLandscape {
            self.imageView?.image = customBackgroundImage
        }
    }
}
