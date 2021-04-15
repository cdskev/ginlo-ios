//
//  UILabel+Extensions.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore

public extension UILabel {
    //    var textColorPicker: UIColor
    //    {
    //        get
    //        {
    //            return self.textColor
    //        }
    //        set
    //        {
    //            self.textColor = self.textColorPicker
    //        }
    //    }

    func configureLabelForTextField() {
        self.textColor = DPAGColorProvider.shared[.labelText]
        self.font = UIFont.kFontFootnote
        self.textAlignment = .left
        self.numberOfLines = 0
    }

    func configureLabelForVideo() {
        self.textColor = DPAGColorProvider.shared[.labelTextForBackgroundInverted]
        self.font = UIFont.kFontFootnote
        self.textAlignment = .center
        self.numberOfLines = 0
    }

    func updateWithSearchBarText(_ searchBarText: String?) {
        guard let searchBarText = searchBarText, searchBarText.isEmpty == false else { return }

        var textToHighlightCheck: NSMutableAttributedString?

        if let attributedText = self.attributedText, attributedText.string.range(of: searchBarText, options: .caseInsensitive) != nil {
            textToHighlightCheck = NSMutableAttributedString(attributedString: attributedText)
        } else if let text = self.text, text.range(of: searchBarText, options: .caseInsensitive) != nil {
            textToHighlightCheck = NSMutableAttributedString(string: text)
        }

        guard let textToHighlight = textToHighlightCheck else { return }

        let attributedTextString = textToHighlight.string as NSString
        var range = NSRange(location: 0, length: attributedTextString.length)
        var rangeFound = attributedTextString.range(of: searchBarText, options: .caseInsensitive, range: range)

        while rangeFound.location != NSNotFound {
            textToHighlight.addAttribute(.foregroundColor, value: DPAGColorProvider.shared[.conversationOverviewHighlight], range: rangeFound)

            let newStartIndex = (rangeFound.location + rangeFound.length)

            range = NSRange(location: newStartIndex, length: attributedTextString.length - newStartIndex)
            rangeFound = attributedTextString.range(of: searchBarText, options: .caseInsensitive, range: range)
        }

        self.text = nil
        self.attributedText = textToHighlight
    }
}
