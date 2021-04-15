//
//  DPAGColorProvider.swift
//  SIMSmeCore
//
//  Created by RBU on 03.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

// swiftlint:disable discouraged_object_literal
import UIKit

protocol ColorThemeProtocol {
    var primary: UIColor { get }
    var primaryContrast: UIColor { get }
    var emphasis: UIColor { get }
    var emphasisContrast: UIColor { get }
    var meBubble: UIColor { get }
    var tempColorMiddleConfidence: UIColor { get }
    var c100: UIColor { get }
    var c200: UIColor { get }
    var c300: UIColor { get }
    var c350: UIColor { get }
    var c400: UIColor { get }
    var c500: UIColor { get }
    var c600: UIColor { get }
    var c650: UIColor { get }
    var c700: UIColor { get }
    var c800: UIColor { get }
    var c850: UIColor { get }
    var c900: UIColor { get }
    var darkBlue: UIColor { get }
}

struct ColorThemeBase: ColorThemeProtocol {
    var primary: UIColor { // 00C1A7
        if DPAGApplicationFacade.preferences.isBaMandant {
            return #colorLiteral(red: 0, green: 0.2833051682, blue: 0.4406666756, alpha: 1)
        } else {
            return #colorLiteral(red: 0, green: 0.7568627451, blue: 0.6549019608, alpha: 1)
        }
    }

