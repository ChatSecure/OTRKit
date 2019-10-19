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
#import "OTRTLVHandler.h"
#import "OTRFingerprint.h"

@class OTRKit;

typedef NS_ENUM(NSUInteger, OTRKitMessageState) {
    OTRKitMessageStateUnknown,
    OTRKitMessageStatePlaintext,
    OTRKitMessageStateEncrypted,
    OTRKitMessageStateFinished
};

typedef NS_ENUM(NSUInteger, OTRKitPolicy) {
    OTRKitPolicyDefault,
    OTRKitPolicyNever,
    OTRKitPolicyOpportunistic,
    OTRKitPolicyManual,
    OTRKitPolicyAlways,
    
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

NS_ASSUME_NONNULL_BEGIN
@protocol OTRKitDelegate <NSObject>
#pragma mark Required OTRKitDelegate methods
@required

/**
 *  This method **MUST** be implemented or OTR will not work. All outgoing messages
 *  should be sent first through OTRKit encodeMessage and then passed from this delegate
 *  to the appropriate chat protocol manager to send the actual message.
 *
 *  @param otrKit      reference to shared instance
 *  @param message     message to be sent over the network. may contain ciphertext.
 *  @param username   intended recipient of the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param fingerprint fingerprint of contact, if in session
 *  @param tag optional tag to attached to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag;

#pragma mark OTRKitDelegate optional methods
@optional

/**
 *  All outgoing messages should be sent to the OTRKit encodeMessage method before being
 *  sent over the network.
 *  @note This method won't be called if you use the block-based completion version of encodeMessage.
 *
 *  @param otrKit      reference to shared instance
 *  @param encodedMessage     plaintext message
 *  @param wasEncrypted whether or not encodedMessage message is ciphertext, or just plaintext appended with the opportunistic whitespace. This is just a check of the encodedMessage message for a "?OTR" prefix. Nil if error.
 *  @param username      buddy who sent the message
 *  @param accountName your local account name
 *  @param fingerprint fingerprint of contact, if in session
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 encodedMessage:(nullable NSString*)encodedMessage
   wasEncrypted:(BOOL)wasEncrypted
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag
          error:(nullable NSError*)error;


/**
 *  All incoming messages should be sent to the OTRKit decodeMessage method before being
 *  processed by your application. You should only display the messages coming from this delegate method.
 *  @note This method won't be called if you use the block-based completion version of decodeMessage.
 *
 *  @param otrKit      reference to shared instance
 *  @param decodedMessage plaintext message to display to the user. May be nil if other party is sending raw TLVs without messages attached.
 *  @param wasEncrypted whether or not the original message sent to decodeMessage: was encrypted or plaintext. This is just a check of the original message for a "?OTR" prefix.
 *  @param tlvs        OTRTLV values that may be present.
 *  @param username      buddy who sent the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param fingerprint fingerprint of contact, if in session
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(nullable NSString*)decodedMessage
           tlvs:(NSArray<OTRTLV*>*)tlvs
   wasEncrypted:(BOOL)wasEncrypted
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag
          error:(nullable NSError*)error;

/**
 *  libotr likes to know if buddies are still "online". This method
 *  is called synchronously on the callback queue so be careful.
 *
 *  @param otrKit      reference to shared instance
 *  @param username   intended recipient of the message
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
 *  When the encryption status changes this method is called
 *
 *  @param otrKit      reference to shared instance
 *  @param messageState plaintext, encrypted or finished
 *  @param username     buddy whose state has changed
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param fingerprint fingerprint of contact
 */
- (void)    otrKit:(OTRKit*)otrKit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
       fingerprint:(OTRFingerprint*)fingerprint;

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
               tag:(nullable id)tag
             error:(nullable NSError*)error;

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
               useData:(nullable NSData*)useData
              username:(NSString*)username
           accountName:(NSString*)accountName
              protocol:(NSString*)protocol;

/** 
 * If you'd like to override the TOFU trust mechanism.
 * This method is called synchronously on the callback queue so be careful.
 */
- (BOOL)             otrKit:(OTRKit*)otrKit
evaluateTrustForFingerprint:(OTRFingerprint*)evaluateTrustForFingerprint;

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
                                      error:(nullable NSError*)error;
@end

@interface OTRKit : NSObject

#pragma mark Properties

@property (nonatomic, weak, readonly) id<OTRKitDelegate> delegate;

/**
 *  Defaults to main queue. All delegate and block callbacks will be done on this queue. Cannot be set to nil.
 */
@property (atomic, strong, readwrite) dispatch_queue_t callbackQueue;

/** 
 * By default uses `OTRKitPolicyDefault`
 */
@property (atomic, readwrite) OTRKitPolicy otrPolicy;

/**
 *  Path to where the OTR private keys and related data is stored.
 */
@property (nonatomic, copy, readonly) NSString* dataPath;

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

#pragma mark Setup
//////////////////////////////////////////////////////////////////////
/// @name Setup
//////////////////////////////////////////////////////////////////////

/**
 * Designated initialzer method.
 *
 * @param dataPath This is a path to a folder where private keys, fingerprints, and instance tags will be stored. If a nil dataPath is passed, a default within the documents directory is chosen.
 */
- (instancetype) initWithDelegate:(id<OTRKitDelegate>)delegate dataPath:(nullable NSString*)dataPath NS_DESIGNATED_INITIALIZER;

/** Use initWithDataPath: instead. */
- (instancetype) init NS_UNAVAILABLE;

/**
 *  For specifying fragmentation for a protocol.
 *
 *  @param maxSize  max size of protocol messages in bytes
 *  @param protocol protocol like "xmpp"
 */
- (void) setMaximumProtocolSize:(NSUInteger)maxSize forProtocol:(NSString*)protocol;


#pragma mark Key Generation
//////////////////////////////////////////////////////////////////////
/// @name Key Generation
//////////////////////////////////////////////////////////////////////

/**
 *  Initiates the generation of a new key pair for a given account/protocol, and optionally returns the fingerprint of the generated key via the completionBlock. If the key already exists this is a no-op that quickly returns the fingerprint (uppercase, without spaces).
 *  
 *  @param accountName Your account name
 *  @param protocol the protocol of accountName, such as @"xmpp"
 *  @param completion (optional) returns fingerprint if key exists or nil if there was an error
 */
- (void) generatePrivateKeyForAccountName:(NSString*)accountName
                                 protocol:(NSString*)protocol
                               completion:(void (^)(OTRFingerprint *_Nullable fingerprint, NSError * _Nullable error))completion;


#pragma mark Messaging
//////////////////////////////////////////////////////////////////////
/// @name Messaging
//////////////////////////////////////////////////////////////////////

/**
 * Encodes a message and optional array of OTRTLVs, splits it into fragments,
 * then injects the encoded data via the injectMessage: delegate method.
 * @param message The message to be encoded. May be nil if only sending TLVs.
 * @param tlvs Array of OTRTLVs, the data length of each TLV must be smaller than UINT16_MAX or it will be ignored. May be nil if only sending message.
 * @param username The intended recipient of the message
 * @param accountName Your account name
 * @param protocol the protocol of accountName, such as @"xmpp"
 * @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void)encodeMessage:(nullable NSString*)message
                 tlvs:(nullable NSArray<OTRTLV*>*)tlvs
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag;

/**
 * Encodes a message and optional array of OTRTLVs, splits it into fragments,
 * then injects the encoded data via the injectMessage: delegate method.
 * @note when using this method, you must implement the encodedMessage: delegate method.
 *
 * @param message The message to be encoded. May be nil if only sending TLVs.
 * @param tlvs Array of OTRTLVs, the data length of each TLV must be smaller than UINT16_MAX or it will be ignored. May be nil if only sending message.
 * @param username The intended recipient of the message
 * @param accountName Your account name
 * @param protocol the protocol of accountName, such as @"xmpp"
 * @param tag optional tag to attach additional application-specific data to message. Only used locally.
 * @param async If async is false, it will block the current thread until complete so you can synchronously capture values in the block, and the callback will be performed on the current thread instead of the callbackQueue.
 * @param completion If async, called on callbackQueue, otherwise current queue.
 */
- (void)encodeMessage:(nullable NSString*)message
                 tlvs:(nullable NSArray<OTRTLV*>*)tlvs
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag
                async:(BOOL)async
           completion:(void (^)(NSString* _Nullable encodedMessage, BOOL wasEncrypted, OTRFingerprint* _Nullable fingerprint, NSError* _Nullable error))completion;

/**
 *  All messages should be sent through here before being processed by your program.
 * @note when using this method, you must implement the decodedMessage: delegate method.
 *
 *  @param message     Encoded or plaintext incoming message
 *  @param username      account name of buddy who sent the message
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void)decodeMessage:(NSString*)message
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag;

/**
 *  All messages should be sent through here before being processed by your program.
 *
 *  @param message     Encoded or plaintext incoming message
 *  @param username      account name of buddy who sent the message
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 * @param async If async is false, it will block the current thread until complete so you can synchronously capture values in the block, and the callback will be performed on the current thread instead of the callbackQueue.
 * @param completion If async, called on callbackQueue, otherwise current queue.
 */
- (void)decodeMessage:(NSString*)message
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag
                async:(BOOL)async
           completion:(void (^)(NSString* _Nullable decodedMessage, NSArray<OTRTLV*>* tlvs, BOOL wasEncrypted, OTRFingerprint* _Nullable fingerprint, NSError* _Nullable error))completion;


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
 *  Shortcut for injecting a "?OTRv23?" message.
 *
 *  @param username   name of buddy you'd like to start OTR conversation
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
 *  @param username   name of buddy you'd like to end OTR conversation
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
 */
- (OTRKitMessageState)messageStateForUsername:(NSString*)username
                                  accountName:(NSString*)accountName
                                     protocol:(NSString*)protocol;

#pragma mark Socialist's Millionaire Protocol
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

#pragma mark Shared Symmetric Key
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
 *  @param error Symmetric key ready to be used externally, or error.
 *  @return Symmetric key ready to be used externally, or nil for error.
 */

- (nullable NSData*) requestSymmetricKeyForUsername:(NSString*)username
                            accountName:(NSString*)accountName
                               protocol:(NSString*)protocol
                                 forUse:(NSUInteger)use
                                useData:(nullable NSData*)useData
                                  error:(NSError**)error;

#pragma mark Fingerprint Verification
//////////////////////////////////////////////////////////////////////
/// @name Fingerprint Verification
//////////////////////////////////////////////////////////////////////


/** Synchronously fetches every known fingerprint, excluding yourself. */
- (NSArray<OTRFingerprint*>*) allFingerprints;

/** Synchronously fetches your own fingerprint for this device / account, which is implicitly trusted. */
- (nullable OTRFingerprint*)fingerprintForAccountName:(NSString*)accountName
                                             protocol:(NSString*)protocol;

/** Synchronously fetches all fingerprints known for a given user */
- (NSArray<OTRFingerprint*>*) fingerprintsForUsername:(NSString*)username
                                          accountName:(NSString*)accountName
                                             protocol:(NSString*)protocol;

/** Synchronously fetches fingerprint used in the current session with user. */
- (nullable OTRFingerprint*)activeFingerprintForUsername:(NSString*)username
                                             accountName:(NSString*)accountName
                                             protocol:(NSString*)protocol;

/** Update a fingerprint's trust status, or store a new one. */
- (void) saveFingerprint:(OTRFingerprint*)fingerprint;

/** Delete fingerprint from the trust store. Will throw an error if you try to delete the active fingerprint, or the fingerprint isn't in the store. */
- (BOOL) deleteFingerprint:(OTRFingerprint*)fingerprint error:(NSError**)error;

#pragma mark TLV Handlers
//////////////////////////////////////////////////////////////////////
/// @name TLV Handlers
//////////////////////////////////////////////////////////////////////

/**
 *  You can register custom handlers for TLV types. For instance OTRDataHandler
 *  can handle OTRDATA TLVs (0x0100, 0x0101)
 */
- (void) registerTLVHandler:(id<OTRTLVHandler>)handler;

#pragma mark Utility
//////////////////////////////////////////////////////////////////////
/// @name Utility
//////////////////////////////////////////////////////////////////////

/**
 *  Test if a string starts with "?OTR".
 *
 *  @param string string to test
 *
 *  @return [string hasPrefix:@"?OTR"]
 */
+ (BOOL) stringStartsWithOTRPrefix:(NSString*)string;

/**
 *  Current libotr version
 *
 *  @return string version number ex. 4.0.0
 */
+ (NSString *)libotrVersion;

+ (NSString *)libgcryptVersion;

+ (NSString *)libgpgErrorVersion;

@end

NS_ASSUME_NONNULL_END
