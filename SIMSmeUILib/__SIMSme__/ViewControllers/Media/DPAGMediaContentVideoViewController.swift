//
//  DPAGMediaContentVideoViewController.swift
//  SIMSme
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVKit
import Photos
import SIMSmeCore
import UIKit

class DPAGMediaContentVideoViewController: DPAGMediaContentViewController, DPAGMediaContentVideoViewControllerProtocol {
    func saveToLibrary(buttonPressed: UIBarButtonItem) {
        if AppConfig.isShareExtension == false {
            guard let attachment = self.mediaResource.attachment else {
                return
            }

            DPAGAttachmentWorker.shareAttachment(attachment: attachment, buttonPressed: buttonPressed)
        }
    }

    private var movieUrl: URL?
    private weak var playButton: UIButton?
    private weak var imageView: UIImageView?

    private var labelDesc: UILabel?
    private var imageViewDesc: UIImageView?

    override func setUpGui() {
        super.setUpGui()

        self.view.backgroundColor = UIColor.clear

        let imageView = UIImageView(frame: self.view.frame)
        self.imageView = imageView

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.clear
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

        self.view.addSubview(imageView)

        let playButton = UIButton(type: .custom)

        self.playButton = playButton

        playButton.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        playButton.addTarget(self, action: #selector(handlePlayButtonPressed), for: .touchUpInside)

        self.view.addSubview(playButton)

        playButton.setBackgroundImage(DPAGImageProvider.shared[.kImageChatCellOverlayVideoPlay], for: .normal)
        playButton.tintColor = DPAGColorProvider.shared[.buttonOverlayTint]
        playButton.frame = CGRect(origin: self.view.center, size: CGSize(width: 56, height: 56))
        playButton.backgroundColor = DPAGColorProvider.shared[.buttonOverlayBackground]
        playButton.layer.cornerRadius = 28
        playButton.layer.masksToBounds = true

        if let text = self.mediaResource.text, text.isEmpty == false {
            let labelDesc = UILabel(frame: self.view.bounds)
            let imageViewDesc = UIImageView(frame: labelDesc.bounds)

            labelDesc.text = text
            labelDesc.font = .kFontBody
            labelDesc.textColor = .lightText
            labelDesc.numberOfLines = 0
            labelDesc.adjustsFontSizeToFitWidth = true

            let locations: [CGFloat] = [0.0, 0.1, 1.0]
            let components: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0.3, 0, 0, 0, 0.9]

            imageViewDesc.image = UIImage.gradientImage(size: CGSize(width: 20, height: 30), scale: 0, locations: locations, numLocations: locations.count, components: components)

            self.view.addSubview(imageViewDesc)
            imageViewDesc.addSubview(labelDesc)

            labelDesc.translatesAutoresizingMaskIntoConstraints = false
            imageViewDesc.translatesAutoresizingMaskIntoConstraints = false

            [
                self.view.constraintLeading(subview: imageViewDesc),
                self.view.constraintTrailing(subview: imageViewDesc),
                self.view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: imageViewDesc.bottomAnchor),
                self.view.centerYAnchor.constraint(lessThanOrEqualTo: imageViewDesc.topAnchor, constant: -DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTop(subview: labelDesc, padding: 5),
                imageViewDesc.constraintBottom(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintLeadingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding),
                imageViewDesc.constraintTrailingSafeArea(subview: labelDesc, padding: DPAGConstantsGlobal.kPadding)
            ].activate()

            self.labelDesc = labelDesc
            self.imageViewDesc = imageViewDesc

            self.imageViewDesc?.isHidden = true
        }
    }

    override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                self.customDelegate?.updateBackgroundColor(DPAGColorProvider.shared[.defaultViewBackground])
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    override func preparePresentationWithZoomingRect(_ zoomingRect: CGRect) {
        if zoomingRect.isNull {
            return
        }
        self.imageView?.contentMode = .scaleAspectFill
        self.imageView?.clipsToBounds = true
        self.imageView?.frame = zoomingRect
        self.imageView?.autoresizingMask = UIView.AutoresizingMask()

        self.playButton?.alpha = 0

        self.customDelegate?.updateBackgroundColor(UIColor.clear)
    }

