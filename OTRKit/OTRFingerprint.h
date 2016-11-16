//
//  OTRFingerprint.h
//  OTRKit
//
//  Created by Chris Ballinger on 11/8/16.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OTRTrustLevel) {
    /** Trust level is not set */
    OTRTrustLevelUnknown,
    /** A new untrusted device. Set for any device after the first. */
    OTRTrustLevelUntrustedNew,
    /** Device marked as untrusted by the user */
    OTRTrustLevelUntrustedUser,
    /** First device seen is implicitly trusted (TOFU) */
    OTRTrustLevelTrustedTofu,
    /** Device marked as trusted by the user */
    OTRTrustLevelTrustedUser,
};

NS_ASSUME_NONNULL_BEGIN
@interface OTRFingerprint : NSObject

@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, copy, readonly) NSString *accountName;
@property (nonatomic, copy, readonly) NSString *protocol;
@property (nonatomic, copy, readonly) NSData *fingerprint;
@property (nonatomic, readwrite) OTRTrustLevel trustLevel;

- (instancetype) initWithUsername:(NSString*)username
                      accountName:(NSString*)accountName
                         protocol:(NSString*)protocol
                      fingerprint:(NSData*)fingerprint
                       trustLevel:(OTRTrustLevel)trustLevel;

/** Returns true if trustLevel = (OTRTrustLevelTrustedTofu || OTRTrustLevelTrustedTofu) */
- (BOOL) isTrusted;

- (BOOL) isEqualToFingerprint:(OTRFingerprint*)fingerprint;

@end
NS_ASSUME_NONNULL_END
