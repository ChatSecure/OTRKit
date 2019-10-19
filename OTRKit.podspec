Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "3.0.0"
  s.summary         = "OTRKit is a lightweight Objective-C wrapper for libotr to provide OTR (Off the Record) message encryption."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license = { :type => 'LGPL', :file => 'LICENSE' }
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :tag => s.version.to_s }
  s.prepare_command = <<-CMD
    PLATFORM_TARGET="macOS" ./scripts/build-all.sh
    PLATFORM_TARGET="iOS" ./scripts/build-all.sh
    ./scripts/build-xcframework.sh
  CMD

  s.ios.deployment_target = "8.0"
  s.ios.source_files = "OTRKit/**/*.{h,m}"
  s.ios.vendored_frameworks  = "OTRKitDependencies/libotrkit.xcframework"
  s.osx.frameworks = 'Security', 'MobileCoreServices', 'libotrkit'

  s.osx.deployment_target = "10.10"
  s.osx.source_files = "OTRKit/**/*.{h,m}"
  s.osx.vendored_frameworks  = "OTRKitDependencies/libotrkit.xcframework"
  s.osx.frameworks = 'Security', 'CoreServices', 'libotrkit'

  s.public_header_files = "OTRKit/**/*.h"
  s.preserve_paths  = "COPYING.LGPLv2.1", "COPYING.MPLv2"
  s.requires_arc = true

end