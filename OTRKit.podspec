Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "1.0.0"
  s.summary         = "OTRKit is an Objective-C wrapper around libotr."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license         = 'LGPLv2+'
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :branch => "otrdata"}
  s.preserve_paths  = "dependencies/libs/*","dependencies/include/*", "dependencies/include/**/*.h"
  s.prepare_command = <<-CMD
    bash build-all.sh
  CMD

#  s.header_dir   = "openssl"
  s.platform     = :ios, "6.0"
  s.source_files = "dependencies/include/**/*.h", "OTRKit/*.{h,m}"
  s.library     = 'gpg-error', 'gcrypt', 'otr'
  s.xcconfig     = {'LIBRARY_SEARCH_PATHS' => '"$(PODS_ROOT)/OTRKit/lib"'}
  s.requires_arc = true
  s.dependency 'CocoaHTTPServer', '~> 2.3'

end