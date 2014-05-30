/*
 * OTRKit.m
 * OTRKit
 *
 * Created by Chris Ballinger on 9/4/11.
 * Copyright (c) 2012 Chris Ballinger. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <Foundation/Foundation.h>
#import "OTRTLV.h"

@class OTRKit;

typedef NS_ENUM(NSUInteger, OTRKitMessageState) {
    OTRKitMessageStatePlaintext,
    OTRKitMessageStateEncrypted,
    OTRKitMessageStateFinished
};

typedef NS_ENUM(NSUInteger, OTRKitPolicy) {
    OTRKitPolicyNever,
    OTRKitPolicyOpportunistic,
    OTRKitPolicyManual,
    OTRKitPolicyAlways,
    OTRKitPolicyDefault
};

typedef NS_ENUM(NSUInteger, OTRKitSMPEvent) {
    OTRKitSMPEventNone,
    OTRKitSMPEventAskForSecret,
    OTRKitSMPEventAskForAnswer,
    OTRKitSMPEventCheated,
    OTRKitSMPEventInProgress,
    OTRKitSMPEventSuccess,
    OTRKitSMPEventFailure,
    OTRKitSMPEventAbort,
    OTRKitSMPEventError
};

typedef NS_ENUM(NSUInteger, OTRKitMessageEvent) {
    OTRKitMessageEventNone,
    OTRKitMessageEventEncryptionRequired,
    OTRKitMessageEventEncryptionError,
    OTRKitMessageEventConnectionEnded,
    OTRKitMessageEventSetupError,
    OTRKitMessageEventMessageReflected,
    OTRKitMessageEventMessageResent,
    OTRKitMessageEventReceivedMessageNotInPrivate,
    OTRKitMessageEventReceivedMessageUnreadable,
    OTRKitMessageEventReceivedMessageMalformed,
    OTRKitMessageEventLogHeartbeatReceived,
    OTRKitMessageEventLogHeartbeatSent,
    OTRKitMessageEventReceivedMessageGeneralError,
    OTRKitMessageEventReceivedMessageUnencrypted,
    OTRKitMessageEventReceivedMessageUnrecognized,
    OTRKitMessageEventReceivedMessageForOtherInstance
};

extern NSString * const kOTRKitUsernameKey;
extern NSString * const kOTRKitAccountNameKey;
extern NSString * const kOTRKitFingerprintKey;
extern NSString * const kOTRKitProtocolKey;
extern NSString * const kOTRKitTrustKey;

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

/**
 *  libotr likes to know if buddies are still "online". This method
 *  is called synchronously on the callback queue so be careful.
 *
 *  @param otrKit      reference to shared instance
 *  @param recipient   intended recipient of the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *
 *  @return online status of recipient
 */
- (BOOL)       otrKit:(OTRKit*)otrKit
   isUsernameLoggedIn:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol;

/**
 *  Show a dialog here so the user can confirm when a user's fingerprint changes.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param username    buddy whose fingerprint has changed
 *  @param theirHash   buddy's fingerprint
 *  @param ourHash     our fingerprint
 */
- (void)                           otrKit:(OTRKit*)otrKit
  showFingerprintConfirmationForTheirHash:(NSString*)theirHash
                                  ourHash:(NSString*)ourHash
                                 username:(NSString*)username
                              accountName:(NSString*)accountName
                                 protocol:(NSString*)protocol;

/**
 *  Implement this if you plan to handle SMP.
 *
 *  @param otrKit      reference to shared instance
 *  @param event    SMP event
 *  @param progress percent progress of SMP negotiation
 *  @param question question that should be displayed to user
 */
- (void) otrKit:(OTRKit*)otrKit
 handleSMPEvent:(OTRKitSMPEvent)event
       progress:(double)progress
       question:(NSString*)question
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol;

/**
 *  Implement this delegate method to handle message events.
 *
 *  @param otrKit      reference to shared instance
 *  @param event   message event
 *  @param message offending message
 *  @param error   error describing the problem
 */
