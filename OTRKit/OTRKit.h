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

extern NSString const *kOTRKitUsernameKey;
extern NSString const *kOTRKitAccountNameKey;
extern NSString const *kOTRKitFingerprintKey;
extern NSString const *kOTRKitProtocolKey;
extern NSString const *kOTRKitTrustKey;

@protocol OTRKitDelegate <NSObject>
@required
// Implement this delegate method to forward the injected message to the appropriate protocol
- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
      recipient:(NSString*)recipient
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol;

- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(NSString*)message
           tlvs:(NSArray*)tlvs
         sender:(NSString*)sender
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol;

- (void)    otrKit:(OTRKit*)otrKit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol;

- (BOOL)       otrKit:(OTRKit*)otrKit
  isRecipientLoggedIn:(NSString*)recipient
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol;

- (void)                           otrKit:(OTRKit*)otrKit
showFingerprintConfirmationForAccountName:(NSString*)accountName
                                 protocol:(NSString*)protocol
                                 userName:(NSString*)userName
                                theirHash:(NSString*)theirHash
                                  ourHash:(NSString*)ourHash;

- (void) otrKit:(OTRKit*)otrKit
 handleSMPEvent:(OTRKitSMPEvent)event
       progress:(double)progress
       question:(NSString*)question;

- (void)    otrKit:(OTRKit*)otrKit
handleMessageEvent:(OTRKitMessageEvent)event
           message:(NSString*)message
             error:(NSError*)error;

- (void)        otrKit:(OTRKit*)otrKit
  receivedSymmetricKey:(NSData*)symmetricKey
                forUse:(NSUInteger)use
               useData:(NSData*)useData;

@optional

- (void) otrKit:(OTRKit *)otrKit
willStartGeneratingPrivateKeyForAccountName:(NSString*)accountName
protocol:(NSString*)protocol;

- (void) otrKit:(OTRKit *)otrKit
didFinishGeneratingPrivateKeyForAccountName:(NSString*)accountName
       protocol:(NSString*)protocol
          error:(NSError*)error;

- (int)            otrKit:(OTRKit*)otrKit
maxMessageSizeForProtocol:(NSString*)protocol;

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
 * Encodes a message and optional array of OTRTLVs, splits it into fragments,
 * then injects the encoded data via the injectMessage: delegate method.
 * @param message The message to be encoded
 * @param tlvs Array of OTRTLVs, the data length of each TLV must be smaller than UINT16_MAX or it will be ignored.
 * @param recipient The intended recipient of the message
 * @param accountName Your account name
 * @param protocol the protocol of accountName, such as @"xmpp"
 */
- (void)encodeMessage:(NSString*)message
                 tlvs:(NSArray*)tlvs
            recipient:(NSString*)recipient
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol;

/**
 *  All messages should be sent through here before being processed by your program.
 *
 *  @param message     Encoded or plaintext incoming message
 *  @param sender      account name of buddy who sent the message
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)decodeMessage:(NSString*)message
               sender:(NSString*)sender
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol;

/**
 *  You can use this method to determine whether or not OTRKit is currently generating
 *  a private key.
 *
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param completion  whether or not we are currently generating a key
 */
- (void)checkIfGeneratingKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol completion:(void (^)(BOOL isGeneratingKey))completion;

/**
 *  Shortcut for injecting a "?OTR?" message.
 *
 *  @param recipient   name of buddy you'd like to start OTR conversation
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)inititateEncryptionWithRecipient:(NSString*)recipient
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
- (void)disableEncryptionWithRecipient:(NSString*)recipient
                           accountName:(NSString*)accountName
                              protocol:(NSString*)protocol;

/**
 *  Current encryption state for buddy
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return current encryption state
 */
- (OTRKitMessageState)messageStateForUsername:(NSString*)username
                                  accountName:(NSString*)accountName
                                     protocol:(NSString*)protocol;

//////////////////////////////////////////////////////////////////////
/// @name Socialist's Millionaire Protocol
//////////////////////////////////////////////////////////////////////

- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                         secret:(NSString*)secret;

- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                       question:(NSString*)question
                         secret:(NSString*)secret;

- (void) respondToSMPForUsername:(NSString*)username
                     accountName:(NSString*)accountName
                        protocol:(NSString*)protocol
                          secret:(NSString*)secret;

/**
 *  
 *
 *  @param username    <#username description#>
 *  @param accountName <#accountName description#>
 *  @param protocol    <#protocol description#>
 *  @param use         <#use description#>
 *  @param useData     <#useData description#>
 *  @param error       <#error description#>
 *
 *  @return <#return value description#>
 */

- (NSData*) requestSymmetricKeyForUsername:(NSString*)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString*)protocol
                                    forUse:(NSUInteger)use
                                   useData:(NSData*)useData
                                     error:(NSError**)error;

//////////////////////////////////////////////////////////////////////
/// @name Fingerprint Verification
//////////////////////////////////////////////////////////////////////

/**
 *  Returns an array of dictionaries using OTRAccountNameKey, OTRUsernameKey,
 *  OTRFingerprintKey, OTRProtocolKey, OTRFingerprintKey to store the relevant
 *  information.
 */
@property (nonatomic, strong, readonly) NSArray *allFingerprints;

/**
 *  Delete a specified fingerprint.
 *
 *  @param fingerprint fingerprint to be deleted
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return whether not the operation was successful.
 */
- (BOOL)deleteFingerprint:(NSString *)fingerprint
                 username:(NSString *)username
              accountName:(NSString *)accountName
                 protocol:(NSString *)protocol;

/**
 *  For determining your own fingerprint.
 *
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return Returns your private key fingerprint
 */
- (NSString *)fingerprintForAccountName:(NSString*)accountName
                               protocol:(NSString*)protocol;

/**
 *  For determining the fingerprint of a buddy.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return Returns username's private key fingerprint
 */
- (NSString *)activeFingerprintForUsername:(NSString*)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString*)protocol;

/**
 *  Whether or not buddy's fingerprint is marked as verified.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return fingerprint verification state for buddy
 */
- (BOOL)activeFingerprintIsVerifiedForUsername:(NSString*)username
                                   accountName:(NSString*)accountName
                                      protocol:(NSString*)protocol;

/**
 *  Mark a user's active fingerprint as verified
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param verified    whether or not to trust this fingerprint
 */
- (void)setActiveFingerprintVerificationForUsername:(NSString*)username
                                        accountName:(NSString*)accountName
                                           protocol:(NSString*)protocol
                                           verified:(BOOL)verified;
/**
 *  Whether or not buddy has any previously verified fingerprints.
 *
 *  @param username    username of remote buddy
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *
 *  @return Whether or not buddy has any previously verified fingerprints.
 */
- (BOOL)hasVerifiedFingerprintsForUsername:(NSString *)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString *)protocol;

@end