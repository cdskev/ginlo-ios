# Build Your Own Ginlo Client

First, and foremost: thank you for your interest in the Ginlo Client. We hope you enjoy looking into the
code and building a client for yourself.

The code was originally written in Objective-C and then "ported" to Swift. Thus, you will see a lot of
Objective-C'ish style within Swift.

Since this code has a lot of [history](HISTORY.md), we don't really know who converted it to Swift (it seems, it was
someone called RBU).

The original idea behind the code was to develop a simple messenger; then the developers added the ability
to have different clients (called "Mandant" in the code, from German, meaning Client). Thus you will find
a lot of "isBaMandant" (BA = Business Application = Ginlo Business). 

The code is nearly 100% shared between Ginlo Private and Ginlo Business. There are some minor differences that
are implemented using something like:

    if isBaMandant {
    }

Additionally, the code supports Mobile Device Management (MDM), but only for the business version (obviously). 
Thus you will find, quite a few times, `*MDM*`.

Since ginlo.net GmbH only releases the Ginlo Private *configuration* into the public you can only build a 
private version. Thus you can just ignore the MDM-stuff. 

But note: some features are available only for the business version. These include **Managed Groups** and
**Restricted Groups**. The clients can not create these groups. These groups can only be created by
the business administration cockpit, which only business customers have access to.

If you want to build and run your own client and you are not member of either the ginlo.net GmbH development team 
*or* the CDSK e.V. development team, you need to adjust some items to be able to compile and run this.

**WARNING**: The Ginlo Source Code can NOT be compiled and run on a simulator. You **MUST** use a physical device
to compile and test the client. WE DO NOT SUPPORT SIMULATORS!!

## Installation / Configuration

1. Install Pre-Requisities
2. Clone the Repo (`develop` is our main branch)
3. Install Pods
4. Open the `.xcworkspace`-file
5. Set Your BundleIDs
6. Set Your Package Names
7. Complete the `info.plist`-Files
8. Complete the `.entitlement`-files
9. Get a license for `libchilkat.a`
10. Build

## 1. Install Pre-Requisities

You need to install the following tools to be able to build this repository:

