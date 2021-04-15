//
//  ApplicationRouter.swift
//  SIMSmeUILib
//

import SIMSmeCore

class ApplicationRouter: ApplicationRouterProtocol {
    weak var navigationController: UINavigationController?

    func showContacts() {
        guard let nextVC = DPAGApplicationFacade.preferences
            .viewControllerContactSelectionForIdent(.dpagNavigationDrawerViewController_startContactController,
                                                    contactsSelected: DPAGSearchListSelection<DPAGContact>())
        else { return }
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextVC, animated: true)
    }

    func showFiles() {
        let nextViewController = DPAGApplicationFacadeUIMedia.mediaOverviewVC(mediaResourceForwarding: mediaResourceForwarding())
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextViewController, animated: true)
    }

    func showDevices() {
        let nextViewController = DPAGApplicationFacadeUISettings.devicesVC()
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextViewController, animated: true)
    }

    func showChannels() {
        let nextViewController = DPAGApplicationFacadeUI.channelSubscribeVC()
        DPAGApplicationFacadeUIBase.containerVC.pushSecondaryViewController(nextViewController, animated: true)
    }

    func showServices() {
    }

    private func mediaResourceForwarding() -> DPAGMediaResourceForwarding {
        let forwarding: DPAGMediaResourceForwarding = { mediaResource in
            let navigationController = DPAGApplicationFacadeUIBase.containerVC.secondaryNavigationController
            let activeChatsVC = DPAGApplicationFacadeUIContacts.activeChatsVC()
            activeChatsVC.completionOnSelectReceiver = { receiver in
                let streamGuidReceiver = (receiver as? DPAGContact)?.streamGuid ?? (receiver as? DPAGGroup)?.guid
                let streamNameReceiver = (receiver as? DPAGContact)?.displayName ?? (receiver as? DPAGGroup)?.name
                guard let streamGuid = streamGuidReceiver, let streamName = streamNameReceiver else { return }
                DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { _ in
                    DPAGChatHelper.openChatStreamView(streamGuid, navigationController: navigationController, startChatWithUnconfirmedContact: true, draftMediaResource: mediaResource) { streamVC in
                        streamVC?.title = streamName
                        DPAGProgressHUD.sharedInstance.hide(true)
                    }
                }
            }
            if let presentedViewController = navigationController.presentedViewController {
                presentedViewController.dismiss(animated: true) {
                    navigationController.pushViewController(activeChatsVC, animated: true)
                }
            } else {
                navigationController.pushViewController(activeChatsVC, animated: true)
            }
        }
        return forwarding
    }
}
