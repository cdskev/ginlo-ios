//
//  DPAGShowImageViewController.swift
// ginlo
//
//  Created by RBU on 11/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Photos
import SIMSmeCore
import UIKit

protocol DPAGShowImageViewControllerProtocol: DPAGDestructionViewControllerProtocol {}

class DPAGShowImageViewController: DPAGDestructionViewController, DPAGShowImageViewControllerProtocol {
    private var scrollView: UIScrollView?
    private var imageView: UIImageView?

    private var labelDesc: UILabel?
    private var imageViewDesc: UIImageView?

//    private var image: UIImage
//    private var preview: UIImage?

    private let mediaResource: DPAGMediaResource

    init(messageGuid: String, decMessage: DPAGDecryptedMessage, fromStream streamGuid: String, mediaResource: DPAGMediaResource) {
        self.mediaResource = mediaResource

        super.init(messageGuid: messageGuid, decMessage: decMessage, fromStream: streamGuid)

//        if let content = decMessage.content, let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters)
//        {
//            self.preview = UIImage(data: data)
//        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.setUpImageViewWithImage()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.configureSelfDestruction()

        self.scrollView?.updateScales()
        self.scrollView?.centerScrollViewContents(self.imageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.scrollView?.updateScales()
        self.scrollView?.centerScrollViewContents(self.imageView)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private func setUpGui() {}

    override var destructionFinishedText: String {
        DPAGLocalizedString("chats.showPicture.destroyedLabel")
    }

    override var pleaseTouchText: String {
        DPAGLocalizedString("chats.showPicture.pleaseTouch")
    }

    override func removeContent() {
        self.imageView?.image = nil
        self.imageView?.removeFromSuperview()
        self.imageViewDesc?.removeFromSuperview()
    }

    private func setUpImageViewWithImage() {
        guard let mediaContent = self.mediaResource.mediaContent, let image = UIImage(data: mediaContent) else {
            return
        }

        let scrollView = UIScrollView(frame: self.contentView.bounds)

        self.scrollView = scrollView

        let imageView = UIImageView(image: image)

        self.imageView = imageView
        imageView.contentMode = .scaleAspectFit

        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.addSubview(imageView)

        scrollView.contentSize = image.size
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.clipsToBounds = true
        scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrollView.maximumZoomScale = 3.0

        scrollView.backgroundColor = UIColor.clear
        self.contentView.backgroundColor = UIColor.clear

        scrollView.isScrollEnabled = false
        scrollView.isUserInteractionEnabled = false

        self.contentView.addSubview(scrollView)

        if (self.decryptedMessage.contentDesc?.isEmpty ?? true) == false {
            let labelDesc = UILabel(frame: self.contentView.bounds)
            let imageViewDesc = UIImageView(frame: labelDesc.bounds)

            labelDesc.text = self.decryptedMessage.contentDesc
            labelDesc.font = UIFont.kFontBody
            labelDesc.textColor = .white
            labelDesc.shadowColor = .darkText
            labelDesc.shadowOffset = UIFont.kFontShadowOffset
            labelDesc.numberOfLines = 0
            labelDesc.adjustsFontSizeToFitWidth = true

            let locations: [CGFloat] = [0.0, 0.1, 1.0]
            let components: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0.3, 0, 0, 0, 0.9]

            imageViewDesc.image = UIImage.gradientImage(size: CGSize(width: 20, height: 30), scale: 0, locations: locations, numLocations: locations.count, components: components)

            self.contentView.addSubview(imageViewDesc)
            imageViewDesc.addSubview(labelDesc)

            labelDesc.translatesAutoresizingMaskIntoConstraints = false
            imageViewDesc.translatesAutoresizingMaskIntoConstraints = false

            [
                self.contentView.constraintLeading(subview: imageViewDesc),
                self.contentView.constraintTrailing(subview: imageViewDesc),
                self.contentView.constraintBottomToTop(bottomView: imageViewDesc, topView: self.selfdestructionFooter),
                self.contentView.topAnchor.constraint(lessThanOrEqualTo: imageViewDesc.topAnchor),
                imageViewDesc.constraintLeadingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTrailingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTopSafeArea(subview: labelDesc, padding: 5),
                imageViewDesc.constraintBottomSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding)
            ].activate()

            self.labelDesc = labelDesc
            self.imageViewDesc = imageViewDesc
        }

        self.readyToStart = true
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in

            self?.scrollView?.updateScales()
        }, completion: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        if !self.hasSelfDestructionStarted, self.readyToStart {
            if !self.messageDeleted, self.decryptedMessage.sendOptions?.countDownSelfDestruction != nil {
                self.countDownStarted()
            }

            self.updateTouchState(true)

            if !(self.countdownTimer?.isValid ?? false), !self.hasSelfDestructionStarted {
                self.countdownTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateCountdownLabel), userInfo: nil, repeats: true)
            }
        }
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
        }
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        if !self.hasSelfDestructionStarted {
            self.updateTouchState(false)
        }
    }

    @objc
    private func handleDoubleTap(_: UITapGestureRecognizer) {
        var scale = self.scrollView?.zoomScale ?? 1

        scale += 1.0

        if scale > 2.0 {
            scale = self.scrollView?.minimumZoomScale ?? 1
        }
        self.scrollView?.setZoomScale(scale, animated: true)
    }

    @objc
    private func handleSingleTap(_: UITapGestureRecognizer) {
        let navigationBarHidden = self.navigationController?.isNavigationBarHidden ?? true

        self.navigationController?.setNavigationBarHidden(!navigationBarHidden, animated: true)

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in

            self?.contentView.backgroundColor = navigationBarHidden ? .clear : .black
            self?.imageViewDesc?.alpha = navigationBarHidden ? 1 : 0
        })
    }
}

extension DPAGShowImageViewController: UIScrollViewDelegate {
    func viewForZooming(in _: UIScrollView) -> UIView? {
        self.imageView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        self.scrollView?.centerScrollViewContents(self.imageView)
    }
}
