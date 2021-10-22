//
//  DPAGScanProfileViewController.swift
// ginlo
//
//  Created by RBU on 25/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit
import ZXingObjC

class DPAGScanProfileViewController: DPAGViewControllerBackground {
    private let successBlock: DPAGCompletion
    private let failedBlock: DPAGCompletion
    private let cancelBlock: DPAGCompletion
    private let contactGuid: String
    private var scanProfileWorker: DPAGScanProfileWorker?
    private var didCalledResultBlock = false

    init(contactGuid: String, blockSuccess successBlock: @escaping DPAGCompletion, blockFailed failedBlock: @escaping DPAGCompletion, blockCancelled cancelBlock: @escaping DPAGCompletion) {
        self.successBlock = successBlock
        self.failedBlock = failedBlock
        self.cancelBlock = cancelBlock
        self.contactGuid = contactGuid
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("chat.list.action.scanContact")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.scanProfileWorker == nil {
            self.scanProfileWorker = DPAGScanProfileWorker(presentingController: self, scanDelegate: self)
            if let contact = DPAGApplicationFacade.cache.contact(for: self.contactGuid), let contactPublicKey = contact.publicKey {
                self.scanProfileWorker?.verifyQRCodeForContact(self.contactGuid, publicKey: contactPublicKey)
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.scanProfileWorker?.cancelWithCompletion { [weak self] in
            self?.scanFinishedWithCancel()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            let orientation = AppConfig.statusBarOrientation()
            self?.scanProfileWorker?.updateVideoToOrientation(orientation)
        }, completion: nil)
    }
}

extension DPAGScanProfileViewController: DPAGScanProfileDelegate {
    func scanFinishedWithSuccess() {
        if !self.didCalledResultBlock {
            self.didCalledResultBlock = true
            self.successBlock()
        }
    }

    func scanFinishedWithFail() {
        if !self.didCalledResultBlock {
            self.didCalledResultBlock = true
            self.failedBlock()
        }
    }

    func scanFinishedWithCancel() {
        if self.didCalledResultBlock == false {
            self.didCalledResultBlock = true
            self.cancelBlock()
        }
    }
}

private protocol DPAGScanProfileDelegate: AnyObject {
    func scanFinishedWithSuccess()
    func scanFinishedWithFail()
    func scanFinishedWithCancel()
}

private class DPAGScanProfileWorker: NSObject {
    private weak var presentingController: UIViewController?
    private weak var scanDelegate: DPAGScanProfileDelegate?
    private var scanWorkerDelegate: DPAGScanProfileWorkerDelegate?
    private var capture: ZXCapture?
    private var contactAccountGuid: String?
    private var publicKey: String?

    var isValidating = false

    init(presentingController: UIViewController, scanDelegate: DPAGScanProfileDelegate) {
        self.presentingController = presentingController
        self.scanDelegate = scanDelegate
        super.init()
        self.scanWorkerDelegate = DPAGScanProfileWorkerDelegate(scanWorker: self)
    }

    func verifyQRCodeForContact(_ contactAccountGuid: String, publicKey: String) {
        guard let presentingController = self.presentingController else { return }

        self.contactAccountGuid = contactAccountGuid
        self.publicKey = publicKey
        let capture = ZXCapture()
        capture.delegate = self.scanWorkerDelegate
        capture.rotation = 90.0
        capture.camera = capture.back()
        capture.layer.frame = presentingController.view.bounds
        self.capture = capture
        UIView.transition(with: presentingController.view, duration: 0.15, options: .transitionCrossDissolve, animations: { [weak self] in
            guard let strongSelf = self, let capture = strongSelf.capture, capture.layer != nil else { return }
            let oldState = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            strongSelf.presentingController?.view.layer.addSublayer(capture.layer)
            strongSelf.updateVideoToOrientation(AppConfig.statusBarOrientation())
            UIView.setAnimationsEnabled(oldState)
        }, completion: nil)
    }

    func updateVideoToOrientation(_ io: UIInterfaceOrientation) {
        guard let capture = self.capture, capture.layer != nil else { return }
        capture.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        switch io {
            case .portrait:
                capture.layer.transform = CATransform3DIdentity
            case .portraitUpsideDown:
                capture.layer.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
            case .landscapeLeft:
                capture.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                capture.layer.transform = CATransform3DMakeRotation(CGFloat(Double.pi / 2), 0.0, 0.0, 1.0)
            case .landscapeRight:
                capture.layer.transform = CATransform3DMakeRotation(CGFloat(-(Double.pi / 2)), 0.0, 0.0, 1.0)
            default:
                break
        }
        capture.layer.frame = capture.layer.superlayer?.bounds ?? capture.layer.bounds
    }

    func cancelWithCompletion(_ completion: DPAGCompletion?) {
        self.capture?.delegate = nil
        guard let presentingController = self.presentingController else { return }
        UIView.transition(with: presentingController.view, duration: 0.3, options: .transitionCrossDissolve, animations: { [weak self] in
            let oldState = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            self?.capture?.layer.removeFromSuperlayer()
            UIView.setAnimationsEnabled(oldState)
        }, completion: { [weak self] _ in
            self?.capture?.stop()
            completion?()
        })
    }

    func validateResult(_ text: String) {
        guard let contactAccountGuid = self.contactAccountGuid, let publicKey = self.publicKey else { return }
        let isValid = DPAGApplicationFacade.contactsWorker.validateScanResult(text: text, publicKey: publicKey)
        DPAGLog("verified QR code data: %@", NSNumber(value: isValid))
        if isValid {
            DPAGApplicationFacade.contactsWorker.contactConfidenceHigh(contactAccountGuid: contactAccountGuid)
            self.performBlockOnMainThread { [weak self] in
                NotificationCenter.default.post(name: DPAGStrings.Notification.ChatList.NEEDS_UPDATE, object: nil)
                self?.cancelWithCompletion { [weak self] in
                    self?.scanDelegate?.scanFinishedWithSuccess()
                    self?.isValidating = false
                }
            }
        } else {
            self.isValidating = false
            self.scanDelegate?.scanFinishedWithFail()
        }
    }
}

// MARK: - ZXCaptureDelegate

private class DPAGScanProfileWorkerDelegate: NSObject, ZXCaptureDelegate {
    weak var scanWorker: DPAGScanProfileWorker?

    init(scanWorker: DPAGScanProfileWorker) {
        self.scanWorker = scanWorker
        super.init()
    }

    func captureResult(_: ZXCapture, result: ZXResult) {
        if (self.scanWorker?.isValidating ?? true) == false {
            self.scanWorker?.isValidating = true
            let resultText = result.text ?? ""
            DPAGLog("capture result: \(resultText)")
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            self.performBlockInBackground { [weak self] in
                self?.scanWorker?.validateResult(resultText)
            }
        }
    }
}