- (void)    otrKit:(OTRKit*)otrKit
handleMessageEvent:(OTRKitMessageEvent)event
           message:(NSString*)message
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
               tag:(id)tag
             error:(NSError*)error;

/**
 *  When another buddy requests a shared symmetric key this will be called.
 *
 *  @param otrKit      reference to shared instance
 *  @param symmetricKey key data
 *  @param use          integer tag for identifying the use for the key
 *  @param useData      any extra data to attach
 */
- (void)        otrKit:(OTRKit*)otrKit
  receivedSymmetricKey:(NSData*)symmetricKey
                forUse:(NSUInteger)use
               useData:(NSData*)useData
              username:(NSString*)username
           accountName:(NSString*)accountName
              protocol:(NSString*)protocol;

@optional

/**
 *  Called when starting to generate a private key, may take a while.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)                             otrKit:(OTRKit *)otrKit
willStartGeneratingPrivateKeyForAccountName:(NSString*)accountName
                                   protocol:(NSString*)protocol;

/**
 *  Called when key generation has finished, canceled, or there was an error.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param error       any error that may have occurred
 */
- (void)                             otrKit:(OTRKit *)otrKit
didFinishGeneratingPrivateKeyForAccountName:(NSString*)accountName
                                   protocol:(NSString*)protocol
                                      error:(NSError*)error;
@end

@interface OTRKit : NSObject


@property (nonatomic, weak) id<OTRKitDelegate> delegate;

/**
 *  Defaults to main queue. All delegate and block callbacks will be done on this queue.
 */
@property (nonatomic) dispatch_queue_t callbackQueue;

/** 
 * By default uses `OTRKitPolicyDefault`
 */
@property (nonatomic) OTRKitPolicy otrPolicy;

/**
 *  Path to where the OTR private keys and related data is stored.
 */
@property (nonatomic, strong, readonly) NSString* dataPath;

/**
 *  Path to the OTR private keys file.
 */
@property (nonatomic, strong, readonly) NSString* privateKeyPath;

/**
 *  Path to the OTR fingerprints file.
 */
@property (nonatomic, strong, readonly) NSString* fingerprintsPath;

/**
 *  Path to the OTRv3 Instance tags file.
 */
@property (nonatomic, strong, readonly) NSString* instanceTagsPath;

/**
 *  Always use the sharedInstance. Using two OTRKits within your application
 *  may exhibit strange problems.
 *
 *  @return singleton instance
 */
+ (instancetype) sharedInstance;

/**
 * You must call this method before any others.
 * @param dataPath This is a path to a folder where private keys, fingerprints, and instance tags will be stored. If this is nil a default path will be chosen for you.
 */
- (void) setupWithDataPath:(NSString*)dataPath;

/**
 *  For specifying fragmentation for a protocol.
 *
 *  @param maxSize  max size of protocol messages in bytes
 *  @param protocol protocol like "xmpp"
 */
- (void) setMaximumProtocolSize:(int)maxSize forProtocol:(NSString*)protocol;

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

/**
 *  You can use this method to determine whether or not OTRKit is currently generating a private key.
 *
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion  whether or not we are currently generating a key
 */
- (void)checkIfGeneratingKeyForAccountName:(NSString *)accountName
                                  protocol:(NSString *)protocol
                                completion:(void (^)(BOOL isGeneratingKey))completion;

/**
 *  Shortcut for injecting a "?OTR?" message.
 *
 *  @param recipient   name of buddy you'd like to start OTR conversation
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)initiateEncryptionWithUsername:(NSString*)username
                            accountName:(NSString*)accountName
                               protocol:(NSString*)protocol;

/**
 *  Disable encryption and inform buddy you no longer wish to communicate
 *  privately.
 *
 *  @param recipient   name of buddy you'd like to end OTR conversation
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)disableEncryptionWithUsername:(NSString*)username
                          accountName:(NSString*)accountName
                             protocol:(NSString*)protocol;

/**
 *  Current encryption state for buddy.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion current encryption state, called on callbackQueue
 */
