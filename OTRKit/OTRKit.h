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

@class OTRKit;

typedef NS_ENUM(NSUInteger, OTRKitMessageState) {
    OTRKitMessageStatePlaintext = 0, // OTRL_MSGSTATE_PLAINTEXT
    OTRKitMessageStateEncrypted = 1, // OTRL_MSGSTATE_ENCRYPTED
    OTRKitMessageStateFinished  = 2  // OTRL_MSGSTATE_FINISHED
};

typedef NS_ENUM(NSUInteger, OTRKitPolicy) {
    OTRKitPolicyNever = 0,
    OTRKitPolicyOpportunistic = 1,
    OTRKitPolicyManual = 2,
    OTRKitPolicyAlways = 3,
    OTRKitPolicyDefault = 4
};

typedef void (^OTRKitMessageCompletionBlock)(NSString *message);

extern NSString const *kOTRKitUsernameKey;
extern NSString const *kOTRKitAccountNameKey;
extern NSString const *kOTRKitFingerprintKey;
extern NSString const *kOTRKitProtocolKey;
extern NSString const *kOTRKitTrustKey;

@protocol OTRKitDelegate <NSObject>
@required
// Implement this delegate method to forward the injected message to the appropriate protocol
- (void) otrKit:(OTRKit*)otrkit
  injectMessage:(NSString*)message
      recipient:(NSString*)recipient
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol;

- (void)    otrKit:(OTRKit*)otrkit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol;

- (BOOL)       otrKit:(OTRKit*)otrKit
  isRecipientLoggedIn:(NSString*)recipient
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol;

@optional

- (int)            otrKit:(OTRKit*)otrKit
maxMessageSizeForProtocol:(NSString*)protocol;

- (void)                           otrKit:(OTRKit*)otrKit
showFingerprintConfirmationForAccountName:(NSString*)accountName
                                 protocol:(NSString*)protocol
                                 userName:(NSString*)userName
                                theirHash:(NSString*)theirHash
                                  ourHash:(NSString*)ourHash;

@end

@interface OTRKit : NSObject

@property (nonatomic, weak) id<OTRKitDelegate> delegate;
@property (nonatomic) dispatch_queue_t isolationQueue;
/** If none it uses `OTRL_POLICY_DEFAULT`
 */
@property (nonatomic) OTRKitPolicy otrPolicy;
@property (nonatomic, strong) NSString* dataPath;

/**
 * @param dataPath This is a path to a folder where private keys, fingerprints, and instance tags will be stored.
 *
 */
- (id) initWithDataPath:(NSString*)dataPath;

- (NSString*)privateKeyPath;
- (NSString*)fingerprintsPath;
- (NSString*)instanceTagsPath;

- (void)generatePrivateKeyForAccountName:(NSString *)accountName
                                protocol:(NSString *)protocol
                          completionBock:(void(^)(BOOL didGenerateKey))completionBlock;

- (void)hasPrivateKeyForAccountName:(NSString *)accountName
                           protocol:(NSString *)protocol
                     completionBock:(void(^)(BOOL hasPrivateKey))completionBlock;

- (void)checkIfGeneratingKeyForAccountName:(NSString *)accountName
                                  protocol:(NSString *)protocol
                                completion:(void (^)(BOOL isGeneratingKey))completion;

- (void)encodeMessage:(NSString *)message
            recipient:(NSString*)recipient
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
      completionBlock:(OTRKitMessageCompletionBlock)completionBlock;

- (void)decodeMessage:(NSString *)message
            recipient:(NSString*)recipient
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
      completionBlock:(OTRKitMessageCompletionBlock)completionBlock;    

- (void)generateInitiateOrRefreshMessageToRecipient:(NSString*)recipient
                                       accountName:(NSString*)accountName
                                           protocol:(NSString*)protocol
                                    completionBlock:(OTRKitMessageCompletionBlock)completionBlock;

- (NSString *)fingerprintForAccountName:(NSString*)accountName
                              protocol:(NSString*)protocol; // Returns your fingerprint

- (NSString *)fingerprintForUsername:(NSString*)username
                         accountName:(NSString*)accountName
                            protocol:(NSString*)protocol; // Returns buddy's fingerprint

- (BOOL)activeFingerprintIsVerifiedForUsername:(NSString*)username
                             accountName:(NSString*)accountName
                                protocol:(NSString*)protocol;

- (BOOL)hasVerifiedFingerprintsForUsername:(NSString *)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString *)protocol;

- (void)changeVerifyFingerprintForUsername:(NSString*)username
                               accountName:(NSString*)accountName
                                  protocol:(NSString*)protocol
                                 verrified:(BOOL)trusted;

- (BOOL)isConversationEncryptedForUsername:(NSString *)username
                               accountName:(NSString *)accountName
                                  protocol:(NSString *)protocol;

- (void)disableEncryptionForUsername:(NSString*)username
                          accountName:(NSString*)accountName
                             protocol:(NSString*)protocol;


- (OTRKitMessageState)messageStateForUsername:(NSString*)username
                                  accountName:(NSString*)accountName
                                     protocol:(NSString*)protocol;
/***
 Returns an array of dictionaries using OTRAccountNameKey, OTRUsernameKey, OTRFingerprintKey, OTRProtocolKey, OTRFingerprintKey to
 store the relevant information
 **/
- (NSArray *)allFingerprints;

- (BOOL)deleteFingerprint:(NSString *)fingerprint
                 username:(NSString *)username
              accountName:(NSString *)accountName
                 protocol:(NSString *)protocol;

@end