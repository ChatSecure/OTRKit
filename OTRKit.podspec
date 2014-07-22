Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "1.0.0"
  s.summary         = "OTRKit is an Objective-C wrapper around libotr."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license         = 'LGPLv2.1+ & MPL 2.0'
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :branch => "master"}
  s.prepare_command = <<-CMD
    bash build-all.sh
  CMD

  s.platform     = :ios, "6.0"
  s.source_files = "OTRKit/*.{h,m}", "dependencies/include/**/*.h"
  s.preserve_paths  = "dependencies/libs/*", "dependencies/include/**/*.h"
  s.vendored_libraries  = "dependencies/lib/*.a"
  s.library     = 'gpg-error', 'gcrypt', 'otr'
  s.requires_arc = true
end