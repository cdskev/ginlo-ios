use_frameworks!

install! 'cocoapods',
    :deterministic_uuids => false

platform :ios, '12.0'

workspace 'Ginlo'

def allTargets
    ['ginlo']
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
JitsiMeetSDKVersion = '3.2.0'

def podsApp
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'AFNetworking', AFNetworkingVersion, :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'MagicalRecord', :path => './PatchedPods/MagicalRecord'
    pod 'NSHash', NSHashVersion
    pod 'objective-zip', ObjectiveZipVersion
    pod 'ZXingObjC', :git => 'https://github.com/zxingify/zxingify-objc.git', :tag => ZXingObjCVersion
    pod 'HPGrowingTextView', HPGrowingTextViewVersion, :inhibit_warnings => true
    pod 'Sentry', :git => 'https://github.com/getsentry/sentry-cocoa.git', :tag => SentryVersion
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
    pod 'JitsiMeetSDK', JitsiMeetSDKVersion
end

def podsShareExtension
    pod 'AFNetworking', AFNetworkingVersion, :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'HPGrowingTextView', HPGrowingTextViewVersion, :inhibit_warnings => true
    pod 'NSHash', NSHashVersion
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
end

def podsNotificationExtension
    pod 'AFNetworking', AFNetworkingVersion, :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
end

def podsCore
    pod 'JFBCrypt', :path => './PatchedPods/JFBCrypt', :inhibit_warnings => true
    pod 'AFNetworking', AFNetworkingVersion, :subspecs => ['Reachability', 'Serialization', 'Security', 'NSURLSession']
    pod 'MagicalRecord', :path => './PatchedPods/MagicalRecord'
    pod 'NSHash', NSHashVersion
    pod 'objective-zip', ObjectiveZipVersion
    pod 'ZXingObjC', :git => 'https://github.com/zxingify/zxingify-objc.git', :tag => ZXingObjCVersion
    pod 'SQLCipher', SQLCipherVersion, :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift', CocoaLumberjackVersion
    pod 'JitsiMeetSDK', JitsiMeetSDKVersion
end

target 'SIMSmeCore' do
    project 'SIMSmeCoreLib/SIMSmeCoreLib.xcodeproj'
    podsCore
end
target 'shareExtension' do
    project 'Ginlo.xcodeproj'
    podsShareExtension
end

target 'notificationExtension' do
    project 'Ginlo.xcodeproj'
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

# TODO: Remove this hook when MagicalRecord is removed
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
end

