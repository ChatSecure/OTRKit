Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "1.1.2"
  s.summary         = "OTRKit is a lightweight Objective-C wrapper for libotr to provide OTR (Off the Record) message encryption."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license = { :type => 'LGPL', :file => 'LICENSE' }
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :tag => s.version.to_s }
  s.prepare_command = <<-CMD
    bash ./scripts/build-all.sh
  CMD

  s.platform     = :ios, "8.0"
  s.source_files = "OTRKit/**/*.{h,m}", "OTRKitDependencies/include/**/*.h"
  s.header_mappings_dir = "OTRKitDependencies/include"
  s.public_header_files = "OTRKit/**/*.h"
  s.preserve_paths  = "COPYING.LGPLv2.1", "COPYING.MPLv2", "OTRKitDependencies/libs/*", "OTRKitDependencies/include/**/*.h"
  s.vendored_libraries  = "OTRKitDependencies/lib/*.a"
  s.library     = 'gpg-error', 'gcrypt', 'otr'
  s.requires_arc = true
  s.frameworks = 'Security'
end