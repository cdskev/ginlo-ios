//
//  DPAGMediaContentImageViewController.swift
// ginlo
//
//  Created by RBU on 02/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Photos
import SIMSmeCore
import UIKit

class DPAGMediaContentImageViewController: DPAGMediaContentViewController, DPAGMediaContentImageViewControllerProtocol {
  func saveToLibrary(buttonPressed: UIBarButtonItem) {
    if AppConfig.isShareExtension == false {
      guard let attachment = self.mediaResource.attachment else { return }
      DPAGAttachmentWorker.shareAttachment(attachment: attachment, buttonPressed: buttonPressed)
    }
  }
  
  private weak var scrollView: UIScrollView?
  private(set) weak var imageView: UIImageView?
  
  private var labelDesc: UILabel?
  private var imageViewDesc: UIImageView?
  
  override func setUpGui() {
    let imageView = UIImageView()
    self.imageView = imageView
    self.imageView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    
    self.imageView?.clipsToBounds = true
    
    let scrollView = UIScrollView(frame: self.view.bounds)
    self.scrollView = scrollView
    
    scrollView.delegate = self
    scrollView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
    scrollView.maximumZoomScale = 3.0
    scrollView.addSubview(imageView)
    scrollView.contentInsetAdjustmentBehavior = .never
    
    self.view.addSubview(scrollView)
    scrollView.clipsToBounds = true
    scrollView.canCancelContentTouches = false
    scrollView.isScrollEnabled = true
    scrollView.bouncesZoom = true
    
    self.view.backgroundColor = .clear
    imageView.backgroundColor = .clear
    scrollView.backgroundColor = .clear
    
    let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
    doubleTapRecognizer.numberOfTapsRequired = 2
    
    scrollView.addGestureRecognizer(doubleTapRecognizer)
    
    let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
    singleTapRecognizer.numberOfTapsRequired = 1
    scrollView.addGestureRecognizer(singleTapRecognizer)
    singleTapRecognizer.require(toFail: doubleTapRecognizer)
    
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
      
      let doubleTapRecognizerLabel = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
      doubleTapRecognizerLabel.numberOfTapsRequired = 2
      
      imageViewDesc.addGestureRecognizer(doubleTapRecognizerLabel)
      
      let singleTapRecognizerLabel = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
      singleTapRecognizerLabel.numberOfTapsRequired = 1
      imageViewDesc.addGestureRecognizer(singleTapRecognizerLabel)
      singleTapRecognizerLabel.require(toFail: doubleTapRecognizer)
      singleTapRecognizerLabel.require(toFail: doubleTapRecognizerLabel)
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    self.scrollView?.updateScales()
    self.scrollView?.centerScrollViewContents(self.imageView)
    
    self.imageView?.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
  }
  
  override func preparePresentationWithZoomingRect(_ zoomingRect: CGRect) {
    if zoomingRect.isNull {
      return
    }
    self.imageView?.contentMode = .scaleAspectFill
    self.imageView?.clipsToBounds = true
    self.imageView?.frame = zoomingRect
    self.imageView?.autoresizingMask = UIView.AutoresizingMask()
    
    self.customDelegate?.updateBackgroundColor(UIColor.clear)
  }
  
