use_frameworks!

install! 'cocoapods',
    :deterministic_uuids => false

platform :ios, '12.0'

workspace 'Ginlo'

def allTargets
    ['ginlo', 'ginlo-staging', 'ginloba', 'ginlo-ba-staging' ]
end

JFBCryptVersion = '0.1'
AFNetworkingVersion = '4.0.1'
MagicalRecordVersion = '2.4.0'
NSHashVersion = '1.2.0'
ObjectiveZipVersion = '1.0.5'
ZXingObjCVersion = '3.6.7'
HPGrowingTextViewVersion = '1.1'
SentryVersion = '5.2.2'
SQLCipherVersion = '4.4.0'
CocoaLumberjackVersion = '3.6.2'
JitsiMeetSDKVersion = '6.0.0'
GiphyVersion = '2.1.20'

def podsApp
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'AFNetworking', :path => './PatchedPods/AFNetworking', :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'MagicalRecord', :path => './PatchedPods/MagicalRecord'
    pod 'NSHash', NSHashVersion
    pod 'objective-zip', ObjectiveZipVersion
    pod 'ZXingObjC', :git => 'https://github.com/zxingify/zxingify-objc.git', :tag => ZXingObjCVersion
    pod 'HPGrowingTextView', HPGrowingTextViewVersion, :inhibit_warnings => true
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => SentryVersion
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
    pod 'JitsiMeetSDK', JitsiMeetSDKVersion
    pod 'Giphy', GiphyVersion
    pod 'ImageSlideShowSwift'
end

def podsShareExtension
    pod 'AFNetworking', :path => './PatchedPods/AFNetworking', :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'HPGrowingTextView', HPGrowingTextViewVersion, :inhibit_warnings => true
    pod 'NSHash', NSHashVersion
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
end

def podsNotificationExtension
    pod 'AFNetworking', :path => './PatchedPods/AFNetworking', :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
end

def podsCore
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'AFNetworking', :path => './PatchedPods/AFNetworking', :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'MagicalRecord', :path => './PatchedPods/MagicalRecord'
    pod 'NSHash', NSHashVersion
    pod 'objective-zip', ObjectiveZipVersion
    pod 'ZXingObjC', :git => 'https://github.com/zxingify/zxingify-objc.git', :tag => ZXingObjCVersion
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
    pod 'JitsiMeetSDK', JitsiMeetSDKVersion
    pod 'Giphy', GiphyVersion
    pod 'ImageSlideShowSwift'
end

target 'SIMSmeCore' do
    project 'SIMSmeCoreLib/SIMSmeCoreLib.xcodeproj'
    podsCore
end
target 'shareExtension' do
    project 'Ginlo.xcodeproj'
    podsShareExtension
end

target 'shareExtensionBA' do
    project 'GinloBusiness.xcodeproj'
    podsShareExtension
end

target 'notificationExtension' do
    project 'Ginlo.xcodeproj'
    podsNotificationExtension
end

target 'notificationExtensionBA' do
    project 'GinloBusiness.xcodeproj'
    podsNotificationExtension
end

target 'notificationExtensionStaging' do
    project 'GinloStaging.xcodeproj'
    podsNotificationExtension
end

target 'SIMSmeUILib' do
    project 'SIMSmeUILib/SIMSmeUILib.xcodeproj'
    podsApp
end

target 'ginlo' do
    podsApp
    project 'Ginlo.xcodeproj'
end

target 'ginlo-staging' do
    podsApp
    project 'GinloStaging.xcodeproj'
end

target 'ginloba' do
    podsApp
    project 'GinloBusiness.xcodeproj'
end

target 'ginlo-ba-staging' do
    podsApp
    project 'GinloBusinessStaging.xcodeproj'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
          if (target.name == "MagicalRecord")
            config.build_settings['OTHER_CFLAGS'] ||= ['$(inherited)', '-DMR_LOGGING_DISABLED=1']
          end
        end
    end
    Dir.chdir './src/'
    FileUtils.ln_s '../Pods', '.', force: true
    Dir.chdir '..'
end

