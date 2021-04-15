//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import AVFoundation
import SIMSmeCore
import UIKit

public struct DPAGApplicationFacadeUIMedia {
    private init() {}

    static func mediaContentFileVC(index: Int, mediaResource: DPAGMediaResource) -> (UIViewController & DPAGMediaContentFileViewControllerProtocol) { DPAGMediaContentFileViewController(index: index, mediaResource: mediaResource) }
    public static func mediaContentImageVC(index: Int, mediaResource: DPAGMediaResource) -> (UIViewController & DPAGMediaContentImageViewControllerProtocol) { DPAGMediaContentImageViewController(index: index, mediaResource: mediaResource) }
    public static func mediaContentVideoVC(index: Int, mediaResource: DPAGMediaResource) -> (UIViewController & DPAGMediaContentVideoViewControllerProtocol) { DPAGMediaContentVideoViewController(index: index, mediaResource: mediaResource) }
    static func mediaPlayerVC(playerItem: AVPlayerItem) -> (UIViewController & DPAGMediaPlayerViewControllerProtocol) { DPAGMediaPlayerViewController(playerItem: playerItem) }
    public static func mediaDetailVC(mediaResources: [DPAGMediaResource], index: Int, contentViewDelegate: DPAGMediaContentViewDelegate?, mediaResourceForwarding: DPAGMediaResourceForwarding?) -> (UIViewController & DPAGMediaDetailViewControllerProtocol) { DPAGMediaDetailViewController(mediaResources: mediaResources, index: index, contentViewDelegate: contentViewDelegate, mediaResourceForwarding: mediaResourceForwarding) }
    static func mediaVC() -> (UIViewController & DPAGMediaViewControllerProtocol) { DPAGMediaViewController() }
    static func mediaFilesVC() -> (UIViewController & DPAGMediaFilesViewControllerProtocol) { DPAGMediaFilesViewController() }
    public static func mediaOverviewVC(mediaResourceForwarding: @escaping DPAGMediaResourceForwarding) -> (UIViewController) { DPAGMediaOverviewViewController(mediaResourceForwarding: mediaResourceForwarding) }
    public static func mediaSelectSingleVC() -> (UIViewController & DPAGMediaSelectSingleViewControllerProtocol) { DPAGMediaSelectSingleViewController(showFiles: true) }
    public static func mediaSelectMultiVC(selectionType: DPAGMediaSelectionOptions, selection: [DPAGDecryptedAttachment]) -> (UIViewController & DPAGMediaSelectMultiViewControllerProtocol) { DPAGMediaSelectMultiViewController(selectionType: selectionType, selection: selection) }
    public static func mediaSelectSingleNoFilesVC() -> (UIViewController & DPAGMediaSelectSingleViewControllerProtocol) { DPAGMediaSelectSingleViewController(showFiles: false) }
    static func mediaOverviewSearchResultsVC(delegate: DPAGMediaOverviewSearchResultsViewControllerDelegate) -> UIViewController & DPAGMediaOverviewSearchResultsViewControllerProtocol { DPAGMediaOverviewSearchResultsViewController(delegate: delegate) }
    static func cellMediaNib() -> UINib { UINib(nibName: "DPAGMediaCollectionViewCell", bundle: Bundle(for: DPAGMediaCollectionViewCell.self)) }
    static func cellMediaFileNib() -> UINib { UINib(nibName: "DPAGMediaFileTableViewCell", bundle: Bundle(for: DPAGMediaFileTableViewCell.self)) }
}