    var primaryContrast: UIColor { // FFFFFF
        return #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }

    var emphasis: UIColor { // DC004B
        return #colorLiteral(red: 0.862745098, green: 0, blue: 0.2941176471, alpha: 1)
    }

    var emphasisContrast: UIColor { // FFFFFF
        return #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }

    var meBubble: UIColor { // 009BAF
        return #colorLiteral(red: 0, green: 0.6078431373, blue: 0.6862745098, alpha: 1)
    }

    var tempColorMiddleConfidence: UIColor { // F99C3F
        return #colorLiteral(red: 0.9764705882, green: 0.6117647059, blue: 0.2470588235, alpha: 1)
    }

    var darkBlue: UIColor { // 0043FF
        return #colorLiteral(red: 0.1294117647, green: 0.5882352941, blue: 0.9529411765, alpha: 1)
    }

    // MARK: - cXXX

    var c100: UIColor { // FFFFFF
        return #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }

    var c200: UIColor { // F0F0F0
        return #colorLiteral(red: 0.9411764706, green: 0.9411764706, blue: 0.9411764706, alpha: 1)
    }

    var c300: UIColor { // E8E8E8
        return #colorLiteral(red: 0.9098039216, green: 0.9098039216, blue: 0.9098039216, alpha: 1)
    }

    var c350: UIColor { // E0E0E0
        return #colorLiteral(red: 0.8784313725, green: 0.8784313725, blue: 0.8784313725, alpha: 1)
    }

    var c400: UIColor { // C0C0C0
        return #colorLiteral(red: 0.7529411765, green: 0.7529411765, blue: 0.7529411765, alpha: 1)
    }

    var c500: UIColor { // B0B0B0
        return #colorLiteral(red: 0.6901960784, green: 0.6901960784, blue: 0.6901960784, alpha: 1)
    }

    var c600: UIColor { // 737373
        return #colorLiteral(red: 0.4509803922, green: 0.4509803922, blue: 0.4509803922, alpha: 1)
    }

    var c650: UIColor { // 464646
        return #colorLiteral(red: 0.2745098039, green: 0.2745098039, blue: 0.2745098039, alpha: 1)
    }

    var c700: UIColor { // 333333
        return #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    }

    var c800: UIColor { // 7B98AB
        return #colorLiteral(red: 0.4823529412, green: 0.5960784314, blue: 0.6705882353, alpha: 1)
    }
    
    var c850: UIColor { // 282828
        return #colorLiteral(red: 0.1568627451, green: 0.1568627451, blue: 0.1568627451, alpha: 1)
    }
    var c900: UIColor { // 000000
        return #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
    }
}

public class DPAGColorProvider {
    public static let shared = DPAGColorProvider()
    private var baColorProviderInstance: ColorThemeB2BManaged?
    private var darkColorProviderInstance = ColorThemeDark(theme: ColorThemeBase())
    private var lightColorProviderInstance = ColorThemeDefault(theme: ColorThemeBase())
    private var darkColorProviderInstanceB2B = ColorThemeB2BDark(theme: ColorThemeBase())
    private var lightColorProviderInstanceB2B = ColorThemeB2B(theme: ColorThemeBase())
    public var darkMode: Bool = false

    private var colorProviderInstance: ColorThemeDefault {
        if DPAGApplicationFacade.preferences.isBaMandant {
            if DPAGApplicationFacade.preferences.isCompanyManagedState, let baColorProviderInstance = baColorProviderInstance {
                return baColorProviderInstance
            } else if darkMode {
                return darkColorProviderInstanceB2B
            } else {
                return lightColorProviderInstanceB2B
            }
        } else if darkMode {
            return darkColorProviderInstance
        } else {
            return lightColorProviderInstance
        }
    }

    public func updateProviderBA() {
        self.baColorProviderInstance = ColorThemeB2BManaged(theme: ColorThemeBase())
    }

    public static let thresholdBetweenTheDarkAndTheLight = #colorLiteral(red: 0.4509803922, green: 0.4509803922, blue: 0.4509803922, alpha: 1)

    public enum ContactNameColor {
        public static let A = #colorLiteral(red: 0.6784313725, green: 0.262745098, blue: 0.6196078431, alpha: 1)
        public static let B = #colorLiteral(red: 0.6470588235, green: 0.262745098, blue: 0.6745098039, alpha: 1)
        public static let C = #colorLiteral(red: 0.568627451, green: 0.262745098, blue: 0.6784313725, alpha: 1)
        public static let D = #colorLiteral(red: 0.4901960784, green: 0.262745098, blue: 0.6784313725, alpha: 1)
        public static let E = #colorLiteral(red: 0.4078431373, green: 0.262745098, blue: 0.6784313725, alpha: 1)
        public static let F = #colorLiteral(red: 0.3254901961, green: 0.262745098, blue: 0.6784313725, alpha: 1)
        public static let G = #colorLiteral(red: 0.2745098039, green: 0.2901960784, blue: 0.6823529412, alpha: 1)
        public static let H = #colorLiteral(red: 0.262745098, green: 0.3647058824, blue: 0.6784313725, alpha: 1)
        public static let I = #colorLiteral(red: 0.262745098, green: 0.4470588235, blue: 0.6784313725, alpha: 1)
        public static let J = #colorLiteral(red: 0.262745098, green: 0.5254901961, blue: 0.6784313725, alpha: 1)
        public static let K = #colorLiteral(red: 0.262745098, green: 0.6078431373, blue: 0.6784313725, alpha: 1)
        public static let L = #colorLiteral(red: 0.2588235294, green: 0.6705882353, blue: 0.6549019608, alpha: 1)
        public static let M = #colorLiteral(red: 0.2666666667, green: 0.6784313725, blue: 0.5803921569, alpha: 1)
        public static let N = #colorLiteral(red: 0.262745098, green: 0.6784313725, blue: 0.4980392157, alpha: 1)
        public static let O = #colorLiteral(red: 0.262745098, green: 0.6784313725, blue: 0.4156862745, alpha: 1)
        public static let P = #colorLiteral(red: 0.262745098, green: 0.6784313725, blue: 0.337254902, alpha: 1)
        public static let Q = #colorLiteral(red: 0.2823529412, green: 0.6823529412, blue: 0.2745098039, alpha: 1)
        public static let R = #colorLiteral(red: 0.3529411765, green: 0.6784313725, blue: 0.262745098, alpha: 1)
        public static let S = #colorLiteral(red: 0.4352941176, green: 0.6784313725, blue: 0.2666666667, alpha: 1)
        public static let T = #colorLiteral(red: 0.5176470588, green: 0.6784313725, blue: 0.2666666667, alpha: 1)
        public static let U = #colorLiteral(red: 0.5960784314, green: 0.6784313725, blue: 0.2666666667, alpha: 1)
        public static let V = #colorLiteral(red: 0.6588235294, green: 0.6549019608, blue: 0.2549019608, alpha: 1)
        public static let W = #colorLiteral(red: 0.6784313725, green: 0.5921568627, blue: 0.262745098, alpha: 1)
        public static let X = #colorLiteral(red: 0.6784313725, green: 0.5098039216, blue: 0.262745098, alpha: 1)
        public static let Y = #colorLiteral(red: 0.6784313725, green: 0.431372549, blue: 0.262745098, alpha: 1)
        public static let Z = #colorLiteral(red: 0.6784313725, green: 0.3490196078, blue: 0.262745098, alpha: 1)
    }

    public enum DPAG {
        public static let post = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1) // FFCC00
        public static let postContrast = #colorLiteral(red: 0.1294117647, green: 0.1529411765, blue: 0.1725490196, alpha: 1) // 21272C
    }

    public enum SecurityLevel {
        public static let level0 = #colorLiteral(red: 0.6392156863, green: 0.6392156863, blue: 0.6392156863, alpha: 0)
        public static let level1 = #colorLiteral(red: 0.8392156863, green: 0.1725490196, blue: 0.01568627451, alpha: 1)
        public static let level2 = #colorLiteral(red: 0.8862745098, green: 0.337254902, blue: 0.1960784314, alpha: 1)
        public static let level3 = #colorLiteral(red: 0.968627451, green: 0.5490196078, blue: 0.09411764706, alpha: 1)
        public static let level4 = #colorLiteral(red: 1, green: 0.7215686275, blue: 0.01960784314, alpha: 1)
        public static let level5 = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)
        public static let level6 = #colorLiteral(red: 0.8039215686, green: 0.8666666667, blue: 0.09411764706, alpha: 1)
        public static let level7 = #colorLiteral(red: 0.6392156863, green: 0.8235294118, blue: 0.1019607843, alpha: 1)
        public static let level8 = #colorLiteral(red: 0.4823529412, green: 0.7764705882, blue: 0.04705882353, alpha: 1)
    }

    public enum TestLicense {
        public static let labelSubtitle = #colorLiteral(red: 1, green: 0.8, blue: 0, alpha: 1)
        public static let gradientStart = #colorLiteral(red: 0.2431372549, green: 0.2862745098, blue: 0.3058823529, alpha: 1)
        public static let gradientEnd = #colorLiteral(red: 0.06666666667, green: 0.1098039216, blue: 0.1294117647, alpha: 1)
    }

    public enum ShareExtension {
        public static let backgroundLoad = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).withAlphaComponent(0.01)
        public static let backgroundAppear = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).withAlphaComponent(0.4)
    }

