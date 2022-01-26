//
//  DPAGImageMessageCell.swift
// ginlo
//
//  Created by RBU on 06/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGImageMessageChannelLeftCell: DPAGImageMessageCell, DPAGChatStreamCellLeft {
  override var accessibilityLabel: String? {
    get {
      String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.imageReceived"))
    }
    set {
      super.accessibilityLabel = newValue
    }
  }
  
  override func chatTextColor() -> UIColor {
    DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
  }
}

class DPAGImageMessageLeftCell: DPAGImageMessageCell, DPAGChatStreamCellLeft {
  override var accessibilityLabel: String? {
    get {
      String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.imageReceived"))
    }
    set {
      super.accessibilityLabel = newValue
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if let labelDesc = self.labelDesc {
      labelDesc.preferredMaxLayoutWidth = self.contentView.frame.width - 128
    }
  }
  
  override func chatTextColor() -> UIColor {
    DPAGColorProvider.shared[.chatDetailsBubbleNotMineContrast]
  }
}

class DPAGImageMessageRightCell: DPAGImageMessageCell, DPAGChatStreamCellRight {
  override var accessibilityLabel: String? {
    get {
      String(format: "%@ %@", self.labelInfo?.text ?? "", DPAGLocalizedString("chat.overview.preview.imageSent"))
    }
    set {
      super.accessibilityLabel = newValue
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if let labelDesc = self.labelDesc {
      labelDesc.preferredMaxLayoutWidth = self.contentView.frame.width - 128
    }
  }
}

public protocol DPAGImageMessageCellProtocol: DPAGMessageCellProtocol, DPAGCellWithProgress, DPAGChatLabelDelegate {
  func openLinkInSelectedCell()
  func copyLinkInSelectedCell()
}

class DPAGImageMessageCell: DPAGMessageCell, DPAGImageMessageCellProtocol {
  var downloadCompletionBackground: DPAGCompletion?
  
  @IBOutlet var viewImage: UIImageView! {
    didSet {
      self.viewImage.contentMode = .scaleAspectFill
      self.viewImage.clipsToBounds = true
    }
  }
  
  @IBOutlet var viewDesc: DPAGStackViewContentView?
  @IBOutlet var labelDesc: DPAGChatLabel? {
    didSet {
      self.labelDesc?.delegate = self
      self.labelDesc?.textColor = chatTextColor()
      self.labelDesc?.lineBreakMode = .byWordWrapping
      self.labelDesc?.numberOfLines = 0
    }
  }
  
  @IBOutlet var constraintViewImageRatio: NSLayoutConstraint!
  @IBOutlet var constraintViewImageWidth: NSLayoutConstraint!
  
  @IBOutlet var viewProgress: DPAGCellProgressViewLarge? {
    didSet {
      self.viewProgress?.fillImage = DPAGImageProvider.shared[.kImageChatCellOverlayImageLoading]
    }
  }
  
  @IBOutlet var viewProgressActivity: UIActivityIndicatorView?
  
  override func updateFonts() {
    super.updateFonts()
    
    self.labelDesc?.font = UIFont.kFontBody
  }
  
