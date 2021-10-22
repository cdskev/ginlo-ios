//
//  DPAGChatStreamInputMediaViewController.swift
// ginlo
//
//  Created by RBU on 18/04/16.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import SIMSmeCore
import UIKit

protocol DPAGChatStreamInputMediaViewControllerDelegate: DPAGChatStreamInputBaseViewControllerDelegate {
    func inputContainerSendMedia()

    func inputContainerDidSelectMedia(at idx: Int)
    func inputContainerDidDeselectMedia(at idx: Int)
}

protocol DPAGChatStreamInputMediaViewControllerProtocol: DPAGChatStreamInputBaseViewControllerProtocol, UICollectionViewDelegate {
    var enableAdd: Bool { get set }

    var inputMediaDelegate: (DPAGChatStreamInputMediaViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)? { get set }

    var mediaResources: [DPAGMediaResource] { get set }
    var collectionViewMediaObjects: UICollectionView? { get }
}

class DPAGChatStreamInputMediaViewController: DPAGChatStreamInputBaseViewController, DPAGChatStreamInputMediaViewControllerProtocol {
    public var enableAdd: Bool = true
    private lazy var viewSendOptionsMediaNib = DPAGApplicationFacadeUI.viewChatStreamSendOptionsContent()

    @IBOutlet private var viewMedia: UIView? {
        didSet {
            self.viewMedia?.accessibilityIdentifier = "viewMedia"
            self.viewMedia?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
        }
    }

    override
    func handleDesignColorsUpdated() {
        super.handleDesignColorsUpdated()
        self.viewMedia?.backgroundColor = DPAGColorProvider.shared[.defaultViewBackground]
    }

    @IBOutlet var collectionViewMediaObjects: UICollectionView? {
        didSet {
            self.collectionViewMediaObjects?.accessibilityIdentifier = "collectionViewMediaObjects"
            self.collectionViewMediaObjects?.allowsMultipleSelection = false
            self.collectionViewMediaObjects?.register(DPAGApplicationFacadeUI.cellMediaSendingNib(), forCellWithReuseIdentifier: "Cell")
        }
    }

    var mediaResources: [DPAGMediaResource] = []

    weak var inputMediaDelegate: (DPAGChatStreamInputMediaViewControllerDelegate & DPAGChatStreamSendOptionsContentViewDelegate)? {
        didSet {
            self.inputDelegate = self.inputMediaDelegate
        }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.autoHideSendOptions = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
//        self.contentSizeObserver?.invalidate()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            self.inputMediaDelegate = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func executeSendTapped() {
        self.inputMediaDelegate?.inputContainerSendMedia()
    }

    override var viewSendOptionsNibInstance: (UIView & DPAGChatStreamSendOptionsContentViewProtocol)? {
        self.viewSendOptionsMediaNib
    }
}

// MARK: - UICollectionViewDataSource

extension DPAGChatStreamInputMediaViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        if AppConfig.isShareExtension {
            let preferences = DPAGApplicationFacadeShareExt.preferences

            return self.mediaResources.count + (self.enableAdd && (self.mediaResources.count < preferences.maximumNumberOfMediaAttachments) ? 1 : 0)
        } else {
            let preferences = DPAGApplicationFacade.preferences

            return self.mediaResources.count + (self.enableAdd && (self.mediaResources.count < preferences.maximumNumberOfMediaAttachments) ? 1 : 0)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellDequeued = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)

        guard let cell = cellDequeued as? (UICollectionViewCell & DPAGMediaSendingCollectionViewCellProtocol) else { return cellDequeued }

        let mediaObjectIndex = indexPath.row

        if mediaObjectIndex < self.mediaResources.count {
            let mediaResource = self.mediaResources[mediaObjectIndex]

            cell.setup(mediaResource: mediaResource)
        } else {
            cell.setupAddImage()
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension DPAGChatStreamInputMediaViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.inputMediaDelegate?.inputContainerDidSelectMedia(at: indexPath.item)
    }

    func collectionView(_: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        self.inputMediaDelegate?.inputContainerDidDeselectMedia(at: indexPath.item)
    }
}