    override func animatePresentationZoomingRect(_ zoomingRect: CGRect) {
        if zoomingRect.isNull {
            return
        }
        if let image = self.imageView?.image {
            self.imageView?.frame = image.rectForImageFullscreenInView(self.view, interfaceOrientationRect: self.view.frame)
        } else {
            self.imageView?.frame = self.view.frame
        }
        self.customDelegate?.updateBackgroundColor(DPAGColorProvider.shared[.defaultViewBackground])
    }

    override func completePresentationZoomingRect(_ zoomingRect: CGRect) {
        if zoomingRect.isNull {
            self.handlePlayButtonPressed()
            return
        }
        self.imageView?.contentMode = .scaleAspectFit
        self.imageView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.imageView?.frame = self.view.bounds
        self.playButton?.center = self.view.center
        self.playButton?.alpha = 1

        UIView.animate(withDuration: TimeInterval(UINavigationController.hideShowBarDuration), animations: { [weak self] in
            self?.imageView?.backgroundColor = .black
        }, completion: { [weak self] _ in

            self?.handlePlayButtonPressed()
            self?.imageView?.backgroundColor = .clear
            self?.imageViewDesc?.isHidden = false
        })
    }

    override func prepareDismissalWithZoomingRect(_ zoomingRect: CGRect) {
        if zoomingRect.isNull {
            return
        }
        self.imageView?.contentMode = .scaleAspectFit
        self.imageView?.autoresizingMask = UIView.AutoresizingMask()
        self.playButton?.alpha = 0
        self.imageViewDesc?.isHidden = true
    }

    override func animateDismissalZoomingRect(_ zoomingRect: CGRect) {
        if zoomingRect.isNull {
            return
        }
        self.imageView?.frame = zoomingRect
        self.customDelegate?.updateBackgroundColor(.clear)
    }

    override func completeDismissalZoomingRect(_: CGRect) {}

    override func updateMediaResource() {
        super.updateMediaResource()

        self.imageView?.image = self.mediaResource.preview ?? self.mediaResource.attachment?.thumb

        if AppConfig.isShareExtension == false {
            if let attachment = mediaResource.attachment {
                self.performBlockInBackground {
                    DPAGAttachmentWorker.autoSave(attachment: attachment)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.playButton?.center = self.view.center
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        if parent == nil {
            DPAGHelperEx.clearTempFolder()
        }
    }

    @objc
    private func handlePlayButtonPressed() {
        self.movieUrl = self.movieUrl ?? self.mediaResource.mediaUrl

        if self.movieUrl == nil || FileManager.default.fileExists(atPath: self.movieUrl?.path ?? "") == false, self.mediaResource.mediaContent != nil {
            if let url = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent(String(format: "%@tempVideo", self.mediaResource.attachment?.attachmentGuid ?? DPAGFunctionsGlobal.uuid())).appendingPathExtension("mp4") {
                do {
                    try self.mediaResource.mediaContent?.write(to: url, options: [.atomic])

                    self.movieUrl = url
                } catch {
                    DPAGLog(error)
                }
            }
        } else if let attachment = self.mediaResource.attachment {
            if AppConfig.isShareExtension == false {
                DPAGAttachmentWorker.decryptMessageAttachment(attachment: attachment) { data, _ in

                    if data != nil, let url = DPAGFunctionsGlobal.pathForCustomTMPDirectory()?.appendingPathComponent(String(format: "%@tempVideo", attachment.attachmentGuid)).appendingPathExtension("mp4") {
                        do {
                            try data?.write(to: url, options: [.atomic])

                            self.movieUrl = url
                            self.mediaResource.mediaUrl = url
                        } catch {
                            DPAGLog(error)
                        }
                    }
                }
            }
        }

        guard let movieUrl = self.movieUrl else { return }

        let playVC = DPAGApplicationFacadeUIMedia.mediaPlayerVC(playerItem: AVPlayerItem(asset: AVURLAsset(url: movieUrl)))

        playVC.modalPresentationStyle = .custom
        playVC.transitioningDelegateTransparent = DPAGApplicationFacadeUIBase.defaultTransparentTransitioningDelegate()
        playVC.transitioningDelegate = playVC.transitioningDelegateTransparent

        self.present(playVC, animated: true, completion: nil)
    }
}
