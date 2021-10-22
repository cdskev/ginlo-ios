//
//  DPAGMailHelper.swift
// ginlo
//
//  Created by RBU on 17/02/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import ContactsUI
import MessageUI
import SIMSmeCore
import UIKit

public class DPAGActivityViewController: UIActivityViewController {
    var backgroundObserver: NSObjectProtocol?

    override public init(activityItems: [Any], applicationActivities: [UIActivity]?) {
        super.init(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DPAGDocumentPickerViewController: UIDocumentPickerViewController {
    var backgroundObserver: NSObjectProtocol?

    override public init(documentTypes allowedUTIs: [String], in mode: UIDocumentPickerMode) {
        super.init(documentTypes: allowedUTIs, in: mode)
    }

    override public init(url: URL, in mode: UIDocumentPickerMode) {
        super.init(url: url, in: mode)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DocumentPickerViewController: UIDocumentPickerViewController {
    var backgroundObserver: NSObjectProtocol?

    override public init(documentTypes allowedUTIs: [String], in mode: UIDocumentPickerMode) {
        super.init(documentTypes: allowedUTIs, in: mode)
    }

    override public init(url: URL, in mode: UIDocumentPickerMode) {
        super.init(url: url, in: mode)
    }

    override public init(urls: [URL], in mode: UIDocumentPickerMode) {
        super.init(urls: urls, in: mode)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DPAGMailComposeViewController: MFMailComposeViewController {
    var backgroundObserver: NSObjectProtocol?

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DPAGMessageComposeViewController: MFMessageComposeViewController {
    var backgroundObserver: NSObjectProtocol?

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main) { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DPAGImagePickerController: UIImagePickerController, DPAGNavigationControllerStatusBarStyleSetter {
    var backgroundObserver: NSObjectProtocol?

    func setup() {
        self.modalPresentationStyle = .fullScreen
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        })
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }

    override public var shouldAutorotate: Bool {
        self.sourceType != .camera
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UI_USER_INTERFACE_IDIOM() == .phone ? .allButUpsideDown : .all
    }
}

public class DPAGPeoplePickerNavigationController: CNContactPickerViewController, DPAGNavigationControllerStatusBarStyleSetter {
    var backgroundObserver: NSObjectProtocol?

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        })
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}

public class DPAGContactViewController: CNContactViewController, DPAGNavigationControllerStatusBarStyleSetter {
    var backgroundObserver: NSObjectProtocol?
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationController = self.navigationController as? DPAGNavigationControllerProtocol {
            navigationController.resetNavigationBarStyle()
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.backgroundObserver = NotificationCenter.default.addObserver(forName: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil, queue: .main, using: { [weak self] _ in
            if DPAGApplicationFacade.preferences.passwordOnStartEnabled {
                self?.dismiss(animated: false, completion: nil)
            }
        })
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let backgroundObserver = self.backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver, name: DPAGStrings.Notification.Application.DID_ENTER_BACKGROUND, object: nil)
        }
    }
}
