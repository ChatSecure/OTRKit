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

1. Drag the contents of `./OTRKit/` directory into your Xcode project and add it to your current target.
2. Drag the contents of `./dependencies/` directory into your Xcode project and add it to your current target.
2. Make sure to add `$(SRCROOT)/Submodules/OTRKit/dependencies/include` to your project's Header Search Paths in the Build Settings tab of your target settings.

*Note*: libotr build script may fail if `libgcrypt` has been installed via Homebrew because of a path conflict.

### Cocoapods

There is a work-in-progress Cocoapod that you can check out,`OTRKit.podspec`, but it hasn't been fully tested yet.

## Usage

Check out [OTRKit.h](https://github.com/ChatSecure/OTRKit/blob/master/OTRKit/OTRKit.h) because it is the most up-to-date reference at the moment.

Implement the required delegate methods somewhere that makes sense for your project.

```obj-c
@protocol OTRKitDelegate <NSObject>
@required
/**
 *  This method **MUST** be implemented or OTR will not work. All outgoing messages
 *  should be sent first through OTRKit encodeMessage and then passed from this delegate
 *  to the appropriate chat protocol manager to send the actual message.
 *
 *  @param otrKit      reference to shared instance
 *  @param message     message to be sent over the network. may contain ciphertext.
 *  @param recipient   intended recipient of the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attached to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag;

/**
 *  All outgoing messages should be sent to the OTRKit encodeMessage method before being
 *  sent over the network.
 *
 *  @param otrKit      reference to shared instance
 *  @param message     plaintext message
 *  @param sender      buddy who sent the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 encodedMessage:(NSString*)encodedMessage
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag
          error:(NSError*)error;


/**
 *  All incoming messages should be sent to the OTRKit decodeMessage method before being
 *  processed by your application. You should only display the messages coming from this delegate method.
 *
 *  @param otrKit      reference to shared instance
 *  @param message     plaintext message
 *  @param tlvs        OTRTLV values that may be present.
 *  @param sender      buddy who sent the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(NSString*)decodedMessage
           tlvs:(NSArray*)tlvs
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag;

/**
 *  When the encryption status changes this method is called
 *
 *  @param otrKit      reference to shared instance
 *  @param messageState plaintext, encrypted or finished
 *  @param username     buddy whose state has changed
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 */
- (void)    otrKit:(OTRKit*)otrKit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol;
...
```

To encode a message:

```obj-c
/**
 * Encodes a message and optional array of OTRTLVs, splits it into fragments,
 * then injects the encoded data via the injectMessage: delegate method.
 * @param message The message to be encoded
 * @param tlvs Array of OTRTLVs, the data length of each TLV must be smaller than UINT16_MAX or it will be ignored.
 * @param recipient The intended recipient of the message
 * @param accountName Your account name
 * @param protocol the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void)encodeMessage:(NSString*)message
                 tlvs:(NSArray*)tlvs
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(id)tag;
```

To decode a message:

```obj-c
/**
 *  All messages should be sent through here before being processed by your program.
 *
 *  @param message     Encoded or plaintext incoming message
 *  @param sender      account name of buddy who sent the message
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void)decodeMessage:(NSString*)message
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(id)tag;
```

## TODO

* Documentation!
* Add Mac OS X support
* Finish Cocoapods support.
* Tests

## Contributing

Please fork the project and submit a pull request and (preferrably) squash your commits. Thank you! If you're interested in privacy and security, check out [chatsecure.org](https://chatsecure.org) and [The Guardian Project](https://guardianproject.info).


## License

The code for this project is dual licensed under the [LGPLv2.1+](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt) and [MPL 2.0](http://www.mozilla.org/MPL/2.0/). The required dependencies are under terms of a seperate license (LGPL). More information is available in the [LICENSE](https://github.com/ChatSecure/OTRKit/blob/master/LICENSE) file.