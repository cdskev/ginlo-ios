//
//  DPAGProximityHelper.swift
//  SIMSme
//
//  Created by RBU on 08/11/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreMotion
import SIMSmeCore
import UIKit

public protocol DPAGProximityHelperProtocol: AnyObject {
    func startMotionMonitoring()
    func stopMotionMonitoring()

    func startProximityMonitoring()
    func stopProximityMonitoring()
}

class DPAGProximityHelper {
    var isObservingProximityChanges = false
    private var isMonitoringPausedForInactiveState = false

    // Used to read the accelerometer data
    var motionManager = CMMotionManager()
    // Used to deactivate the proximity monitoring when there's no movement detected
    var motionTimer: Timer?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillResignActive(_:)), name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive(_:)), name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)

        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.accelerometerUpdateInterval = 0.1
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.WILL_RESIGN_ACTIVE, object: nil)
        NotificationCenter.default.removeObserver(self, name: DPAGStrings.Notification.Application.DID_BECOME_ACTIVE, object: nil)
    }

    private func handleAccelerometerData(_ accelerometerData: CMAccelerometerData) {
        let x: Double = accelerometerData.acceleration.x
        let y: Double = accelerometerData.acceleration.y
        let z: Double = accelerometerData.acceleration.z

        let gForce: Double = sqrt((x * x) + (y * y) + (z * z))
        // NSLog(@"%@", @(gForce))

        if gForce > 0.9, gForce < 1.1 {
            // Stop proximity monitoring after 2 seconds
            if (self.motionTimer?.isValid ?? false) == false {
                self.motionTimer = Timer.scheduledTimer(timeInterval: TimeInterval(2), target: self, selector: #selector(motionTimerTick), userInfo: nil, repeats: false)
                self.motionTimer?.tolerance = 0.3
            }
        } else {
            self.motionTimer?.invalidate()
            self.motionTimer = nil

            self.startProximityMonitoring()
        }
    }

    @objc
    private func motionTimerTick() {
        if (DPAGApplicationFacadeUIBase.audioHelper.audioRecorder?.isRecording ?? false) == false, (DPAGApplicationFacadeUIBase.audioHelper.audioPlayer?.isPlaying ?? false) == false {
            self.stopProximityMonitoring()
        }
        self.motionTimer = nil
    }

    @objc
    private func handleWillResignActive(_: Notification) {
        if self.isObservingProximityChanges {
            self.stopProximityMonitoring()
            self.isMonitoringPausedForInactiveState = true
        }
    }

    @objc
    private func handleDidBecomeActive(_: Notification) {
        if self.isMonitoringPausedForInactiveState {
            self.isMonitoringPausedForInactiveState = false
            self.startProximityMonitoring()
        }
    }
}

extension DPAGProximityHelper: DPAGProximityHelperProtocol {
    func startMotionMonitoring() {
        if self.motionManager.isAccelerometerAvailable, self.motionManager.isAccelerometerActive == false {
            self.motionTimer?.invalidate()
            self.motionTimer = nil

            let handler: CMAccelerometerHandler = { [weak self] accelerometerData, _ in

                if let strongSelf = self, let accelerometerDataOpt = accelerometerData {
                    strongSelf.handleAccelerometerData(accelerometerDataOpt)
                }
            }
            self.motionManager.startAccelerometerUpdates(to: OperationQueue.main, withHandler: handler)
        }
    }

    func stopMotionMonitoring() {
        self.motionManager.stopAccelerometerUpdates()

        self.stopProximityMonitoring()
    }

    func startProximityMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = true
        self.isObservingProximityChanges = true
    }

    func stopProximityMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = false
        self.isObservingProximityChanges = false
    }
}
