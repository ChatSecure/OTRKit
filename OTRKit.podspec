Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "2.0.0"
  s.summary         = "OTRKit is a lightweight Objective-C wrapper for libotr to provide OTR (Off the Record) message encryption."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license = { :type => 'LGPL', :file => 'LICENSE' }
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :tag => s.version.to_s }
  s.prepare_command = <<-CMD
    bash ./scripts/build-all.sh
    export PLATFORM_TARGET="macOS"
    bash ./scripts/build-all.sh
  CMD

  s.ios.deployment_target = "8.0"
  s.ios.source_files = "OTRKit/**/*.{h,m}", "OTRKitDependencies-iOS/include/**/*.h"
  s.ios.vendored_libraries  = "OTRKitDependencies-iOS/lib/*.a"
  s.ios.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/OTRKit/OTRKitDependencies-iOS/include' }
  s.osx.frameworks = 'Security', 'MobileCoreServices'

  s.osx.deployment_target = "10.10"
  s.osx.source_files = "OTRKit/**/*.{h,m}", "OTRKitDependencies-macOS/include/**/*.h"
  s.osx.vendored_libraries  = "OTRKitDependencies-macOS/lib/*.a"
  s.osx.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/OTRKit/OTRKitDependencies-macOS/include' }
  s.osx.frameworks = 'Security', 'CoreServices'

  s.public_header_files = "OTRKit/**/*.h"
  s.preserve_paths  = "COPYING.LGPLv2.1", "COPYING.MPLv2"
  s.libraries     = 'gpg-error', 'gcrypt', 'otr'
  s.requires_arc = true

end