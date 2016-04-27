Pod::Spec.new do |s|

  s.name         = "AZSClient"
  s.version      = "0.2.0"
  s.summary      = "Azure Storage Client Library for iOS."
  s.description  = <<-DESC "This library is designed to help you build iOS applications that use Microsoft Azure Storage."
                   DESC
  s.homepage     = "https://github.com/Azure/azure-storage-ios"
  s.license      = "MIT"
  s.author       = "Microsoft Azure Storage"
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/Azure/azure-storage-ios.git", :tag => "v0.2.0" }
  s.source_files  = "Lib/Azure Storage Client Library/Azure Storage Client Library/*.{h,m}"
  s.ios.library   = 'xml2.2'
#  s.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }
  s.xcconfig = {
    "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2",
    "SWIFT_INCLUDE_PATHS[sdk=iphoneos*]" => "$(SRCROOT)/Pods/AZSClient/asl/iphoneos",
    "SWIFT_INCLUDE_PATHS[sdk=iphonesimulator*]" => "$(SRCROOT)/Pods/AZSClient/asl/iphonesimulator",
    "SWIFT_INCLUDE_PATHS[sdk=macosx*]" => "$(SRCROOT)/Pods/AZSClient/asl/macosx"
  }
  s.preserve_paths = "asl/**"
  s.prepare_command = "asl/injectXcodePath.sh"
end
