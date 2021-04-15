//
//  DPAGSubscribeServiceViewController.swift
//  SIMSme
//
//  Created by RBU on 31/01/2017.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGSubscribeServiceViewControllerProtocol: AnyObject {}

class DPAGSubscribeServiceViewController: DPAGViewControllerBackground, DPAGSubscribeServiceViewControllerProtocol, DPAGNavigationViewControllerStyler {
    private let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var viewControllersService: [UIViewController] = []
    private var services: [String: DPAGChannel] = [:]

    init() {
        super.init(nibName: nil, bundle: Bundle(for: type(of: self)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = DPAGLocalizedString("services.subscribe.title")
        self.pageViewController.view.frame = self.view.bounds
        self.pageViewController.delegate = self
        self.pageViewController.dataSource = self
        self.pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.pageViewController.willMove(toParent: self)
        self.addChild(self.pageViewController)
        self.view.addSubview(self.pageViewController.view)
        self.pageViewController.didMove(toParent: self)
        self.view.addConstraintsFill(subview: self.pageViewController.view)
    }

    override func viewFirstAppear(_ animated: Bool) {
        super.viewFirstAppear(animated)
        DPAGProgressHUD.sharedInstance.showForBackgroundProcess(true) { [weak self] _ in
            self?.updateModel()
        }
    }

    private func updateModel() {
        DPAGApplicationFacade.feedWorker.updatedFeedListWithFeedsToUpdate(forFeedType: .service) { [weak self] serviceGuids, serviceGuidsToUpdate, errorMessage in

            guard let strongSelf = self else {
                return
            }

            if let errorMessage = errorMessage {
                DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in

                    self?.showErrorAlertCheck(alertConfig: AlertConfigError(messageIdentifier: errorMessage))
                }
            } else {
                var services: [String: DPAGChannel] = [:]

                if serviceGuids.count > 0 {
                    for serviceGuid in serviceGuids {
                        guard let service = DPAGApplicationFacade.cache.channel(for: serviceGuid) else { continue }

                        if let serviceID = service.serviceID {
                            services[serviceID] = service
                        }

                        if let feedbackContactPhoneNumber = service.feedbackContactPhoneNumber, feedbackContactPhoneNumber.isEmpty == false {
                            DPAGApplicationFacade.feedWorker.checkFeedbackContactPhoneNumber(feedbackContactPhoneNumber: feedbackContactPhoneNumber, feedbackContactNickname: service.feedbackContactNickname)
                        }
                    }
                }

                if serviceGuidsToUpdate.count > 0 {
                    DPAGApplicationFacade.feedWorker.updateFeeds(feedGuids: serviceGuidsToUpdate, feedType: .service) { [weak self] serviceGuids, _, _ in

                        for serviceGuid in serviceGuids {
                            guard let service = DPAGApplicationFacade.cache.channel(for: serviceGuid) else { continue }

                            if let serviceID = service.serviceID {
                                services[serviceID] = service
                            }
                        }

                        self?.performBlockOnMainThread { [weak self] in

                            self?.services = services
                            self?.handleListNeedsUpdate()
                        }
                    }
                } else {
                    strongSelf.services = services
                    strongSelf.handleListNeedsUpdate()
                }
            }
        }
    }

    private func handleListNeedsUpdate() {
        let vcNew: [UIViewController] = []
        DPAGProgressHUD.sharedInstance.hide(true) { [weak self] in
            self?.viewControllersService = vcNew
            if let firstVC = self?.viewControllersService.first {
                self?.pageViewController.setViewControllers([firstVC], direction: .forward, animated: true, completion: nil)
            }
        }
    }
}

extension DPAGSubscribeServiceViewController: UIPageViewControllerDelegate {
    func pageViewController(_: UIPageViewController, didFinishAnimating _: Bool, previousViewControllers _: [UIViewController], transitionCompleted _: Bool) {}
}

extension DPAGSubscribeServiceViewController: UIPageViewControllerDataSource {
    func pageViewController(_: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let idx = self.viewControllersService.firstIndex(of: viewController) {
            if idx < (self.viewControllersService.count - 1) {
                return self.viewControllersService[idx + 1]
            }
        }
        return (viewController != self.viewControllersService.first) ? self.viewControllersService.first : nil
    }

    func pageViewController(_: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let idx = self.viewControllersService.firstIndex(of: viewController) {
            if idx > 0 {
                return self.viewControllersService[idx - 1]
            }
        }
        return (viewController != self.viewControllersService.last) ? self.viewControllersService.last : nil
    }
}
