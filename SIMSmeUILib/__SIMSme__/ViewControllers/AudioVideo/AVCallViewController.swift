//
//  AVCallViewController.swift
//  SIMSmeUILib
//
// JitsiView Controller (AVCallViewController)
//  Copyright © 2020 ginlo.net GmbH
//

import AVKit

import NotificationCenter
import SIMSmeCore
import UIKit
import JitsiMeetSDK

class AVCallViewController: UIViewController, JitsiMeetViewDelegate {
    private var roomName: String?
    private var roomPassword: String?
    private var roomServer: String
    private var isOutgoingCall: Bool = false
    private var ringingOtherSide: Bool = false
    public static var isInAVCall: Bool = false
    fileprivate var pipViewCoordinator: PiPViewCoordinator?
    fileprivate var jitsiMeetView: JitsiMeetView?
    private var isVideoCall: Bool = true
    private var localUser: String?
    let defaultServer: String = AppConfig.voipAVCServer

    init(room: String, password: String, server: String, localUser: String?, isVideo: Bool, isOutgoingCall: Bool) {
        self.roomName = room
        self.roomPassword = password
        self.isVideoCall = isVideo
        self.localUser = localUser
        self.isOutgoingCall = isOutgoingCall
        self.roomServer = defaultServer
        if server != "" {
            self.roomServer = server
        }

        super.init(nibName: String(describing: AVCallViewController.self), bundle: Bundle(for: AVCallViewController.self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        cleanUp()
        AVCallViewController.isInAVCall = true
        super.viewDidLoad()
        self.jitsiMeetView = JitsiMeetView()
        let options = JitsiMeetConferenceOptions.fromBuilder{ (builder) in
            builder.serverURL = URL(string: "https://" + self.roomServer)
            builder.welcomePageEnabled = false
            builder.room = self.roomName
            builder.audioOnly = !self.isVideoCall
            builder.audioMuted = false
            builder.userInfo = JitsiMeetUserInfo(displayName: self.localUser, andEmail: nil, andAvatar: nil)
            builder.subject = " "
            builder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            builder.setFeatureFlag("calendar.enabled", withBoolean: false)
            builder.setFeatureFlag("add-people.enabled", withBoolean: false)
            builder.setFeatureFlag("tile-view.enabled", withBoolean: false)
            builder.setFeatureFlag("close-captions.enabled", withBoolean: false)
            builder.setFeatureFlag("chat.enabled", withBoolean: false)
            builder.setFeatureFlag("invite.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-password.enabled", withBoolean: false)
            builder.setFeatureFlag("recording.enabled", withBoolean: false)
            builder.setFeatureFlag("ios.recording.enabled", withBoolean: false)
            // The following might be a good idea to enable:
            builder.setFeatureFlag("call-integration.enabled", withBoolean: false)
            builder.setFeatureFlag("live-streaming.enabled", withBoolean: false)
            // For now:
            builder.setFeatureFlag("pip.enabled", withBoolean: false)
            builder.setFeatureFlag("raise-hand.enabled", withBoolean: true)

        }
        jitsiMeetView?.delegate = self
        jitsiMeetView?.join(options)
        if let jitsiMeetView = jitsiMeetView {
            pipViewCoordinator = PiPViewCoordinator(withView: jitsiMeetView)
            pipViewCoordinator?.configureAsStickyView(withParentView: view)
        }
        jitsiMeetView?.alpha = 0
        pipViewCoordinator?.show()
        if isOutgoingCall {
            ringingOtherSide = true
        }

    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        let rect = CGRect(origin: CGPoint.zero, size: size)
        pipViewCoordinator?.resetBounds(bounds: rect)
    }

    private func cleanUp() {
        AVCallViewController.isInAVCall = false
        jitsiMeetView?.removeFromSuperview()
        jitsiMeetView = nil
        pipViewCoordinator = nil
        if isOutgoingCall && ringingOtherSide {
            // - stop ringing
            ringingOtherSide = false
        }
    }
    
    func conferenceWillJoin(_ data: [AnyHashable: Any]!) {
    }
    
    func conferenceJoined(_ data: [AnyHashable: Any]!) {
        DPAGApplicationFacadeUIBase.sharedApplication?.isIdleTimerDisabled = true
    }
    
    func conferenceTerminated(_ data: [AnyHashable: Any]!) {
        DispatchQueue.main.async {
            self.dismiss(animated: true)
            self.pipViewCoordinator?.hide { _ in
                self.cleanUp()
             }
        }
        DPAGSimsMeController.sharedInstance.pushToChatEnabled = true
        DPAGApplicationFacadeUIBase.sharedApplication?.isIdleTimerDisabled = true
    }

    func participantJoined(_ data: [AnyHashable: Any]!) {
        if isOutgoingCall && ringingOtherSide {
            // stop ringing
            ringingOtherSide = false
        }
    }
    
    func participantLeft(_ data: [AnyHashable: Any]!) {
        if let remainingParticipants = data["numParticipants"] as? Int, remainingParticipants <= 1 {
            jitsiMeetView?.leave()
        }
    }
    
    func participantKicked(_ data: [AnyHashable: Any]!) {
        participantLeft(data)
    }
    
    func suspendDetected(_ data: [AnyHashable: Any]!) {
    }
    
    func readyToClose(_ data: [AnyHashable: Any]!) {
    }

    func enterPicture(inPicture data: [AnyHashable: Any]!) {
        DispatchQueue.main.async {
            self.pipViewCoordinator?.enterPictureInPicture()
        }
    }
    
}
