//
//  DPAGImageProvider.swift
//  SIMSmeCore
//
//  Created by RBU on 03.05.18.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public class DPAGImageProvider {
    public static let shared = DPAGImageProvider()

    public static let kSizeBarButton = CGSize(width: 30, height: 30)

    private var imageProviderInstance = DPAGImageNameProvider()

    public func updateProviderBA() {
        self.imageProviderInstance = DPAGImageNameProviderB2B()
    }

    public enum Name: String {
        // main bundle
        case kImageChatSystemLogo = "Logo_Systemchat"

        case kImageLogoDPAG = "Logo_DPAG"
        case kImageLaunchBackground = "Screen_Background"
        case kImageLaunchLogo = "Launch_Logo_Ginlo"

        case kImageChatListSystemChatBackground = "SystemChat_Background_List"

        // framework bundle
        case kImagePriority = "priority"

        case kImageAttachmentRecord = "foto"
        case kImageAttachmentAlbum = "library"
        case kImageAttachmentLocation = "location"
        case kImageAttachmentContact = "contact"
        case kImageAttachmentFile = "folders"
        case kImageAttachmentSIMSmeMedia = "simsmefile"

        case kImagePlaceholderGroup = "Placeholder_Group"
        case kImagePlaceholderSingle = "Placeholder_Profile_Single"

        case kImageChatPreviewDestroy = "Media_Destroy"
        case kImageChatPreviewAudio = "Media_Audio"
        case kImageChatPreviewVideo = "Media_Video"
        case kImageChatPreviewImage = "Media_Image"
        case kImageChatPreviewFile = "Media_File"
        case kImageChatPreviewContact = "Media_Contact"
        case kImageChatPreviewTimedMessage = "Media_Timed"
        case kImageChatPreviewHighPriority = "Media_Important"

        case kImageSendStateSent = "MessageStateSent"
        case kImageSendStateReceived = "MessageStateReceived"
        case kImageSendStateRead = "MessageStateRead"
        case kImageSendStateFailed = "MessageStateError"

        case kImageStar = "Star"

        case kImageChannelSortAsc = "Channel_Sort_Asc"
        case kImageChannelSortDesc = "Channel_Sort_Desc"

        case kImageChannelDescriptionShow = "Channel_Description_Open"
        case kImageChannelDescriptionHide = "Channel_Description_Close"
        case kImageChannelDetailsBackground = "Channel_Details_Background"

        case kImageChannelContact = "Channel_Contact"
        case kImageChannelInfo = "Channel_Info"
        case kImageChannelLike = "Channel_Like"
        case kImageChannelSoundsOff = "Channel_Sounds_Off"
        case kImageChannelSoundsOn = "Channel_Sounds"
        case kImageChannelStorno = "Channel_Storno"

        case kImageChannelCategoriesAll = "ChannelCategory_All"
        case kImageChannelCategoriesBusiness = "ChannelCategory_Business"
        case kImageChannelCategoriesGames = "ChannelCategory_Games"
        case kImageChannelCategoriesLifestyle = "ChannelCategory_Lifestyle"
        case kImageChannelCategoriesLocal = "ChannelCategory_Local"
        case kImageChannelCategoriesNews = "ChannelCategory_News"
        case kImageChannelCategoriesShopping = "ChannelCategory_Shopping"
        case kImageChannelCategoriesSport = "ChannelCategory_Sport"
        case kImageChannelCategoriesTechnic = "ChannelCategory_Technic"
        case kImageChannelCategoriesTravel = "ChannelCategory_Travel"
        case kImageChannelCategoriesWeather = "ChannelCategory_Weather"

        case kImageMenuNewStartNewChat = "menu_new_chat"
        case kImageMenuNewStartNewGroup = "menu_new_group"
        case kImageMenuNewStartNewMailingList = "menu_new_mailing_list"
        case kImageMenuNewInviteFriends = "menu_new_invite_friends"

        case kImageBarButtonNavAdd = "Nav_Add"
        case kImageBarButtonNavBack = "Nav_Back"
        case kImageBarButtonNavCheck = "Nav_Check"
        case kImageBarButtonNavClose = "Nav_Close"
        case kImageBarButtonNavContact = "Nav_Contact"
        case kImageBarButtonNavContactSilent = "Nav_ContactSilent"
        case kImageBarButtonNavGroup = "Nav_Group"
        case kImageBarButtonNavGroupSetSilent = "Nav_GroupSetSilent"

        case kImageBarButtonSettings = "Btn_Settings"
        case kImageBarButtonChat = "Btn_Chat"

        case kImageButtonAlert = "Btn_Alert"
        case kImageReload = "Btn_Reload"

        case kImageDeviceComputer = "deviceComputer"
        case kImageDeviceIPhone = "deviceIPhone"
        case kImageDeviceAndroid = "deviceAndroid"
        case kImageDeviceSmartphone = "deviceSmartphone"

        case kImageDeviceBackupLarge = "DeviceBackup_Large"
        case kImageDeviceCreateLarge = "DeviceCreate_Large"
        case kImageAlertLarge = "Alert_Large"

        case kImageChannelsLoadMore = "Btn_Softload"

        case kImageChatAttachment = "attachement"
        case kImageChatAddObject = "Btn_Chat_Add_Object"
        case kImageChatSend = "send"
        case kImageChatSoundRecord = "Btn_Sound_Record_Inactive"
        case kImageChatSoundStop = "Btn_Sound_Record_Active"
        case kImageChatSoundPlay = "Btn_Sound_Play"
        case kImageChatSelfdestruct = "Btn_Send_SelfDestruct"
        case kImageChatSendOptions = "Btn_Send_Options"
        case kImageChatSendTimed = "Btn_Send_Timed"
        case kImageChatTrash = "Btn_Trash"
        case kImageShare = "Btn_Share"
        case kImageChatOpenSendOptions = "Btn_Sound_Timer"
        case kImageClose = "close"

        case kImageChatCellPlaceholderContact = "Btn_Contacts"
        case kImageChatCellOverlayAudioPlay = "Overlay_AudioPlay"
        case kImageChatCellUnderlayAudio = "Underlay_Audio"
        case kImageChatCellOverlayVideoPlay = "Overlay_VideoPlay"
        case kImageChatCellOverlayCheck = "Overlay_Check"

        case kImageChatCellOverlayImageLoading = "Overlay_Image_Loading"
        case kImageChatCellOverlayVideoLoading = "Overlay_Video_Loading"

        case kImageSelfDestructFinished = "szfEnde"
        case kImageChatMessageFingerprint = "Fingerprint"

        case kImageLockedSmall = "Locked_Small"
        case kImageFingerprint = "Fingerprint-1"
        case kImageFingerprintSmall = "Fingerprint-1_small"
        case kImageOverlayCamera = "Overlay_Camera"

        case kImageRecoveryBusiness = "Image_Recovery_Code"
        case kImageRecoveryMail = "Image_Recovery_Code_Mail"
        case kImageRecoverySMS = "Image_Recovery_Code_SMS"

        case kImageSoundAnimation = "sound_animation_large"
        case kImageSoundAnimationInput = "sound_animation"
        case kImageChatCellOverlayDestructiveChannel = "szf_overlay_channel"
        case kImageChatCellOverlayDestructive = "szf_ico_"
        case kImagePlaceholderSound = "Placeholder_Sound"
        case kImageSoundBackground = "Sound_Animation_Background"

        case KImageChannelSubscribedCheckmark = "channel_subscribed_checkmark"

        case kImageFileAny = "File_Any"
        case kImageFileArchive = "File_Archive"
        case kImageFileKeynote = "File_Keynote"
        case kImageFileNumbers = "File_Numbers"
        case kImageFilePages = "File_Pages"
        case kImageFilePdf = "File_Pdf"
        case kImageAttachmentArrow = "arrow"

        case kImageContactsMail = "Contacts_Mail"
        case kImageContactsSearch = "Contacts_Search"

        case kImageContactsPrivate = "Contacts_Phone"
        case kImageContactsDomain = "Contacts_Domain"
        case kImageContactsCompany = "Contacts_Company"

        case kImageCloud = "Image_Cloud"
        case kImageCloudWhite = "Image_Cloud_White"

        case kImageThirty = "Image_Thirty"
        case kImageAddPhoto = "iconAddAPhoto"

        case kBALogo = "baLogo"
        case kBASignet = "baSignet"

        case kImageProcessUpcoming = "iconProcessUpcoming"

        case kVideoOn = "VideoOn"
        case kVideoOff = "VideoOff"
        case kMicOn = "MicOn"
        case kMicOff = "MicOff"
        case kSpeakerOn = "SpeakerOn"
        case kSpeakerOff = "SpeakerOff"
        case kPhone = "phone"
        case kPhoneFill = "phone_fill"
        case kVideo = "video"
        
        case kPersonCircleBadgeCheck = "person_circle_badge_check"
        case kPersonCircleBadgeCheckFill = "person_circle_badge_check_fill"
        case kPersonBadgeAdd = "person_badge_add"
        case kPersonFill = "person_fill"
        case kEllipsis = "ellipsis"
        case kEllipsisCircle = "ellipsis_circle"
        case kEllipsisCircleFill = "ellipsis_circle_fill"
        case kBellSlash = "bell_slash"
        case kBell = "bell"
        case kPencil = "pencil"
        case kPencilCircle = "pencil_circle"
        case kPencilCircleFill = "pencil_circle_fill"
        case kPencilRectangle = "pencil_rectangle"
        case kEdit = "edit"
        case kBubbleRightFill = "bubble_right_fill"
        case kScan = "scan"
        case kDeleteLeft = "delete_left"
        case kDeleteLeftFill = "delete_left_fill"
        case kMinusCircle = "minus_circle"
        case kMinusCircleFill = "minus_circle_fill"
        case kShare = "share"
        case kShareFill = "share_fill"
        case kClear = "clear"
        case kArrowSquareUp = "arrow_square_up"
        case kEye = "eye"
        case kEyeGlasses = "eyeglasses"
        case kMagnifyingGlassCircle = "magnifyingglas.circle"
        
        case kFileExt_ai = "ai"
        case kFileExt_audio = "audio"
        case kFileExt_csv = "csv"
        case kFileExt_doc = "doc"
        case kFileExt_document = "document"
        case kFileExt_docx = "docx"
        case kFileExt_dwg = "dwg"
        case kFileExt_dxf = "dxf"
        case kFileExt_emf = "emf"
        case kFileExt_exe = "exe"
        case kFileExt_flash = "flash"
        case kFileExt_h = "h"
        case kFileExt_html = "html"
        case kFileExt_image = "image"
        case kFileExt_ind = "ind"
        case kFileExt_indd = "indd"
        case kFileExt_iso = "iso"
        case kFileExt_js = "js"
        case kFileExt_key = "key"
        case kFileExt_mind = "mind"
        case kFileExt_mindmap = "mindmap"
        case kFileExt_numbers = "numbers"
        case kFileExt_odb = "odb"
        case kFileExt_odf = "odf"
        case kFileExt_odg = "odg"
        case kFileExt_odp = "odp"
        case kFileExt_ods = "ods"
        case kFileExt_odt = "odt"
        case kFileExt_pages = "pages"
        case kFileExt_pdf = "pdf"
        case kFileExt_pgp = "pgp"
        case kFileExt_ppt = "ppt"
        case kFileExt_pptx = "pptx"
        case kFileExt_program = "program"
        case kFileExt_psd = "psd"
        case kFileExt_quarkxpress = "quarkxpress"
        case kFileExt_task_finished = "task_finished"
        case kFileExt_task_open = "task_open"
        case kFileExt_txt = "txt"
        case kFileExt_vcf = "vcf"
        case kFileExt_videof = "videof"
        case kFileExt_visio = "visio"
        case kFileExt_vsd = "vsd"
        case kFileExt_wiki = "wiki"
        case kFileExt_xls = "xls"
        case kFileExt_xlsx = "xlsx"
        case kFileExt_xml = "xml"
        case kFileExt_zip = "zip"

    }

    public subscript(key: DPAGImageProvider.Name) -> UIImage? { self.imageProviderInstance[key] }
    public subscript(key: String) -> UIImage? { self.imageProviderInstance[key] }

    fileprivate lazy var mimeType2ImageName = [
        "application/gzip": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-gzip": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-ace-compressed": DPAGImageProvider.Name.kImageFileArchive,
        "application/java-archive": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-rar-compressed": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-7z-compressed": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-bzip": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-bzip2": DPAGImageProvider.Name.kImageFileArchive,
        "application/zip": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-compressed": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-zip-compressed": DPAGImageProvider.Name.kImageFileArchive,
        "application/vnd.android.package-archive": DPAGImageProvider.Name.kImageFileArchive,
        "application/x-tar": DPAGImageProvider.Name.kImageFileArchive,

        "application/x-iwork-numbers-sffnumbers": DPAGImageProvider.Name.kImageFileNumbers,
        "application/x-iwork-numbers-sfftemplate": DPAGImageProvider.Name.kImageFileNumbers,
        "application/msexcel": DPAGImageProvider.Name.kImageFileNumbers,
        "application/excel": DPAGImageProvider.Name.kImageFileNumbers,
        "application/x-excel": DPAGImageProvider.Name.kImageFileNumbers,
        "application/vnd.ms-excel": DPAGImageProvider.Name.kImageFileNumbers,
        "application/x-msexcel": DPAGImageProvider.Name.kImageFileNumbers,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": DPAGImageProvider.Name.kImageFileNumbers,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.template": DPAGImageProvider.Name.kImageFileNumbers,

        "application/x-iwork-pages-sffpages": DPAGImageProvider.Name.kImageFilePages,
        "application/x-iwork-pages-sfftemplate": DPAGImageProvider.Name.kImageFilePages,
        "application/msword": DPAGImageProvider.Name.kImageFilePages,
        "application/word": DPAGImageProvider.Name.kImageFilePages,
        "application/x-msword": DPAGImageProvider.Name.kImageFilePages,
        "application/vnd.ms-word": DPAGImageProvider.Name.kImageFilePages,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": DPAGImageProvider.Name.kImageFilePages,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.template": DPAGImageProvider.Name.kImageFilePages,

        "application/x-iwork-keynote-sffkey": DPAGImageProvider.Name.kImageFileKeynote,
        "application/x-iwork-keynote-sfftemplate": DPAGImageProvider.Name.kImageFileKeynote,
        "application/mspowerpoint": DPAGImageProvider.Name.kImageFileKeynote,
        "application/vnd.ms-powerpoint": DPAGImageProvider.Name.kImageFileKeynote,
        "application/powerpoint": DPAGImageProvider.Name.kImageFileKeynote,
        "application/x-mspowerpoint": DPAGImageProvider.Name.kImageFileKeynote,
        "application/vnd.openxmlformats-officedocument.presentationml.presentation": DPAGImageProvider.Name.kImageFileKeynote,
        "application/vnd.openxmlformats-officedocument.presentationml.slide": DPAGImageProvider.Name.kImageFileKeynote,
        "application/vnd.openxmlformats-officedocument.presentationml.slideshow": DPAGImageProvider.Name.kImageFileKeynote,
        "application/vnd.openxmlformats-officedocument.presentationml.template": DPAGImageProvider.Name.kImageFileKeynote,

        "application/pdf": DPAGImageProvider.Name.kImageFilePdf
    ]

    public func imageForMimeType(_ mimeType: String) -> UIImage? {
        if let key = mimeType2ImageName[mimeType.lowercased()] {
            return self[key]
        }

        return self[DPAGImageProvider.Name.kImageFileAny]
    }

    fileprivate lazy var fileExtension2ImageName = [
        "gzip": DPAGImageProvider.Name.kImageFileArchive,
        "ace": DPAGImageProvider.Name.kImageFileArchive,
        "jar": DPAGImageProvider.Name.kImageFileArchive,
        "rar": DPAGImageProvider.Name.kImageFileArchive,
        "7z": DPAGImageProvider.Name.kImageFileArchive,
        "bzip": DPAGImageProvider.Name.kImageFileArchive,
        "bzip2": DPAGImageProvider.Name.kImageFileArchive,
        "tar": DPAGImageProvider.Name.kImageFileArchive,
        "ai": DPAGImageProvider.Name.kFileExt_ai,

        "audio": DPAGImageProvider.Name.kFileExt_audio,
        "aac": DPAGImageProvider.Name.kFileExt_audio,
        "3gp": DPAGImageProvider.Name.kFileExt_audio,
        "aiff": DPAGImageProvider.Name.kFileExt_audio,
        "ogg": DPAGImageProvider.Name.kFileExt_audio,
        "au": DPAGImageProvider.Name.kFileExt_audio,
        "wav": DPAGImageProvider.Name.kFileExt_audio,
        "raw": DPAGImageProvider.Name.kFileExt_audio,
        "wma": DPAGImageProvider.Name.kFileExt_audio,
        "webm": DPAGImageProvider.Name.kFileExt_audio,
        "m4a": DPAGImageProvider.Name.kFileExt_audio,
        "mp3": DPAGImageProvider.Name.kFileExt_audio,

        "csv": DPAGImageProvider.Name.kFileExt_csv,
        "doc": DPAGImageProvider.Name.kFileExt_doc,
        "docx": DPAGImageProvider.Name.kFileExt_docx,
        "dwg": DPAGImageProvider.Name.kFileExt_dwg,
        "dxf": DPAGImageProvider.Name.kFileExt_dxf,
        "emf": DPAGImageProvider.Name.kFileExt_emf,
        "exe": DPAGImageProvider.Name.kFileExt_exe,
        "flash": DPAGImageProvider.Name.kFileExt_flash,
        "h": DPAGImageProvider.Name.kFileExt_h,
        "html": DPAGImageProvider.Name.kFileExt_html,
        
        "image": DPAGImageProvider.Name.kFileExt_image,
        "jpeg": DPAGImageProvider.Name.kFileExt_image,
        "jpg": DPAGImageProvider.Name.kFileExt_image,
        "jfif": DPAGImageProvider.Name.kFileExt_image,
        "tiff": DPAGImageProvider.Name.kFileExt_image,
        "gif": DPAGImageProvider.Name.kFileExt_image,
        "bmp": DPAGImageProvider.Name.kFileExt_image,
        "png": DPAGImageProvider.Name.kFileExt_image,
        "webp": DPAGImageProvider.Name.kFileExt_image,
        "svg": DPAGImageProvider.Name.kFileExt_image,
        "ppm": DPAGImageProvider.Name.kFileExt_image,
        "pgm": DPAGImageProvider.Name.kFileExt_image,
        "pbm": DPAGImageProvider.Name.kFileExt_image,
        "pnm": DPAGImageProvider.Name.kFileExt_image,

        "ind": DPAGImageProvider.Name.kFileExt_ind,
        "indd": DPAGImageProvider.Name.kFileExt_indd,
        "iso": DPAGImageProvider.Name.kFileExt_iso,
        "js": DPAGImageProvider.Name.kFileExt_js,
        "key": DPAGImageProvider.Name.kFileExt_key,
        "mind": DPAGImageProvider.Name.kFileExt_mind,
        "mindmap": DPAGImageProvider.Name.kFileExt_mindmap,
        "numbers": DPAGImageProvider.Name.kFileExt_numbers,
        "odb": DPAGImageProvider.Name.kFileExt_odb,
        "odf": DPAGImageProvider.Name.kFileExt_odf,
        "odg": DPAGImageProvider.Name.kFileExt_odg,
        "odp": DPAGImageProvider.Name.kFileExt_odp,
        "ods": DPAGImageProvider.Name.kFileExt_ods,
        "odt": DPAGImageProvider.Name.kFileExt_odt,
        "pages": DPAGImageProvider.Name.kFileExt_pages,
        "pdf": DPAGImageProvider.Name.kFileExt_pdf,
        "pgp": DPAGImageProvider.Name.kFileExt_pgp,
        "ppt": DPAGImageProvider.Name.kFileExt_ppt,
        "pptx": DPAGImageProvider.Name.kFileExt_pptx,
        "psd": DPAGImageProvider.Name.kFileExt_psd,
        "quarkxpress": DPAGImageProvider.Name.kFileExt_quarkxpress,
        "txt": DPAGImageProvider.Name.kFileExt_txt,
        "vcf": DPAGImageProvider.Name.kFileExt_vcf,
        "visio": DPAGImageProvider.Name.kFileExt_visio,
        
        "video": DPAGImageProvider.Name.kFileExt_videof,
        "mkv": DPAGImageProvider.Name.kFileExt_videof,
        "flv": DPAGImageProvider.Name.kFileExt_videof,
        "vob": DPAGImageProvider.Name.kFileExt_videof,
        "ogv": DPAGImageProvider.Name.kFileExt_videof,
        "avi": DPAGImageProvider.Name.kFileExt_videof,
        "mts": DPAGImageProvider.Name.kFileExt_videof,
        "m2ts": DPAGImageProvider.Name.kFileExt_videof,
        "mov": DPAGImageProvider.Name.kFileExt_videof,
        "mp2": DPAGImageProvider.Name.kFileExt_videof,
        "mpeg": DPAGImageProvider.Name.kFileExt_videof,
        "mpg": DPAGImageProvider.Name.kFileExt_videof,
        "mp4": DPAGImageProvider.Name.kFileExt_videof,
        "m4v": DPAGImageProvider.Name.kFileExt_videof,

        "vsd": DPAGImageProvider.Name.kFileExt_vsd,
        "wiki": DPAGImageProvider.Name.kFileExt_wiki,
        "xls": DPAGImageProvider.Name.kFileExt_xls,
        "xlsx": DPAGImageProvider.Name.kFileExt_xlsx,
        "xml": DPAGImageProvider.Name.kFileExt_xml,
        "zip": DPAGImageProvider.Name.kFileExt_zip
    ]

    public func imageForFileExtension(_ fileExtension: String) -> UIImage? {
        if let key = fileExtension2ImageName[fileExtension.lowercased()] {
            return self[key]
        }

        return self[DPAGImageProvider.Name.kImageFileAny]
    }
}

