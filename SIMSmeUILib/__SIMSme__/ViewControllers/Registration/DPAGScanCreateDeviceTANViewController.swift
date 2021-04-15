//
//  DPAGScanCreateDeviceTANViewController.swift
//  SIMSme
//
//  Created by RBU on 28.11.17.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

class DPAGScanCreateDeviceTANViewController: DPAGViewControllerBackground {
    @IBOutlet private var viewScanner: UIView!
    @IBOutlet private var viewVisualEffectBlur: UIVisualEffectView!
    @IBOutlet private var viewContentVisualEffectBlur: UIView!
    @IBOutlet private var viewVisualEffectVibrant: UIVisualEffectView!
    @IBOutlet private var viewContentVisualEffectVibrant: UIView!
    @IBOutlet private var labelDescription: UILabel! {
        didSet {
            self.labelDescription.textColor = .white
            self.labelDescription.text = DPAGLocalizedString("createDevice.scan.description")
        }
    }

    @IBOutlet private var imageViewTopLeft: UIImageView! {
        didSet {
            self.imageViewTopLeft.image = UIImage.imageEdge(type: .topLeft, size: self.imageViewTopLeft.frame.size, scale: UIScreen.main.scale, color: .white)
        }
    }

    @IBOutlet private var imageViewTopRight: UIImageView! {
        didSet {
            self.imageViewTopRight.image = UIImage.imageEdge(type: .topRight, size: self.imageViewTopRight.frame.size, scale: UIScreen.main.scale, color: .white)
        }
    }

    @IBOutlet private var imageViewBottomLeft: UIImageView! {
        didSet {
            self.imageViewBottomLeft.image = UIImage.imageEdge(type: .bottomLeft, size: self.imageViewBottomLeft.frame.size, scale: UIScreen.main.scale, color: .white)
        }
    }

    @IBOutlet private var imageViewBottomRight: UIImageView! {
        didSet {
            self.imageViewBottomRight.image = UIImage.imageEdge(type: .bottomRight, size: self.imageViewBottomRight.frame.size, scale: UIScreen.main.scale, color: .white)
        }
    }

    private let successBlock: (String) -> Void
    private let failedBlock: DPAGCompletion
    private let cancelBlock: DPAGCompletion

    private var scanWorker: DPAGScanCreateDeviceTANWorker?

    private var didCalledResultBlock = false
    private weak var activityIndicator: UIActivityIndicatorView?

    init(blockSuccess successBlock: @escaping (String) -> Void, blockFailed failedBlock: @escaping DPAGCompletion, blockCancelled cancelBlock: @escaping DPAGCompletion) {
        self.successBlock = successBlock
        self.failedBlock = failedBlock
        self.cancelBlock = cancelBlock
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("registration.device.scanTAN")
        let actInd = UIActivityIndicatorView(style: .gray)
        self.view.addSubview(actInd)
        self.activityIndicator = actInd
        NSLayoutConstraint.activate([
            self.view.safeAreaLayoutGuide.centerXAnchor.constraint(equalTo: actInd.centerXAnchor),
            self.view.safeAreaLayoutGuide.centerYAnchor.constraint(equalTo: actInd.centerYAnchor)
        ])
        actInd.hidesWhenStopped = true
        actInd.translatesAutoresizingMaskIntoConstraints = false
        actInd.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.scanWorker == nil {
            self.scanWorker = DPAGScanCreateDeviceTANWorker(presentationView: self.viewScanner, scanDelegate: self)
            self.scanWorker?.verifyQRCode()
            self.viewVisualEffectBlur.layer.mask = {
                let rectBounds = self.viewVisualEffectBlur.bounds
                let rect = CGRect(x: 40, y: (rectBounds.height - (rectBounds.width - 80)) / 2, width: rectBounds.width - 80, height: rectBounds.width - 80)
                let path = UIBezierPath(rect: rectBounds)
                let croppedPath = UIBezierPath(rect: rect)
                path.append(croppedPath)
                path.usesEvenOddFillRule = true
                let mask = CAShapeLayer()
                mask.path = path.cgPath
                mask.fillRule = CAShapeLayerFillRule.evenOdd
                return mask
            }()
            self.activityIndicator?.stopAnimating()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.scanWorker?.cancelWithCompletion { [weak self] in
            self?.scanFinishedWithCancel()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            let orientation = AppConfig.statusBarOrientation()
            self?.scanWorker?.updateVideoToOrientation(orientation)
        }, completion: nil)
    }
}

