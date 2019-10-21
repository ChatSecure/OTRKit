Pod::Spec.new do |s|
  s.name            = "OTRKit"
  s.version         = "3.0.0"
  s.summary         = "OTRKit is a lightweight Objective-C wrapper for libotr to provide OTR (Off the Record) message encryption."
  s.author          = "Chris Ballinger <chris@chatsecure.org>"

  s.homepage        = "https://chatsecure.org"
  s.license = { :type => 'LGPL', :file => 'LICENSE' }
  s.source          = { :git => "https://github.com/ChatSecure/OTRKit.git", :tag => s.version.to_s }
  s.prepare_command = <<-CMD
    ./scripts/build-all.sh
  CMD

  s.ios.deployment_target = "12.0"
  s.osx.deployment_target = "10.10"

  s.module_name = 'OTRKitPod'

  s.preserve_paths  = "COPYING.LGPLv2.1", "COPYING.MPLv2"
  s.requires_arc = true
end