- [**Xcode** (>=12.4) - Apple Developer Tools](https://developer.apple.com/download/)
- [**Homebrew**](https://brew.sh/)
- [**git-lfs** - Git Large File Storage](https://git-lfs.github.com)

After installing Xcode and Homebrew, open a [Terminal](https://iterm2.com/)-Window and execute the commands shown below:

- **git**: `brew install git`
- **git-lfs**: `git lfs install`
- **CocoaPods**: `brew install cocoapods`

Now you can go the step 2: Clone the Repo.

## 2. Clone the Repo

You can use [SourceTree](https://www.atlassian.com/software/sourcetree) or use command line (or both) for
your `git` needs.

In any case, go to the repository's page on GitHub, get the URL (cloning) and clone it onto your harddisk.

**WARNING**: NEVER USE THE `.xcodeproj`-files directly, it will not work. You need to acces them from the
`.xcworkspace`-file (Xcode Workspace).

**INFO**: DO NOT OPEN THE `.xcworkspace`-file yet.

## 3. CocoaPods

You have installed CocoaPods using Homebrew, right? Otherwise go back and install it please; you need the `pod`-command now.

Go into the project-directory (where the `.xcworkspace`-file resides) and perform:

    pod install

This will create all of your required CocoaPod-Configurations install the pods.

**Now** you can open the `.xcworkspace`-file in Xcode. 

## 4. Open the `.xcworkspace`-file

Now open the `.xcworkspace`-file in Xcode. You will notice four projects in the workspace:

1. Ginlo
3. *CoreLib*
4. *UILib*
5. Pods

You should also find one scheme to build: **Ginlo**.

You are now ready to configure your version.

## 5. Set Your BundleIDs

In the directory `Config`, you will find various configuration files (`.xcconfig`). You need to configure
these files correctly with the right Team ID, bundle-ID, iCloud-ID, GroupID, etc.

You need to have a working Apple Developer ID to do so. Go to your developer account and create the right
bundle-IDs there.

Example:

    BundleID = eu.cdsk.ginlo
    iCloud   = icloud.eu.cdsk.ginlo
    Group    = group.eu.cdsk.ginlo

Then find your team ID which is usually an alphanumeric string such as:

    8UNQ4626FQ

Using your developer team ID create a string such as **8UNQ4626FQ.keychain.eu.cdsk.ginlo** which 
will need to be added into a configuration file.

Use this to create your entries in the config-files.

### Application BundleID

You need to create an application bundle ID using Apple's Developer Portal ( *not* AppStoreConnect). Use *Certificates, Identifiers & Profiles* to
create your new application bundle id.

Give your app a unique bundle id such as `eu.cdsk.ginlo`. We will assume, going forward, that this is your application bundle id.

The capabilities you will require are:

- **App Groups**: It is suggested to use `group.` as prefix to your application bundle id. In our example case, it would be `group.eu.cdsk.ginlo`.

  Please note: the Applicaiton-Group needs to end in the application bundle id.

- **Data Protection**: Complete Protection
- **iCloud**: CloudKit-support. Please use your application bundle id with the `icloud.` prefix.
- **Push Notifications**: If you have an agreement with ginlo.net GmbH that they will support your push certificate, you need to create a push certificate, download it 
and provide it to ginlo.net GmbH so that they can add this certificate to the server. *In any case, you need the Push Notification-capability, even if you don't (for now) create a certificate*.

### Sharing Extension BundleID

You must provide a bundle-Id for the sharing extension. You can use `sharing.` as suffxi, e.g.: `eu.cdsk.ginlo.sharing`.

You need the Capabilities:

- App Groups: use the app groups from above
- Data Protection: Complete Protection
- iCloud: use the icloud id from above

### Notification Extension BundleID

You must provide a bundle-iD for your notification extension. You can use `notification.` as suffxi, e.g.: `eu.cdsk.ginlo.notification`.

You need the Capabilities:

- App Groups: use the app groups from above
- Data Protection: Complete Protection
- iCloud: use the icloud id from above

Add these ids, where necessary, to the `.xcconfig`-files (not all IDs need to be added in `.xcconfig`-files).

**WARNING: DO NOT TOUCH ANY BUNDLE-ID IN ANY OF THE LIBRARIES SUCH AS CoreLib or UILib**.

### Finalize Configuration

In order to finish your bundle-ID configuration you need to enter the so created bundle-IDs into the configuration-file in `./Applicaiton/Config/01_application.xcconfig`:

- KEYCHAIN_ACCESS_GROUP_NAME: keychain access group for Ginlo; this is &lt;`team-id`&gt;`.keychain.`&lt;`app-bundle-id`&gt;
- APPLICATION_GROUP_ID: the one you created in Apple's Developer Portal
- APPLICATION_ICLOUD_ID_TEST: the iCloud ID you created in Apple's Developer Portal with `.beta` at end (don't worry)
- APPLICATION_ICLOUD_ID_RELEASE: the iCloud ID as you created it in Apple's Developer Portal

Additionally you need to configure these two variables, of which one is mandatory and the other one is optional:

- URL_HTTP_SERVICE: You need to obtain this entry from ginlo.net GmbH in order to run your client against their backend. Please enter the **complete** value for this variable here **as received from ginlo.net GmbH** - **MANDATORY**
- VOIP_AVC_SERVER: If you want your client to be able to **initiate** AV-calls, you will need to run your own JitsiMeet Server. Please enter the url of your JitsiMeet-Server **without any http**, e.g. `VOIP_AVC_SERVER = myserver.mydomain.com` - **OPTIONAL**, see below.

Save and you are done with the configurations.

### Audio-/Video-Calls & -Conferences

You need to run your own JitsiMeet-Server. Please check out on the [JitsiMeet Repository](https://github.com/jitsi/jitsi-meet) here 
on GitHub for details on running such a server.

If you leave the AVC-Server-field empty or invalid, you will not be able to **initiate** audio-/video-calls. You will still
be able to participate in any such call if invited.

It is important to know that any Ginlo-Client running on the ginlo.net GmbH's backend is able to participate in 
any audio-/video-call initiated by any other Ginlo client. 

The `VOIP_AVC_SERVER` is for **initiating** such a call. Whenever a user is invited to such a call their client
receives the AVC-Server-URL of the initiating client and will connect to that server - regardless of its own server
setting.

Thus you *can* create an client without its own AVC-Server in which case it just can not **initiate** calls.

## 6. Set Your Package Names (Optional)

Please do choose the application target (not notificate or share-target), in 

    Build Settings -> Packaging

You will find `ginlo.app`.

Change these to something that fits your app - THIS IS ABSOLUTELY OPTIONAL! 

WARNING: YOU CAN NOT CHANGE THIS LATER ON AFTER YOU RELEASE A VERSION TO USERS AS THAT WOULD BE A NEW APP ON THE USER's DEVICE WHEN THEY INSTALL IT.

## 7. Complete the `info.plist`-Files

Check whether anything in your `*-info.plist`-file needs to be changed. These usually change automatically when you edit it in Xcode, but you can double-check it.

## 8. Complete the `.entitlement`-files

Check that your `*.entitlement`-files contain the right entitlements. Again, these should be changed automatically by Xcode depending on your bundle-ID & Co. But you never know.

## 9. Get a license for `libchilkat.a`

Get a license for `libchilkat.a`. You can get this from [Chilkat Software](https://www.chilkatsoft.com). 

Please note that the license we provide (any type of string) allows running for 30 Minutes only. 

You usually get a Chilkat-license per developer, not per application. Please checkout their website for up-to-date license rules and agreements.

Add this license to `00_application.xcconfig` at the appropriate place. It will be automatically added to the appropriate `*-info.plist`.

## 10. Build

Use the appropriate Scheme in Xcode to build for your connected device.

**IMPORTANT: If you want to publish it to the AppStore, you need to adjust Release and Build-Numbers accordingly. We have NOT automated it. You need to adjust three variables in `./Configuration/Config/00_VERSION.xcconfig`. Xcode will take it from there**:

- VERSION: Something like "1.0.0"
- BUILD: An `integer` that you count **up**, you can start at anywhere but it can only go up!

**REMINDER: WE DO NOT SUPPORT SIMULATORS, YOU NEED A HARDWARE-DEVICE TO RUN/TEST. But then again, any iOS-Device >= iPhone 6s will do (including iPad, iPod Touch)***

## Directory Structures

The project is structured this:

    ./Application/
    ./CODE_OF_CONDUCT.md 
    ./Configuration/
    ./CONTRIBUTING.md 
    ./COPYRIGHT.txt 
    ./Ginlo.xcodeproj 
    ./Ginlo.xcworkspace 
    ./HISTORY.md 
    ./HOWTO.md 
    ./LICENSE.txt
    ./PatchedPods/
    ./Podfile 
    ./Podfile.lock 
    ./README.md 
    ./SIMSmeCoreLib/
    ./SIMSmeUILib/

The directories `SIMSmeCoreLib` and `SIMSmeUILib` are called `CoreLib` and `UILib`, respectively, across any of our documentations.

In order to build your first instance of the apps, you will mostly need to work within the `./Configuration`-directory. All configuration-, plist- and entitlement-files are in there. Also the images used are in there and some other internal stuff.


## MagicalRecord & JFBCrypt (./PatchedPods/)

Please do not try to replace the provided `MagicalRecord` and `JFBCrypt`-pods. These are in the `./PatchedPods`-directory.

`MagicalRecord` has been patched to have various additional features that were originally not part of MR and still aren't.
Since it is also deprecated, we can't add them upstream.

`JFBCrypt` has just an additional method made available to Swift as well as `dealloc`/`autorelease` removed due to ARC-use.

## Good Luck and Godspeed

If you need any help you can open an issue and mention the maintainer(s).

Until then: Good Luck and Godspeed.