    public enum Name: Int {
        case labelText
        case labelTextHint
        case labelTextForBackgroundInverted
        case labelDisabled
        case labelDestructive
        case labelLink
        case labelDeviceActivity
        case labelValidationConfirmed
        case labelValidationUnconfirmed
        case systemMessageText
        case systemMessageBackground

        case textFieldText
        case textFieldTextDisabled
        case textFieldBackground
        case placeholder

        case navigationBar
        case navigationBarTint

        case searchBar
        case searchBarTextFieldBackground
        case searchBarTint

        case datePickerText

        case passwordPIN
        case passwordPINEmpty

        case defaultViewBackground
        case defaultViewBackground2
        case defaultViewBackgroundInverted
        case backgroundLocationInfo
        case backgroundBorder
        case backgroundInput
        case backgroundInputText

        case mandantBackground
        case mandantText

        case progressHUDBackground
        case progressHUDActivityIndicator
        case progressHUDFullViewBackground
        case progressHUDFullViewActivityIndicator
        case progressHUDFullViewText
        case progressHUDFullViewProgress
        case progressHUDFullViewTrack

        case buttonTintNoBackground
        case buttonTintSelectedNoBackground
        case buttonDestructiveTintNoBackground
        case buttonOverlayBackground
        case buttonOverlayTint
        case buttonTint
        case buttonTintDisabled
        case buttonBackground
        case buttonBackgroundDisabled

        case alertTint
        case alertBackground
        case alertDestructiveTint
        case alertDestructiveBackground

        case tableSeparator
        case tableSectionIndex

        case imageSelectorTint
        case imageSelectorBackground

        case messageInputFrameBorder
        case messageSendOptionsOverlayBackground
        case messageSendOptionsTint
        case messageSendOptionsAction
        case messageSendOptionsActionContrast
        case messageSendOptionsActionHighPriority
        case messageSendOptionsActionHighPriorityContrast
        case messageSendOptionsActionSelfdestruct
        case messageSendOptionsActionSelfdestructContrast
        case messageSendOptionsActionSendDelayed
        case messageSendOptionsActionSendDelayedContrast
        case messageSendOptionsActionCancel
        case messageSendOptionsActionCancelContrast
        case messageSendOptionsActionCheck
        case messageSendOptionsActionCheckContrast
        case messageSendOptionsActionUnselected
        case messageSendOptionsActionUnselectedContrast

        case messageSendOptionsSelectedBackground
        case messageSendOptionsSelectedBackgroundContrast

        case messageSendOptionsCellBackground
        case messageSendOptionsCellBackgroundContrast

        case attachmentDownloadProgressBackground
        case attachmentDownloadProgressTint

        case selectionBorder
        case selectionOverlay

        case messageCellSendingFailedAlert
        case messageCellOOOStatusMessage

        case chatDetailsBackground
        case chatDetailsBackgroundContrast
        case chatDetailsBackground2
        case chatDetailsBackgroundCitation

        case chatDetailsBubbleMine
        case chatDetailsBubbleMineContrast
        case chatDetailsBubbleNotMine
        case chatDetailsBubbleNotMineContrast
        case chatDetailsBubbleChannel

        case chatDetailsBubbleBackgroundShortSelection1
        case chatDetailsBubbleBackgroundShortSelection2

        case chatDetailsBubbleLink

        case conversationOverviewHighlight
        case conversationOverviewSelectionSpinner
        case conversationOverviewUnreadMessages
        case conversationOverviewUnreadMessagesTint

        case settingsBackground
        case settingsViewBackground
        case settingsHeader

        case keyboard
        case keyboardContrast

        case channelDetailsLabelEnabled
        case channelDetailsLabelDisabled
        case channelDetailsText
        case channelDetailsToggle
        case channelDetailsButtonFollow
        case channelDetailsButtonFollowDisabled
        case channelDetailsButtonFollowText
        case channelDetailsButtonFollowTextDisabled

        case channelChatMessageSection
        case channelChatMessageSectionPre

        case channelIconBackground
        case channelIconOverlay

        case muteActive
        case muteInactive

        case callHangupBackground

        case cellSelection

        case introBulletItem

        case contactSelectionSelectedBackground
        case contactSelectionSelectedBackgroundFixed
        case contactSelectionNotSelectedBackground

        case segmentedControlSelected
        case segmentedControlSelectedContrast
        case segmentedControlUnselected
        case segmentedControlUnselectedContrast

        case segmentedControlRight
        case segmentedControlRightContrast
        case segmentedControlLeft
        case segmentedControlLeftContrast

        case switchOnTint
        case switchOnTintDisabled

        case imageCheck
        case imageCheckTint
        case imageUncheck
        case imageUncheckTint
        case imageSendStateReadTint
        case imageSendStateFailedTint
        case imageSendDelayedTint
        case imageSendSelfDestructTint
        case imageSendHighPriorityTint

        case contactInternal
        case contactInternalContrast

        case accountID

        case oooStatusActive
        case oooStatusInactive
        case oooStatusInactiveContrast

        case trustLevelHigh
        case trustLevelMedium
        case trustLevelLow
        case actionSheetLabel
    }

