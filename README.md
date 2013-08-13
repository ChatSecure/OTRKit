# OTRKit


[OTRKit](https://github.com/ChatSecure/OTRKit) is an Objective-C wrapper for the OTRv3 encrypted messaging protocol, using [libotr](http://www.cypherpunks.ca/otr/). This library was designed for use with the encrypted iOS messaging app [ChatSecure](https://github.com/chrisballinger/Off-the-Record-iOS), but should theoretically work for Mac OS X as well with some minor tweaking to the build scripts.

## Installation

Install this project as a submodule in your repository (make sure to [fork](https://github.com/ChatSecure/OTRKit/fork) it first if you plan to make changes):

    git submodule add https://github.com/ChatSecure/OTRKit.git Submodules/OTRKit


To compile libotr and dependencies for iOS, run the included scripts in this order (or use `build-all.sh`):

1. `build-libgpg-error.sh`
2. `build-libgcrypt.sh`
3. `build-libotr.sh`

Then do these things:

1. Drag `OTRKit.xcodeproj` to the left-hand file pane in Xcode to add it to your project. 
2. Make sure to add `OTRKit (OTRKit)` to your project's Targent Dependencies in the Build Phases tab of your target settings.
3. Add `libOTRKit.a` to the Link Binary With Libraries step within the same window.

## Usage

Check out [OTRKit.h](https://github.com/ChatSecure/OTRKit/blob/master/OTRKit/OTRKit.h) because it is the most up-to-date reference at the moment.

Implement the required delegate methods somewhere that makes sense for your project.

```obj-c
@protocol OTRKitDelegate <NSObject>
@required
// Implement this delegate method to forward the injected message to the appropriate protocol
- (void) injectMessage:(NSString*)message recipient:(NSString*)recipient accountName:(NSString*)accountName protocol:(NSString*)protocol;
- (void) updateMessageStateForUsername:(NSString*)username accountName:(NSString*)accountName protocol:(NSString*)protocol messageState:(OTRKitMessageState)messageState; 
```

To encode a message:

```obj-c
NSString *message = @"Something in plain text.";
NSString *recipientAccount = @"bob@example.com";
NSString *sendingAccount = @"alice@example.com";
NSString *protocol = @"xmpp"; // OTR can work over any protocol
[[OTRKit sharedInstance] encodeMessage:message recipient:recipientAccount accountName:sendingAccount protocol:protocol success:^(NSString *encryptedMessage) {
		// you might want to pass this along to diffie
        NSLog(@"Encrypted ciphertext: %@", encryptedMessage);
    }];
```

To decode a message:

```obj-c
[[OTRKit sharedInstance] decodeMessage:message recipient:friendAccount accountName:myAccountName protocol:protocol]
```

## TODO

* Refactor to clean up the code a bit
* Documentation!
* Add Mac OS X support
* Change project to use git submodules for the dependencies.
* Figure out how to make `libgcrypt`, `libgpg-error`, and `libotr` build within Xcode to assist in debugging.
* Preserve the debugging symbols to allow for better crash reports when used in conjuction with dSYM files.


## Contributing

Please fork the project and submit a pull request and (preferrably) squash your commits. Thank you! If you're interested in privacy and security, check out [chatsecure.org](https://chatsecure.org) and [The Guardian Project](https://guardianproject.info).


## License

The code for this project is provided under the Modified BSD license. The required dependencies are under terms of a seperate license (LGPL). More information is available in the [LICENSE](https://github.com/ChatSecure/OTRKit/blob/master/LICENSE) file.