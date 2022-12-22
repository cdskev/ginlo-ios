//
//  DPAGApplicationFacadeUI.swift
//  SIMSmeUILib
//
//  Created by RBU on 26.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CoreLocation
import HPGrowingTextView
import MapKit
import SIMSmeCore
import UIKit

protocol DPAGChatStreamInputBaseViewControllerDelegate: NSObjectProtocol {
  func inputContainerSizeSizeChangedWithDiff(_ diff: CGFloat)
  
  func inputContainerSendText(_ textToSend: String)
  func inputContainerSendMemoji(_ medias: [DPAGMediaResource], sendMessageOptions sendOptions: DPAGSendMessageSendOptions?)
  
  func inputContainerMaxHeight() -> CGFloat
  
  func inputContainerInitDraft()
  func inputContainerTextPlaceholder() -> String?
  
  func inputContainerShowsAdditionalView(_ isShowingView: Bool)
  
  func inputContainerCanExecuteSendMessage() -> Bool
  
  func inputContainerAddAttachment()
  func inputContainerCitationCancel()
  
  var inputContainerCitationEnabled: Bool { get }
  
  func inputContainerTextViewDidChange()
}

protocol DPAGChatStreamInputBaseViewControllerProtocol: DPAGChatStreamCitationViewDelegate, DPAGChatStreamSendOptionsContentViewDelegate {
  var textView: HPGrowingTextView? { get }
  var sendOptionsContainerView: (UIView & DPAGChatStreamSendOptionsContentViewProtocol)? { get }
  
  var btnAdd: UIButton? { get }
  var inputTextContainer: DPAGStackViewContentView! { get }
  
  var keyboardDidHideCompletion: DPAGCompletion? { get set }
  
  var inputDisabled: Bool { get }
  
  func updateInputState(_ inputDisabled: Bool, animated: Bool)
  func updateViewBeforeMessageWillSend()
  func updateViewAfterMessageWasSent()
  
  var sendOptionsEnabled: Bool { get set }
  
  func sendOptionSelected(sendOption: DPAGChatStreamSendOptionsViewSendOption)
  func getSendOptions() -> DPAGSendMessageSendOptions?
  func dismissSendOptionsView(animated: Bool)
  func dismissSendOptionsView(animated: Bool, completion: DPAGCompletion?)
  func resetSendOptions()
  
  func handleCommentMessage(for decryptedMessage: DPAGDecryptedMessage)
  func dismissCitationView()
}

protocol DPAGChatBaseViewControllerProtocol: AnyObject {
  var draftTextMessage: String? { get set }
  var sendingDelegate: DPAGSendingDelegate? { get set }
  var inputController: (UIViewController & DPAGChatStreamInputBaseViewControllerProtocol)? { get }
  func sendCallInvitation(room: String, password: String, server: String)
  func sendAVCallAccepted(room: String, password: String, server: String)
  func sendAVCallRejected(room: String, password: String, server: String)
}

protocol DPAGChatStreamBaseViewControllerProtocol: DPAGSendAVViewControllerDelegate & DPAGChatBaseViewControllerProtocol & DPAGSendViewControllerDelegate {
  var showMessageGuid: String? { get set }
  var mediaToSend: DPAGMediaResource? { get set }
  var fileToSend: URL? { get set }
  var streamGuid: String { get }
  
  func createModel()
}

protocol DPAGSendViewControllerDelegate: AnyObject {
  func sendTextWithWorker(_ text: String, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?)
  func sendMediaWithWorker(_ media: DPAGMediaResource, sendMessageOptions sendOptions: DPAGSendMessageSendOptions?)
}

protocol DPAGSendLocationViewControllerDelegate: AnyObject {
  func sendLocationViewController(_ sendLocationViewController: UIViewController & DPAGShowLocationViewControllerDelegate, selectedLocation location: CLLocation, mapSnapshot image: UIImage, address: String)
}

protocol DPAGShowLocationViewControllerDelegate: AnyObject {
  func userLocationDidUpdate(_ location: CLLocation)
}

protocol DPAGShowLocationViewControllerProtocol: AnyObject {
  var locationDelegate: DPAGShowLocationViewControllerDelegate? { get set }
  
  var lastValidLocation: CLLocation? { get }
  var pinLocation: CLLocation? { get set }
  var automaticallyZoom: Bool { get set }
  
  func mapCamera() -> MKMapCamera
  func zoomMapToLocation(_ location: CLLocation)
  func refreshLocationLookup()
}

protocol DPAGChatStreamCitationViewProtocol: AnyObject {
  var delegate: DPAGChatStreamCitationViewDelegate? { get set }
  
  func configureCitation(for decryptedMessage: DPAGDecryptedMessage)
}