  override func animatePresentationZoomingRect(_ zoomingRect: CGRect) {
    if zoomingRect.isNull {
      return
    }
    if let image = self.imageView?.image {
      self.imageView?.frame = image.rectForImageFullscreenInView(self.view, interfaceOrientationRect: self.view.frame)
    } else {
      self.imageView?.frame = self.scrollView?.frame ?? .zero
    }
    self.customDelegate?.updateBackgroundColor(DPAGColorProvider.shared[.defaultViewBackground])
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
  
  override func completePresentationZoomingRect(_ zoomingRect: CGRect) {
    if zoomingRect.isNull {
      return
    }
    self.scrollView?.contentSize = self.imageView?.frame.size ?? .zero
    self.scrollView?.updateScales()
    self.imageViewDesc?.isHidden = false
  }
  
  override func prepareDismissalWithZoomingRect(_: CGRect) {
    self.imageViewDesc?.isHidden = false
  }
  
  override func animateDismissalZoomingRect(_ zoomingRect: CGRect) {
    self.scrollView?.updateScales()
    if zoomingRect.isNull {
      return
    }
    self.imageView?.frame = zoomingRect
    self.customDelegate?.updateBackgroundColor(UIColor.clear)
  }
  
  override func completeDismissalZoomingRect(_ zoomingRect: CGRect) {
    if zoomingRect.isNull {
      return
    }
    self.scrollView?.contentSize = self.imageView?.frame.size ?? .zero
    self.scrollView?.updateScales()
  }
  
  override func updateMediaResource() {
    super.updateMediaResource()
    
    if let mediaContent = self.mediaResource.mediaContent, let image = UIImage(data: mediaContent) {
      self.updateWithImage(image)
    } else if let mediaUrl = self.mediaResource.mediaUrl, let imageData = try? Data(contentsOf: mediaUrl), let image = UIImage(data: imageData) {
      self.updateWithImage(image)
    } else if let imageAsset = self.mediaResource.mediaAsset {
      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.resizeMode = .fast
      
      if AppConfig.isShareExtension {
        let preferences = DPAGApplicationFacadeShareExt.preferences
        
        PHImageManager.default().requestImage(for: imageAsset, targetSize: preferences.imageOptionsForSending.size, contentMode: .aspectFit, options: options) { [weak self] image, _ in
          
          guard let image = image else { return }
          
          self?.performBlockOnMainThread { [weak self] in
            self?.updateWithImage(image)
          }
        }
      } else {
        let preferences = DPAGApplicationFacade.preferences
        
        PHImageManager.default().requestImage(for: imageAsset, targetSize: preferences.imageOptionsForSending.size, contentMode: .aspectFit, options: options) { [weak self] image, _ in
          
          guard let image = image else { return }
          
          self?.performBlockOnMainThread { [weak self] in
            self?.updateWithImage(image)
          }
        }
      }
    } else if let attachment = self.mediaResource.attachment {
      if AppConfig.isShareExtension == false {
        guard let resource = DPAGAttachmentWorker.resourceFromAttachment(attachment).mediaResource else { return }
        
        self.mediaResource.additionalData = resource.additionalData
        self.mediaResource.preview = resource.preview
        
        if let mediaContent = resource.mediaContent, let image = UIImage(data: mediaContent) {
          self.updateWithImage(image)
        }
      }
    }
  }
  
  private func updateWithImage(_ image: UIImage) {
    if AppConfig.isShareExtension == false {
      if let attachment = mediaResource.attachment {
        self.performBlockInBackground {
          DPAGAttachmentWorker.autoSave(attachment: attachment)
        }
      }
    }
    
    self.imageView?.contentMode = .scaleAspectFit
    self.imageView?.image = image
    self.imageView?.frame = image.rectForImageFullscreenInView(self.view, interfaceOrientationRect: self.view.frame)
    self.scrollView?.contentSize = self.imageView?.frame.size ?? .zero
    self.imageView?.autoresizingMask = UIView.AutoresizingMask()
    
    self.scrollView?.updateScales()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    self.scrollView?.zoomScale = self.scrollView?.minimumZoomScale ?? 0
  }
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    
    coordinator.animate(alongsideTransition: { [weak self] _ in
      
      self?.scrollView?.updateScales()
      self?.scrollView?.centerScrollViewContents(self?.imageView)
      
    }, completion: nil)
  }
  
  override func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
    super.handleSingleTap(recognizer)
    self.imageViewDesc?.isHidden = (self.imageViewDesc?.isHidden ?? false) == false
  }
  
  @objc
  private func handleDoubleTap(_: UITapGestureRecognizer) {
    if let scrollView = self.scrollView {
      var scale = scrollView.zoomScale
      scale += 1.0
      if scale > 2.0 {
        scale = scrollView.minimumZoomScale
      }
      self.scrollView?.setZoomScale(scale, animated: true)
    }
  }
}

extension DPAGMediaContentImageViewController: UIScrollViewDelegate {
  func viewForZooming(in _: UIScrollView) -> UIView? {
    self.imageView
  }
  
  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    scrollView.centerScrollViewContents(self.imageView)
  }
}