    public subscript(key: DPAGColorProvider.Name) -> UIColor {
        self.colorProviderInstance[key]
    }

    public var kColorAccentMandant: [String: UIColor] {
        [
            "default": #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            "ba": DPAGApplicationFacade.preferences.companyColorMain ?? #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            "blk": #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1),
            "vw": #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        ]
    }

    public var kColorAccentMandantContrast: [String: UIColor] {
        [
            "default": #colorLiteral(red: 0, green: 0.7568627451, blue: 0.6549019608, alpha: 1),
            "ba": DPAGApplicationFacade.preferences.companyColorMainContrast ?? #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
            "blk": #colorLiteral(red: 0, green: 0.6196078431, blue: 0.8862745098, alpha: 1),
            "vw": #colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1)
        ]
    }

    public var preferredStatusBarStyle: UIStatusBarStyle { self[.navigationBarTint].statusBarStyle(backgroundColor: self[.navigationBar]) }
}

class ColorThemeDefault {
    let theme: ColorThemeProtocol

    init(theme: ColorThemeProtocol) {
        self.theme = theme
    }

    subscript(key: DPAGColorProvider.Name) -> UIColor {
        switch key {
            case .labelText:
                return theme.c700
            case .labelTextHint:
                return theme.c700.withAlphaComponent(0.5)
            case .labelTextForBackgroundInverted:
                return theme.c100
            case .labelDisabled:
                return theme.c400
            case .labelDestructive:
                return theme.emphasis
            case .labelLink:
                return theme.primary
            case .labelDeviceActivity:
                return theme.primary
            case .labelValidationConfirmed:
                return theme.primary
            case .labelValidationUnconfirmed:
                return theme.emphasis
            case .systemMessageText:
                return theme.c700
            case .systemMessageBackground:
                return theme.c300
            case .textFieldText:
                return theme.c700
            case .textFieldBackground:
                return theme.c300
            case .textFieldTextDisabled:
                return theme.c300
            case .placeholder:
                return self[.textFieldText].withAlphaComponent(0.3)
            case .navigationBar:
                return theme.c100
            case .navigationBarTint:
                return theme.c700
            case .searchBar:
                return theme.c100
            case .searchBarTextFieldBackground:
                return theme.c300
            case .searchBarTint:
                return theme.c700
            case .datePickerText:
                return theme.c700
            case .passwordPIN:
                return theme.c700
            case .passwordPINEmpty:
                return theme.c700.withAlphaComponent(0.5)
            case .defaultViewBackground:
                return theme.c100
            case .defaultViewBackground2:
                return theme.c300
            case .defaultViewBackgroundInverted:
                return theme.c700
            case .backgroundLocationInfo:
                return theme.c100.withAlphaComponent(0.75)
            case .backgroundBorder:
                return theme.c700
            case .backgroundInput:
                return theme.c100
            case .backgroundInputText:
                return theme.c700
            case .mandantBackground:
                return theme.c700
            case .mandantText:
                return theme.c100
            case .progressHUDBackground:
                return theme.c100
            case .progressHUDActivityIndicator:
                return theme.c100
            case .progressHUDFullViewBackground:
                return theme.c100
            case .progressHUDFullViewActivityIndicator:
                return theme.c100
            case .progressHUDFullViewText:
                return theme.c100
            case .progressHUDFullViewProgress:
                return theme.c100
            case .progressHUDFullViewTrack:
                return theme.c700
            case .buttonTintNoBackground:
                return theme.primary
            case .buttonTintSelectedNoBackground:
                return theme.c700
            case .buttonDestructiveTintNoBackground:
                return theme.emphasis
            case .buttonOverlayTint:
                return theme.c100
            case .buttonOverlayBackground:
                return theme.c700
            case .buttonTint:
                return theme.primaryContrast
            case .buttonTintDisabled:
                return theme.primaryContrast
            case .buttonBackground:
                return theme.primary
            case .buttonBackgroundDisabled:
                return theme.primary.withAlphaComponent(0.5)
            case .alertTint:
                return theme.c700
            case .alertBackground:
                return theme.c100
            case .alertDestructiveTint:
                return theme.emphasisContrast
            case .alertDestructiveBackground:
                return theme.emphasis
            case .tableSeparator:
                return theme.c300
            case .tableSectionIndex:
                return theme.primary
            case .imageSelectorTint:
                return theme.c700
            case .imageSelectorBackground:
                return theme.c100.withAlphaComponent(0.5)
            case .messageInputFrameBorder:
                return self[.defaultViewBackground]
            case .messageSendOptionsOverlayBackground:
                return theme.c700.withAlphaComponent(0.3)
            case .messageSendOptionsTint:
                return theme.c700
            case .messageSendOptionsAction:
                return theme.emphasis
            case .messageSendOptionsActionContrast:
                return theme.c100
            case .messageSendOptionsActionHighPriority, .messageSendOptionsActionSelfdestruct, .messageSendOptionsActionSendDelayed, .messageSendOptionsActionCancel, .messageSendOptionsActionCheck:
                return theme.emphasis
            case .messageSendOptionsActionHighPriorityContrast, .messageSendOptionsActionSelfdestructContrast, .messageSendOptionsActionSendDelayedContrast, .messageSendOptionsActionCancelContrast, .messageSendOptionsActionCheckContrast:
                return theme.emphasisContrast
            case .messageSendOptionsActionUnselected:
                return theme.primary
            case .messageSendOptionsActionUnselectedContrast:
                return theme.primaryContrast
            case .messageSendOptionsCellBackground, .messageSendOptionsSelectedBackground:
                return theme.emphasis
            case .messageSendOptionsCellBackgroundContrast, .messageSendOptionsSelectedBackgroundContrast:
                return theme.emphasisContrast
            case .attachmentDownloadProgressTint:
                return theme.c100
            case .attachmentDownloadProgressBackground:
                return theme.c700
            case .selectionBorder:
                return theme.primary
            case .selectionOverlay:
                return theme.c100.withAlphaComponent(0.5)
            case .messageCellSendingFailedAlert:
                return theme.emphasis
            case .messageCellOOOStatusMessage:
                return theme.emphasis
            case .chatDetailsBackground:
                return theme.c200
            case .chatDetailsBackgroundContrast:
                return theme.c700
            case .chatDetailsBackground2:
                return theme.c200
            case .chatDetailsBackgroundCitation:
                return theme.c500.withAlphaComponent(0.5)
            case .chatDetailsBubbleMine:
                return theme.meBubble
            case .chatDetailsBubbleMineContrast:
                return theme.c100
            case .chatDetailsBubbleNotMine:
                return theme.c350
            case .chatDetailsBubbleNotMineContrast:
                return theme.c700
            case .chatDetailsBubbleChannel:
                return theme.c100
            case .chatDetailsBubbleLink:
                return theme.primary
            case .chatDetailsBubbleBackgroundShortSelection1:
                return self[.defaultViewBackground]
            case .chatDetailsBubbleBackgroundShortSelection2:
                return self[.defaultViewBackground].withAlphaComponent(0.9)
            case .conversationOverviewHighlight:
                return theme.primary
            case .conversationOverviewSelectionSpinner:
                return theme.c700.withAlphaComponent(0.3)
            case .conversationOverviewUnreadMessages:
                return theme.emphasis
            case .conversationOverviewUnreadMessagesTint:
                return theme.emphasisContrast
            case .settingsBackground:
                return theme.c100
            case .settingsViewBackground:
                return theme.c200
            case .settingsHeader:
                return theme.c600
            case .keyboard:
                return theme.c400
            case .keyboardContrast:
                return theme.c700
            case .channelDetailsLabelEnabled:
                return theme.c700
            case .channelDetailsLabelDisabled:
                return theme.c700
            case .channelDetailsText:
                return theme.c700
            case .channelDetailsToggle:
                return theme.primary
            case .channelDetailsButtonFollow:
                return theme.primary
            case .channelDetailsButtonFollowDisabled:
                return theme.primary.withAlphaComponent(0.3)
            case .channelDetailsButtonFollowText:
                return theme.primaryContrast
            case .channelDetailsButtonFollowTextDisabled:
                return theme.primaryContrast
            case .channelChatMessageSection:
                return theme.primary
            case .channelChatMessageSectionPre:
                return theme.c700
            case .channelIconBackground:
                return theme.c200
            case .channelIconOverlay:
                return theme.c700.withAlphaComponent(0.05)
            case .muteActive:
                return theme.emphasis
            case .muteInactive:
                return theme.c600
            case .callHangupBackground:
                return theme.emphasis.withAlphaComponent(0.9)
            case .cellSelection:
                return theme.c700.withAlphaComponent(0.1)
            case .introBulletItem:
                return theme.darkBlue
            case .contactSelectionSelectedBackground:
                return theme.primary.withAlphaComponent(0.5)
            case .contactSelectionSelectedBackgroundFixed:
                return theme.primary.withAlphaComponent(0.25)
            case .contactSelectionNotSelectedBackground:
                return theme.emphasis.withAlphaComponent(0.5)
            case .segmentedControlSelected:
                return theme.primary
            case .segmentedControlSelectedContrast:
                return theme.c100
            case .segmentedControlUnselected:
                return theme.emphasis
            case .segmentedControlUnselectedContrast:
                return theme.emphasisContrast
            case .segmentedControlRight:
                return theme.primary
            case .segmentedControlRightContrast:
                return theme.primaryContrast
            case .segmentedControlLeft:
                return theme.emphasis
            case .segmentedControlLeftContrast:
                return theme.emphasisContrast
            case .switchOnTint:
                return theme.primary
            case .switchOnTintDisabled:
                return theme.primary.withAlphaComponent(0.5)
            case .imageCheck:
                return theme.primary
            case .imageCheckTint:
                return theme.c100
            case .imageUncheck:
                return theme.emphasis
            case .imageUncheckTint:
                return theme.emphasisContrast
            case .imageSendStateReadTint, .imageSendDelayedTint:
                return theme.darkBlue
            case .imageSendStateFailedTint, .imageSendSelfDestructTint, .imageSendHighPriorityTint:
                return theme.emphasis
            case .contactInternal:
                return theme.primary
            case .contactInternalContrast:
                return theme.c100
            case .accountID:
                return theme.primary
            case .oooStatusActive:
                return theme.primary
            case .oooStatusInactive:
                return theme.emphasis
            case .oooStatusInactiveContrast:
                return theme.emphasisContrast
            case .trustLevelHigh:
                return theme.primary
            case .trustLevelMedium:
                return theme.tempColorMiddleConfidence
            case .trustLevelLow:
                return theme.emphasis
            case .actionSheetLabel:
                return self[.alertTint]
        }
    }
}
class ColorThemeDark: ColorThemeDefault {
    override subscript(key: DPAGColorProvider.Name) -> UIColor {
        switch key {
            case .labelText:
                return theme.c100
            case .labelTextHint:
                return theme.c100.withAlphaComponent(0.5)
            case .labelTextForBackgroundInverted:
                return theme.c900
            case .labelDisabled:
                return theme.c600
            case .labelDestructive:
                return theme.emphasis
            case .labelLink:
                return theme.primary
            case .labelDeviceActivity:
                return theme.primary
            case .labelValidationConfirmed:
                return theme.primary
            case .labelValidationUnconfirmed:
                return theme.emphasis
            case .systemMessageText:
                return theme.c100
            case .systemMessageBackground:
                return theme.c700
            case .textFieldText:
                return theme.c100
            case .textFieldBackground:
                return theme.c600
            case .textFieldTextDisabled:
                return theme.c600
            case .placeholder:
                return self[.textFieldText].withAlphaComponent(0.3)
            case .navigationBar:
                return theme.c900
            case .navigationBarTint:
                return theme.c100
            case .searchBar:
                return theme.c900
            case .searchBarTextFieldBackground:
                return theme.c600
            case .searchBarTint:
                return theme.c100
            case .datePickerText:
                return theme.c100
            case .passwordPIN:
                return theme.c100
            case .passwordPINEmpty:
                return theme.c100.withAlphaComponent(0.5)
            case .defaultViewBackground:
                return theme.c900
            case .defaultViewBackground2:
                return theme.c850
            case .defaultViewBackgroundInverted:
                return theme.c100
            case .backgroundLocationInfo:
                return theme.c900.withAlphaComponent(0.75)
            case .backgroundBorder:
                return theme.c100
            case .backgroundInput:
                return theme.c850
            case .backgroundInputText:
                return theme.c100
            case .mandantBackground:
                return theme.c100
            case .mandantText:
                return theme.c900
            case .progressHUDBackground:
                return theme.c850
            case .progressHUDActivityIndicator:
                return theme.c100
            case .progressHUDFullViewBackground:
                return theme.c850
            case .progressHUDFullViewActivityIndicator:
                return theme.c100
            case .progressHUDFullViewText:
                return theme.c100
            case .progressHUDFullViewProgress:
                return theme.c100
            case .progressHUDFullViewTrack:
                return theme.c100
            case .buttonTintNoBackground:
                return theme.primary
            case .buttonTintSelectedNoBackground:
                return theme.c100
            case .buttonDestructiveTintNoBackground:
                return theme.emphasis
            case .buttonOverlayTint:
                return theme.c850
            case .buttonOverlayBackground:
                return theme.c100
            case .buttonTint:
                return theme.c300
            case .buttonTintDisabled:
                return theme.primaryContrast
            case .buttonBackground:
                return theme.primary
            case .buttonBackgroundDisabled:
                return theme.primary.withAlphaComponent(0.5)
            case .alertTint:
                return theme.c100
            case .alertBackground:
                return theme.c850
            case .alertDestructiveTint:
                return theme.emphasisContrast
            case .alertDestructiveBackground:
                return theme.emphasis
            case .tableSeparator:
                return theme.c650
            case .tableSectionIndex:
                return theme.primary
            case .imageSelectorTint:
                return theme.c100
            case .imageSelectorBackground:
                return theme.c900.withAlphaComponent(0.5)
            case .messageInputFrameBorder:
                return self[.defaultViewBackground]
            case .messageSendOptionsOverlayBackground:
                return theme.c100.withAlphaComponent(0.3)
            case .messageSendOptionsTint:
                return theme.c100
            case .messageSendOptionsAction:
                return theme.emphasis
            case .messageSendOptionsActionContrast:
                return theme.c900
            case .messageSendOptionsActionHighPriority, .messageSendOptionsActionSelfdestruct, .messageSendOptionsActionSendDelayed, .messageSendOptionsActionCancel, .messageSendOptionsActionCheck:
                return theme.emphasis
            case .messageSendOptionsActionHighPriorityContrast, .messageSendOptionsActionSelfdestructContrast, .messageSendOptionsActionSendDelayedContrast, .messageSendOptionsActionCancelContrast, .messageSendOptionsActionCheckContrast:
                return theme.emphasisContrast
            case .messageSendOptionsActionUnselected:
                return theme.primary
            case .messageSendOptionsActionUnselectedContrast:
                return theme.primaryContrast
            case .messageSendOptionsCellBackground, .messageSendOptionsSelectedBackground:
                return theme.emphasis
            case .messageSendOptionsCellBackgroundContrast, .messageSendOptionsSelectedBackgroundContrast:
                return theme.emphasisContrast
            case .attachmentDownloadProgressTint:
                return theme.c900
            case .attachmentDownloadProgressBackground:
                return theme.c100
            case .selectionBorder:
                return theme.primary
            case .selectionOverlay:
                return theme.c900.withAlphaComponent(0.5)
            case .messageCellSendingFailedAlert:
                return theme.emphasis
            case .messageCellOOOStatusMessage:
                return theme.emphasis
            case .chatDetailsBackground:
                return theme.c900
            case .chatDetailsBackgroundContrast:
                return theme.c100
            case .chatDetailsBackground2:
                return theme.c600
            case .chatDetailsBackgroundCitation:
                return theme.c600.withAlphaComponent(0.5)
            case .chatDetailsBubbleMine:
                return theme.meBubble
            case .chatDetailsBubbleMineContrast:
                return theme.c100
            case .chatDetailsBubbleNotMine:
                return theme.c600
            case .chatDetailsBubbleNotMineContrast:
                return theme.c100
            case .chatDetailsBubbleChannel:
                return theme.c850
            case .chatDetailsBubbleLink:
                return theme.primary
            case .chatDetailsBubbleBackgroundShortSelection1:
                return self[.defaultViewBackground]
            case .chatDetailsBubbleBackgroundShortSelection2:
                return self[.defaultViewBackground].withAlphaComponent(0.9)
            case .conversationOverviewHighlight:
                return theme.primary
            case .conversationOverviewSelectionSpinner:
                return theme.c100.withAlphaComponent(0.3)
            case .conversationOverviewUnreadMessages:
                return theme.emphasis
            case .conversationOverviewUnreadMessagesTint:
                return theme.emphasisContrast
            case .settingsBackground:
                return theme.c850
            case .settingsViewBackground:
                return self[.defaultViewBackground]
            case .settingsHeader:
                return theme.c400
            case .keyboard:
                return theme.c900
            case .keyboardContrast:
                return theme.c100
            case .channelDetailsLabelEnabled:
                return theme.c100
            case .channelDetailsLabelDisabled:
                return theme.c100
            case .channelDetailsText:
                return theme.c100
            case .channelDetailsToggle:
                return theme.primary
            case .channelDetailsButtonFollow:
                return theme.primary
            case .channelDetailsButtonFollowDisabled:
                return theme.primary.withAlphaComponent(0.3)
            case .channelDetailsButtonFollowText:
                return theme.primaryContrast
            case .channelDetailsButtonFollowTextDisabled:
                return theme.primaryContrast
            case .channelChatMessageSection:
                return theme.primary
            case .channelChatMessageSectionPre:
                return theme.c100
            case .channelIconBackground:
                return theme.c600
            case .channelIconOverlay:
                return theme.c100.withAlphaComponent(0.05)
            case .muteActive:
                return theme.emphasis
            case .muteInactive:
                return theme.c700
            case .callHangupBackground:
                return theme.emphasis.withAlphaComponent(0.9)
            case .cellSelection:
                return theme.c100.withAlphaComponent(0.2)
            case .introBulletItem:
                return theme.darkBlue
            case .contactSelectionSelectedBackground:
                return theme.primary.withAlphaComponent(0.5)
            case .contactSelectionSelectedBackgroundFixed:
                return theme.primary.withAlphaComponent(0.25)
            case .contactSelectionNotSelectedBackground:
                return theme.emphasis.withAlphaComponent(0.5)
            case .segmentedControlSelected:
                return theme.primary
            case .segmentedControlSelectedContrast:
                return theme.c850
            case .segmentedControlUnselected:
                return theme.emphasis
            case .segmentedControlUnselectedContrast:
                return theme.emphasisContrast
            case .segmentedControlRight:
                return theme.primary
            case .segmentedControlRightContrast:
                return theme.primaryContrast
            case .segmentedControlLeft:
                return theme.emphasis
            case .segmentedControlLeftContrast:
                return theme.emphasisContrast
            case .switchOnTint:
                return theme.primary
            case .switchOnTintDisabled:
                return theme.primary.withAlphaComponent(0.5)
            case .imageCheck:
                return theme.primary
            case .imageCheckTint:
                return theme.c100
            case .imageUncheck:
                return theme.emphasis
            case .imageUncheckTint:
                return theme.emphasisContrast
            case .imageSendStateReadTint, .imageSendDelayedTint:
                return theme.darkBlue
            case .imageSendStateFailedTint, .imageSendSelfDestructTint, .imageSendHighPriorityTint:
                return theme.emphasis
            case .contactInternal:
                return theme.primary
            case .contactInternalContrast:
                return theme.c900
            case .accountID:
                return theme.primary
            case .oooStatusActive:
                return theme.primary
            case .oooStatusInactive:
                return theme.emphasis
            case .oooStatusInactiveContrast:
                return theme.emphasisContrast
            case .trustLevelHigh:
                return theme.primary
            case .trustLevelMedium:
                return theme.tempColorMiddleConfidence
            case .trustLevelLow:
                return theme.emphasis
            case .actionSheetLabel:
                return self[.alertTint]
        }
    }
}

class ColorThemeB2B: ColorThemeDefault {
}

class ColorThemeB2BDark: ColorThemeDark {
}

class ColorThemeB2BManaged: ColorThemeB2B {
    override subscript(key: DPAGColorProvider.Name) -> UIColor {
        var retVal: UIColor?
        switch key {
            case .labelText:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .labelTextHint:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.5)
            case .labelTextForBackgroundInverted:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .labelDisabled:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.3)
            case .labelDestructive:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .labelLink:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .labelDeviceActivity:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .labelValidationConfirmed:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .labelValidationUnconfirmed:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .textFieldText:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .textFieldBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.3)
            case .textFieldTextDisabled:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.3)
            case .navigationBar:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .navigationBarTint:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .searchBar:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .datePickerText:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .passwordPIN:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .passwordPINEmpty:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.5)
            case .defaultViewBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .defaultViewBackground2:
                if DPAGColorProvider.shared.darkMode {
                    retVal = DPAGApplicationFacade.preferences.companyColorMain?.lighter(by: 7) ?? DPAGApplicationFacade.preferences.companyColorMain
                } else {
                    retVal = DPAGApplicationFacade.preferences.companyColorMain?.darker(by: 7) ?? DPAGApplicationFacade.preferences.companyColorMain
                }
            case .defaultViewBackgroundInverted:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .backgroundBorder:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .backgroundInput:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .backgroundInputText:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .settingsViewBackground:
                if DPAGColorProvider.shared.darkMode {
                    retVal = DPAGApplicationFacade.preferences.companyColorMain?.lighter(by: 7) ?? DPAGApplicationFacade.preferences.companyColorMain
                } else {
                    retVal = DPAGApplicationFacade.preferences.companyColorMain?.darker(by: 7) ?? DPAGApplicationFacade.preferences.companyColorMain
                }
            case .progressHUDBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDActivityIndicator:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDFullViewBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDFullViewActivityIndicator:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDFullViewText:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDFullViewProgress:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .progressHUDFullViewTrack:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .buttonTintNoBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .buttonTintSelectedNoBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .buttonDestructiveTintNoBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .buttonOverlayTint:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .buttonOverlayBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .buttonTint:
                retVal = DPAGApplicationFacade.preferences.companyColorActionContrast
            case .buttonTintDisabled:
                retVal = DPAGApplicationFacade.preferences.companyColorActionContrast
            case .buttonBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .buttonBackgroundDisabled:
                retVal = DPAGApplicationFacade.preferences.companyColorAction?.withAlphaComponent(0.5)
            case .tableSeparator:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.3)
            case .tableSectionIndex:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .imageSelectorTint:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .imageSelectorBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMain?.withAlphaComponent(0.5)
            case .messageSendOptionsTint:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .messageSendOptionsAction:
                retVal = DPAGApplicationFacade.preferences.companyColorActionContrast
            case .messageSendOptionsActionContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .messageSendOptionsActionHighPriority, .messageSendOptionsActionSelfdestruct, .messageSendOptionsActionSendDelayed, .messageSendOptionsActionCancel, .messageSendOptionsActionCheck:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .messageSendOptionsActionHighPriorityContrast, .messageSendOptionsActionSelfdestructContrast, .messageSendOptionsActionSendDelayedContrast, .messageSendOptionsActionCancelContrast, .messageSendOptionsActionCheckContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLowContrast
            case .messageSendOptionsActionUnselected:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .messageSendOptionsActionUnselectedContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .messageSendOptionsCellBackground, .messageSendOptionsSelectedBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .messageSendOptionsCellBackgroundContrast, .messageSendOptionsSelectedBackgroundContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHighContrast
            case .attachmentDownloadProgressTint:
                retVal = DPAGApplicationFacade.preferences.companyColorMain
            case .attachmentDownloadProgressBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast
            case .selectionBorder:
                retVal = DPAGApplicationFacade.preferences.companyColorAction
            case .selectionOverlay:
                retVal = DPAGApplicationFacade.preferences.companyColorMain?.withAlphaComponent(0.5)
            case .messageCellSendingFailedAlert:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .messageCellOOOStatusMessage:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .conversationOverviewUnreadMessages:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .conversationOverviewUnreadMessagesTint:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLowContrast
            case .muteActive:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .muteInactive:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.8)
            case .cellSelection:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.1)
            case .conversationOverviewSelectionSpinner:
                retVal = DPAGApplicationFacade.preferences.companyColorMainContrast?.withAlphaComponent(0.3)
            case .contactSelectionSelectedBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh?.withAlphaComponent(0.5)
            case .contactSelectionSelectedBackgroundFixed:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh?.withAlphaComponent(0.25)
            case .contactSelectionNotSelectedBackground:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow?.withAlphaComponent(0.5)
            case .segmentedControlSelected:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .segmentedControlSelectedContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHighContrast
            case .segmentedControlRight:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .segmentedControlRightContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHighContrast
            case .segmentedControlLeft:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .segmentedControlLeftContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLowContrast
            case .switchOnTint:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .switchOnTintDisabled:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh?.withAlphaComponent(0.5)
            case .imageCheck:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .imageCheckTint:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHighContrast
            case .imageUncheck:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .imageUncheckTint:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLowContrast
            case .imageSendStateReadTint, .imageSendDelayedTint:
                return theme.darkBlue
            case .imageSendStateFailedTint, .imageSendSelfDestructTint, .imageSendHighPriorityTint:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .contactInternal:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .contactInternalContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHighContrast
            case .accountID:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .oooStatusActive:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .oooStatusInactive:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .oooStatusInactiveContrast:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLowContrast
            case .trustLevelHigh:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelHigh
            case .trustLevelMedium:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelMed
            case .trustLevelLow:
                retVal = DPAGApplicationFacade.preferences.companyColorSecLevelLow
            case .actionSheetLabel:
                if DPAGColorProvider.shared.darkMode {
                    return theme.c100
                } else {
                    return DPAGColorProvider.shared[.alertTint]
                }
            default:
                break
        }
        return retVal ?? super[key]
    }
}
