xcodebuild clean > /dev/null; rm -rf build;
xcodebuild -scheme OTRKit -configuration Release -sdk iphonesimulator CONFIGURATION_BUILD_DIR='build/i386' > /dev/null
xcodebuild -scheme OTRKit -configuration Release -sdk iphoneos CONFIGURATION_BUILD_DIR='build/arm' > /dev/null
mkdir build/lib; lipo -create build/i386/libOTRKit.a build/arm/libOTRKit.a -output build/lib/libOTRKit.a

echo "Done. Look in build/lib/ for the finished library."
