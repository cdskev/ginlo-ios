//
//  DPAGTextField.swift
//  SIMSmeUILib
//
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

public class DPAGTextField: UITextField {
    public weak var delegateDelete: DPAGTextFieldDelegate?

    private weak var textFieldBefore: UITextField?
    private weak var textFieldAfter: UITextField?
    private var textFieldMaxLength: Int = 0
    private var didChangeCompletion: (() -> Void)?

    private var textFieldSkipBackward = false

    @IBInspectable var hasRectOffset: Bool = true

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: self)
    }

    override public func deleteBackward() {
        self.delegateDelete?.willDeleteBackward(self)

        self.textFieldSkipBackward = false

        if self.textFieldBefore != nil {
            if self.selectedTextRange?.end == self.beginningOfDocument {
                self.textFieldSkipBackward = true
            }
        }
        super.deleteBackward()
        self.delegateDelete?.didDeleteBackward(self)

        if self.textFieldBefore != nil {
            if (self.text ?? "").isEmpty {
                self.textFieldSkipBackward = true
            }

            if self.textFieldSkipBackward {
                OperationQueue.main.addOperation { [weak self] () in

                    self?.textFieldBefore?.becomeFirstResponder()
                }
                self.textFieldSkipBackward = false
            }
        }
    }

    public func configure(textFieldBefore: UITextField?, textFieldAfter: UITextField?, textFieldMaxLength: Int, didChangeCompletion: (() -> Void)?) {
        self.textFieldBefore = textFieldBefore
        self.textFieldAfter = textFieldAfter
        self.textFieldMaxLength = textFieldMaxLength
        self.didChangeCompletion = didChangeCompletion

        NotificationCenter.default.addObserver(self, selector: #selector(handleInputDidChange(_:)), name: UITextField.textDidChangeNotification, object: self)
    }

    @objc
    private func handleInputDidChange(_ aNotification: Notification) {
        if self.textFieldMaxLength > 0 {
            if let textFieldAfter = self.textFieldAfter {
                self.checkTextFieldTextWithMaxLength(self.textFieldMaxLength, aNotification: aNotification, textFieldNext: textFieldAfter)
            } else if let text = self.text, text.isEmpty == false {
                if text.count >= self.textFieldMaxLength {
                    self.text = String(text.prefix(self.textFieldMaxLength))
                }
            }
        }
        self.didChangeCompletion?()
    }

    private func checkTextFieldTextWithMaxLength(_ maxLength: Int, aNotification: Notification?, textFieldNext: UITextField) {
        if let text = self.text, text.isEmpty == false {
            if text.count >= maxLength {
                var isPositionEnd = false
                let idx = text.index(text.startIndex, offsetBy: maxLength)
                let textNext = String(text[idx...])

                if let selectedTextRange = self.selectedTextRange, self.compare(selectedTextRange.end, to: self.endOfDocument) == .orderedSame {
                    isPositionEnd = true
                }

                if text.count > maxLength {
                    let selectedTextRange = self.selectedTextRange
                    self.text = String(text[..<idx])
                    if isPositionEnd == false {
                        self.selectedTextRange = selectedTextRange

                        if let selectedTextRange = self.selectedTextRange, self.compare(selectedTextRange.end, to: self.endOfDocument) == .orderedSame {
                            isPositionEnd = true
                        }
                    }
                }

                if aNotification != nil {
                    if isPositionEnd {
                        if textFieldNext.text?.isEmpty ?? true {
                            textFieldNext.text = textNext
                            textFieldNext.becomeFirstResponder()
                        } else {
                            textFieldNext.becomeFirstResponder()

                            if let textPositionNext = textFieldNext.position(from: textFieldNext.beginningOfDocument, offset: 0 /* textNext.count */ ) {
                                textFieldNext.selectedTextRange = textFieldNext.textRange(from: textPositionNext, to: textPositionNext)
                            }
                        }
                    }
                }
            }
        }
    }

    override public func textRect(forBounds bounds: CGRect) -> CGRect {
        var retVal = super.textRect(forBounds: bounds)

        if self.hasRectOffset {
            retVal.origin.y += 2
            retVal.size.height -= 4
        }

        return retVal
    }

    override public func editingRect(forBounds bounds: CGRect) -> CGRect {
        var retVal = super.editingRect(forBounds: bounds)

        if self.hasRectOffset {
            retVal.origin.y += 2
            retVal.size.height -= 4
        }

        return retVal
    }
}
