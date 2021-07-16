//
//  DPAGChatLabel.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public protocol DPAGChatLabelDelegate: AnyObject {
    func didSelectLinkWithURL(_ url: URL)
}

public class DPAGChatLabel: UILabel {
    private static let highLightAnimationTime: CGFloat = 0.15

    private var handlerDictionary: [NSValue: (DPAGChatLabel, NSRange) -> Void] = [:]
    private var layoutManager: NSLayoutManager?
    private var textContainer: NSTextContainer?
    private var backupAttributedText: NSAttributedString?

    public var linkAttributeDefault: [NSAttributedString.Key: Any] = [
        .foregroundColor: DPAGColorProvider.shared[.chatDetailsBubbleLink],
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    public var linkAttributeHighlight: [NSAttributedString.Key: Any] = [
        .foregroundColor: DPAGColorProvider.shared[.chatDetailsBubbleLink],
        .underlineStyle: NSUnderlineStyle.single.rawValue
    ]

    open override
    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                DPAGColorProvider.shared.darkMode = traitCollection.userInterfaceStyle == .dark
                 linkAttributeDefault = [
                    .foregroundColor: DPAGColorProvider.shared[.chatDetailsBubbleLink],
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
                linkAttributeHighlight = [
                    .foregroundColor: DPAGColorProvider.shared[.chatDetailsBubbleLink],
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            }
        } else {
            DPAGColorProvider.shared.darkMode = false
        }
    }

    private static let dataDetector: NSDataDetector? = try? NSDataDetector(types: DPAGCache.dataDetectorTypes.rawValue)

    public weak var delegate: DPAGChatLabelDelegate?

    public private(set) var links: [NSValue: URL] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    private func setup() {
        if !self.isUserInteractionEnabled {
            self.isUserInteractionEnabled = true

            let tapGr = UITapGestureRecognizer(target: self, action: #selector(DPAGChatLabel.handleTap(_:)))

            tapGr.delegate = self

            self.addGestureRecognizer(tapGr)
        }
    }

    public func setLink(url: URL, for range: NSRange) { // , linkHandler handler:((DPAGChatLabel, NSRange) -> ()), withAttributes attributes: [String: Any]? = nil)
        if let attributedText = self.attributedText, attributedText.length >= (range.location + range.length) {
            let mutableAttributedString = NSMutableAttributedString(attributedString: attributedText)

            mutableAttributedString.addAttributes(self.linkAttributeDefault, range: range)

            self.handlerDictionary[NSValue(range: range)] = { _, _ in
                self.delegate?.didSelectLinkWithURL(url)
            }
            self.links[NSValue(range: range)] = url

            self.attributedText = mutableAttributedString
        }
    }

    public func applyLinks(_ links: [NSTextCheckingResult]) {
        for link in links {
            if let url = link.url {
                self.handlerDictionary[NSValue(range: link.range)] = { _, _ in
                    self.delegate?.didSelectLinkWithURL(url)
                }
                self.links[NSValue(range: link.range)] = url
            }
        }
    }

    public func resetLinks() {
        self.links.removeAll()
        self.handlerDictionary.removeAll()
    }

    // MARK: - Event Handler

    @objc
    private func handleTap(_ tapGr: UITapGestureRecognizer) {
        let touchPoint = tapGr.location(in: self)

        if let rangeValue = self.attributedTextRangeForPoint(touchPoint) {
            if let handler = self.handlerDictionary[rangeValue] {
                handler(self, rangeValue.rangeValue)
            }
        }
    }

    // MARK: - Substring Locator

    private func attributedTextRangeForPoint(_ point: CGPoint) -> NSValue? {
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize.zero)

        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.maximumNumberOfLines = self.numberOfLines

        var size = self.bounds.size
        size.height += self.font.lineHeight

        textContainer.size = size

        layoutManager.addTextContainer(textContainer)

        if let attributedText = self.attributedText {
            let textStorage = NSTextStorage(attributedString: attributedText)

            textStorage.addLayoutManager(layoutManager)

            // find the tapped character location and compare it to the specified range
            let locationOfTouchInLabel = point
            let textBoundingBox = layoutManager.usedRect(for: textContainer)
            let textContainerOffset = CGPoint(x: textBoundingBox.minX, y: textBoundingBox.minY)
            let locationOfTouchInTextContainer = CGPoint(x: locationOfTouchInLabel.x - textContainerOffset.x, y: locationOfTouchInLabel.y - textContainerOffset.y)
            let indexOfCharacter = layoutManager.characterIndex(for: locationOfTouchInTextContainer, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

            for rangeValue in self.handlerDictionary.keys {
                let range = rangeValue.rangeValue

                if NSLocationInRange(indexOfCharacter, range) {
                    return rangeValue
                }
            }
        }

        return nil
    }

    public func detectLinks() {
        self.links.removeAll()

        if let dataDetector = DPAGChatLabel.dataDetector, let attributedText = self.attributedText {
            let results = dataDetector.matches(in: attributedText.string, options: [], range: NSRange(location: 0, length: attributedText.length))

            if results.isEmpty == false {
                for result in results {
                    if let url = result.url {
                        self.setLink(url: url, for: result.range)
                    }
                }
            }
        }
    }
}

extension DPAGChatLabel: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let touchPoint = touch.location(in: self)

        if self.attributedTextRangeForPoint(touchPoint) != nil {
            return true
        }
        return false
    }
}