  override var accessibilityLabel: String? {
    get {
      if self.labelDesc?.text != nil {
        return self.labelDesc?.text
      }
      return super.accessibilityLabel
    }
    set {
      super.accessibilityLabel = newValue
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if self.constraintViewImageWidth.constant != min(min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 112, 320) {
      self.setNeedsUpdateConstraints()
    }
  }
  
  override func updateConstraints() {
    super.updateConstraints()
    let newConstWidth = min(min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 112, 320)
    if self.constraintViewImageWidth.constant != newConstWidth {
      self.constraintViewImageWidth.constant = newConstWidth
    }
  }
  
  override func configureCellWithMessage(_ decryptedMessage: DPAGDecryptedMessage, forHeightMeasurement: Bool) {
    super.configureCellWithMessage(decryptedMessage, forHeightMeasurement: forHeightMeasurement)
    var previewImage: UIImage?
    if let content = decryptedMessage.content {
      if let imageData = Data(base64Encoded: content, options: .ignoreUnknownCharacters) {
        previewImage = UIImage(data: imageData)
        if (previewImage?.size.width ?? 0) > DPAGConstantsGlobal.kChatMaxWidthObjects {
          previewImage = UIImage(data: imageData, scale: UIScreen.main.scale)
        }
      }
    }
    if let attributedText = decryptedMessage.attributedText, attributedText.isEmpty == false {
      self.viewDesc?.isHidden = false
      self.labelDesc?.attributedText = NSAttributedString(string: attributedText, attributes: [.font: UIFont.kFontBody])
    } else {
      self.viewDesc?.isHidden = true
      self.labelDesc?.attributedText = nil
    }
    self.labelDesc?.resetLinks()
    self.setPreviewImage(previewImage)
    guard forHeightMeasurement == false else { return }
    if AttachmentHelper.attachmentAlreadySavedForGuid(decryptedMessage.attachmentGuid) || ((decryptedMessage.isReadServerAttachment || (decryptedMessage.isOwnMessage && decryptedMessage.dateDownloaded != nil)) && DPAGApplicationFacade.preferences.isBaMandant == false) {
      self.viewProgress?.isHidden = true
    } else {
      self.viewProgress?.isHidden = false
    }
    self.viewProgress?.setProgress(0)
    self.viewProgressActivity?.stopAnimating()
    decryptedMessage.attachmentProgress = 0
    decryptedMessage.cellWithProgress = self
    self.setLongPressGestureRecognizerForView(self.viewBubble)
    self.setCellContentSelectedAction { [weak self] in
      self?.didSelectMessageWithValidBlock({ [weak self] in
        self?.didSelectValidImage()
      })
    }
    if let attributedText = decryptedMessage.attributedText, let rangesWithLink = decryptedMessage.rangesWithLink {
      let attributedText = NSMutableAttributedString(string: attributedText, attributes: [.font: UIFont.kFontBody])
      for result in rangesWithLink {
        attributedText.addAttributes([.foregroundColor: chatTextColor(), .underlineStyle: NSUnderlineStyle.single.rawValue], range: result.range)
      }
      self.labelDesc?.attributedText = attributedText
      self.labelDesc?.applyLinks(rangesWithLink)
    }
  }
  
  func didSelectLinkWithURL(_ url: URL) {
    self.askToForwardURL(url)
  }
  
  func askToForwardURL(_ url: URL) {
    self.streamDelegate?.askToForwardURL(url)
  }
  
  override func zoomingViewForNavigationTransition() -> UIView? {
    self.viewImage
  }
  
  func setPreviewImage(_ image: UIImage?) {
    guard let imagePreview = image else {
      self.viewImage?.image = nil
      return
    }
    self.viewImage?.image = imagePreview
    let newHeight = min(imagePreview.size.height, 320)
    let newWidth = min(imagePreview.size.width, 320)
    let constraintViewImageRatioMultiplier: CGFloat
    if (newHeight / 3) * 4 >= newWidth {
      constraintViewImageRatioMultiplier = 3 / 4
    } else if (newHeight / 9) * 16 >= newWidth {
      constraintViewImageRatioMultiplier = 9 / 16
    } else {
      constraintViewImageRatioMultiplier = newHeight / newWidth
    }
    if constraintViewImageRatioMultiplier != self.constraintViewImageRatio.multiplier {
      NSLayoutConstraint.deactivate([self.constraintViewImageRatio])
      self.viewImage.removeConstraint(self.constraintViewImageRatio)
      self.constraintViewImageRatio = self.viewImage.heightAnchor.constraint(equalTo: self.viewImage.widthAnchor, multiplier: constraintViewImageRatioMultiplier)
      NSLayoutConstraint.activate([self.constraintViewImageRatio])
    }
  }
  
  func showWorkInProgress() {
    self.viewProgress?.isHidden = false
    self.viewProgress?.setProgress(0)
    self.viewProgressActivity?.startAnimating()
    self.isLoadingAttachment = true
  }
  
  func updateDownloadProgress(_ progress: Progress, isAutoDownload: Bool) {
    if (self.viewProgress?.progressValue ?? -1) == progress.fractionCompleted {
      return
    }
    
    self.isLoadingAttachment = true
    self.viewProgress?.setProgress(progress.fractionCompleted)
    if progress.fractionCompleted == 1 {
      self.viewProgress?.isHidden = true
      if isAutoDownload {
        if self.isLoadingAttachment {
          self.isLoadingAttachment = false
          self.hideWorkInProgressWithCompletion {}
        }
      } else if (self.viewProgressActivity?.isAnimating ?? false) == false {
        self.viewProgressActivity?.startAnimating()
      }
    } else {
      self.viewProgressActivity?.stopAnimating()
    }
  }
  
  func cancelWorkInProgress() {
    self.viewProgressActivity?.stopAnimating()
    self.viewProgress?.setProgress(0)
  }
  
  func hideWorkInProgress() {
    self.viewProgressActivity?.stopAnimating()
    self.viewProgress?.setProgress(0)
    self.viewProgress?.isHidden = true
  }
  
  func hideWorkInProgressWithCompletion(_ completion: @escaping DPAGCompletion) {
    self.viewProgressActivity?.stopAnimating()
    self.viewProgress?.setProgress(1)
    self.hideWorkInProgress()
    completion()
  }
  
  func contentOfCell() -> String? {
    self.labelDesc?.text ?? self.labelDesc?.attributedText?.string
  }
  
  override func menuItems() -> [UIMenuItem] {
    var retVal = super.menuItems()
    if (self.labelDesc?.links.count ?? 0) > 0 {
      retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.openLink"), action: #selector(openLinkInSelectedCell)))
      retVal.append(UIMenuItem(title: DPAGLocalizedString("chat.message.action.copyLink"), action: #selector(copyLinkInSelectedCell)))
    }
    return retVal
  }
  
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if sender is UIMenuController {
      if action == #selector(DPAGMessageCell.copySelectedCell) {
        let desc = self.labelDesc?.text ?? self.labelDesc?.attributedText?.string
        if (desc?.isEmpty ?? true) == false {
          return true
        }
      } else if action == #selector(openLinkInSelectedCell) || action == #selector(copyLinkInSelectedCell) {
        return true
      }
    }
    return super.canPerformAction(action, withSender: sender)
  }
  
  override func canPerformCopy() -> Bool {
    (self.decryptedMessage.contentDesc?.isEmpty ?? true) == false
  }
  
  override func copySelectedCell() {
    if let clipboardString = self.contentOfCell() {
      UIPasteboard.general.string = clipboardString
    }
  }
  
  override func copy(_: Any?) {
    if let clipboardString = self.contentOfCell() {
      UIPasteboard.general.string = clipboardString
    }
  }
  
  override func forwardSelectedCell() {
    if self.decryptedCheckedMessage() {
      return
    }
    let previewImage = self.viewImage?.image
    self.streamDelegate?.loadAttachmentImageWithMessage(self.decryptedMessage, cell: self, previewImage: previewImage)
  }
  
  @objc
  func openLinkInSelectedCell() {
    guard let labelText = self.labelDesc else { return }
    self.streamDelegate?.openLink(for: labelText)
  }
  
  @objc
  func copyLinkInSelectedCell() {
    guard let labelText = self.labelDesc else { return }
    self.streamDelegate?.copyLink(for: labelText)
  }
}
