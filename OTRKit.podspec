Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "1.0.0"
  s.summary         = "OTRKit is an Objective-C wrapper around libotr."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license         = 'LGPLv2.1+ & MPL 2.0'
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :tag => s.version.to_s }
  s.prepare_command = <<-CMD
    bash ./scripts/build-all.sh
  CMD

  s.platform     = :ios, "7.0"
  s.source_files = "OTRKit/*.{h,m}", "OTRKitDependencies/include/**/*.h"
  s.header_mappings_dir = "OTRKitDependencies/include"
  s.preserve_paths  = "OTRKitDependencies/libs/*", "OTRKitDependencies/include/**/*.h"
  s.vendored_libraries  = "OTRKitDependencies/lib/*.a"
  s.library     = 'gpg-error', 'gcrypt', 'otr'
  s.requires_arc = true
end