- (void)messageStateForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                     completion:(void (^)(OTRKitMessageState messageState))completion;

//////////////////////////////////////////////////////////////////////
/// @name Socialist's Millionaire Protocol
//////////////////////////////////////////////////////////////////////

/**
 *  Initiate's SMP with shared secret to verify buddy identity.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param secret      the secret must match exactly between buddies
 */
- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                         secret:(NSString*)secret;

/**
 *  Initiate's SMP with shared secret to verify buddy identity.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param question    a question to ask remote buddy where the expected answer is the exact secret
 *  @param secret      the secret must match exactly between buddies
 */
- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                       question:(NSString*)question
                         secret:(NSString*)secret;

/**
 *  Respond to an SMP request with the secret answer.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param secret      the secret must match exactly between buddies
 */
- (void) respondToSMPForUsername:(NSString*)username
                     accountName:(NSString*)accountName
                        protocol:(NSString*)protocol
                          secret:(NSString*)secret;

//////////////////////////////////////////////////////////////////////
/// @name Shared Symmetric Key
//////////////////////////////////////////////////////////////////////

/**
 *  Requests a symmetric key for out-of-band crypto like file transfer.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param use         integer tag describing the use of the key
 *  @param useData     any extra data that may be required to use the key
 *  @param completion Symmetric key ready to be used externally, or error.
 */

- (void) requestSymmetricKeyForUsername:(NSString*)username
                            accountName:(NSString*)accountName
                               protocol:(NSString*)protocol
                                 forUse:(NSUInteger)use
                                useData:(NSData*)useData
                             completion:(void (^)(NSData *key, NSError *error))completion;

//////////////////////////////////////////////////////////////////////
/// @name Fingerprint Verification
//////////////////////////////////////////////////////////////////////

/**
 *  @param completion Returns an array of dictionaries using OTRAccountNameKey, OTRUsernameKey,
 *  OTRFingerprintKey, OTRProtocolKey, OTRFingerprintKey to store the relevant
 *  information.
 */
- (void) requestAllFingerprints:(void (^)(NSArray *allFingerprints))completion;


/**
 *  Delete a specified fingerprint.
 *
 *  @param fingerprint fingerprint to be deleted
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion whether not the operation was successful.
 */
- (void)deleteFingerprint:(NSString *)fingerprint
                 username:(NSString *)username
              accountName:(NSString *)accountName
                 protocol:(NSString *)protocol
               completion:(void (^)(BOOL success))completion;


/**
 *  For determining your own fingerprint.
 *
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion Returns your private key fingerprint
 */
- (void)fingerprintForAccountName:(NSString*)accountName
                         protocol:(NSString*)protocol
                       completion:(void (^)(NSString *fingerprint))completion;

/**
 *  For determining the fingerprint of a buddy.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion Returns username's private key fingerprint
 */
- (void)activeFingerprintForUsername:(NSString*)username
                         accountName:(NSString*)accountName
                            protocol:(NSString*)protocol
                          completion:(void (^)(NSString *activeFingerprint))completion;

/**
 *  Whether or not buddy's fingerprint is marked as verified.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion fingerprint verification state for buddy
 */
- (void)activeFingerprintIsVerifiedForUsername:(NSString*)username
                                   accountName:(NSString*)accountName
                                      protocol:(NSString*)protocol
                                    completion:(void (^)(BOOL verified))completion;


/**
 *  Mark a user's active fingerprint as verified
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param verified    whether or not to trust this fingerprint
 *  @param completion  whether or not operation was successful
 */
- (void)setActiveFingerprintVerificationForUsername:(NSString*)username
                                        accountName:(NSString*)accountName
                                           protocol:(NSString*)protocol
                                           verified:(BOOL)verified
                                         completion:(void (^)(void))completion;

/**
 *  Whether or not buddy has any previously verified fingerprints.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @param completoin Whether or not buddy has any previously verified fingerprints.
 */
- (void)hasVerifiedFingerprintsForUsername:(NSString *)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString *)protocol
                                completion:(void (^)(BOOL verified))completion;


@end