private class DPAGImageNameProvider {
    subscript(key: DPAGImageProvider.Name) -> UIImage? {
        switch key {
        case .kImageChatSystemLogo, .kImageLogoDPAG, .kImageLaunchBackground, .kImageLaunchLogo, .kImageChatListSystemChatBackground, .kImagePlaceholderGroup, .kImagePlaceholderSingle:
            return UIImage(named: key.rawValue)
        default:
            return UIImage(named: key.rawValue, in: Bundle(for: DPAGImageNameProvider.self), compatibleWith: nil)
        }
    }

    subscript(key: String) -> UIImage? {
        UIImage(named: key, in: Bundle(for: DPAGImageNameProvider.self), compatibleWith: nil)
    }
}

private class DPAGImageNameProviderB2B: DPAGImageNameProvider {
    private static let kImageLogoDPAG = "Logo_DPAG_B2B"
    private static let kImageLaunchLogo = "Launch_Logo_Ginlo_B2B"

    override subscript(key: DPAGImageProvider.Name) -> UIImage? {
        switch key {
        case .kImageLogoDPAG:
            return UIImage(named: DPAGImageNameProviderB2B.kImageLogoDPAG)

        case .kImageLaunchLogo:
            return UIImage(named: DPAGImageNameProviderB2B.kImageLaunchLogo)

        default:
            return super[key]
        }
    }
}