extension DPAGScanCreateDeviceTANViewController: DPAGScanCreateDeviceTANDelegate {
    func scanFinishedWithSuccess(_ text: String) {
        if self.didCalledResultBlock == false {
            self.didCalledResultBlock = true
            self.successBlock(text)
        }
    }

    func scanFinishedWithFail() {
        if self.didCalledResultBlock == false {
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

import ZXingObjC

private protocol DPAGScanCreateDeviceTANDelegate: AnyObject {
    func scanFinishedWithSuccess(_ text: String)
    func scanFinishedWithFail()
}

private class DPAGScanCreateDeviceTANWorker: NSObject {
    private var presentationView: UIView
    private weak var scanDelegate: DPAGScanCreateDeviceTANDelegate?
    private var scanWorkerDelegate: DPAGScanCreateDeviceTANWorkerDelegate?
    private var capture: ZXCapture?

    var isValidating = false

    init(presentationView: UIView, scanDelegate: DPAGScanCreateDeviceTANDelegate) {
        self.presentationView = presentationView
        self.scanDelegate = scanDelegate
        super.init()
        self.scanWorkerDelegate = DPAGScanCreateDeviceTANWorkerDelegate(scanWorker: self)
    }

    class func createQrCode(_ tan: String, size: CGSize) throws -> UIImage? {
        let writer: ZXMultiFormatWriter = ZXMultiFormatWriter()
        let hints: ZXEncodeHints = ZXEncodeHints()
        hints.margin = NSNumber(value: 0)
        let result: ZXBitMatrix = try writer.encode(tan, format: kBarcodeFormatQRCode, width: Int32(size.width), height: Int32(size.height), hints: hints)
        if let image = ZXImage(matrix: result).cgimage {
            let retVal = UIImage(cgImage: image)
            return retVal
        }
        return nil
    }

    func verifyQRCode() {
        let capture = ZXCapture()
        capture.delegate = self.scanWorkerDelegate
        capture.rotation = 90.0
        capture.camera = capture.back()
        capture.layer.frame = self.presentationView.bounds
        self.capture = capture
        UIView.transition(with: self.presentationView, duration: 0.15, options: .transitionCrossDissolve, animations: { [weak self] in
            guard let strongSelf = self, let capture = strongSelf.capture, capture.layer != nil else { return }
            let oldState = UIView.areAnimationsEnabled
            UIView.setAnimationsEnabled(false)
            strongSelf.presentationView.layer.addSublayer(capture.layer)
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

    public func cancelWithCompletion(_ completion: DPAGCompletion?) {
        self.capture?.delegate = nil
        UIView.transition(with: self.presentationView, duration: 0.3, options: .transitionCrossDissolve, animations: { [weak self] in
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
        let isValid = (text.count == 9) || (text.count == 18)
        DPAGLog("verified QR code data: %@", NSNumber(value: isValid))
        if isValid {
            self.performBlockOnMainThread { [weak self] in
                self?.cancelWithCompletion { [weak self] in
                    self?.scanDelegate?.scanFinishedWithSuccess(text)
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

private class DPAGScanCreateDeviceTANWorkerDelegate: NSObject, ZXCaptureDelegate {
    weak var scanWorker: DPAGScanCreateDeviceTANWorker?

    init(scanWorker: DPAGScanCreateDeviceTANWorker) {
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
