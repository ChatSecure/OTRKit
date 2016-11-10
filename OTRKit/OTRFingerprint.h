//
//  OTRFingerprint.h
//  OTRKit
//
//  Created by Chris Ballinger on 11/8/16.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OTRTrustLevel) {
    OTRTrustLevelUntrustedNew = 0,
    OTRTrustLevelUntrusted    = 1,
    OTRTrustLevelTrustedTofu  = 2,
    OTRTrustLevelTrustedUser  = 3,
};

NS_ASSUME_NONNULL_BEGIN
@interface OTRFingerprint : NSObject

@property (nonatomic, copy, readonly) NSString *username;
@property (nonatomic, copy, readonly) NSString *accountName;
@property (nonatomic, copy, readonly) NSString *protocol;
@property (nonatomic, copy, readonly) NSString *fingerprint;
@property (nonatomic, readwrite) OTRTrustLevel trustLevel;

- (instancetype) initWithUsername:(NSString*)username
                      accountName:(NSString*)accountName
                         protocol:(NSString*)protocol
                      fingerprint:(NSString*)fingerprint
                       trustLevel:(OTRTrustLevel)trustLevel;

/** Returns true if trustLevel = (OTRTrustLevelTrustedTofu || OTRTrustLevelTrustedTofu) */
- (BOOL) isTrusted;

/** Used internally. Stringified version of trustLevel */
- (NSString*) trustLavelString;

@end
NS_ASSUME_NONNULL_END
