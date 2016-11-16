//
//  OTRFingerprint.m
//  OTRKit
//
//  Created by Chris Ballinger on 11/8/16.
//
//

#import "OTRFingerprint.h"

@implementation OTRFingerprint

- (instancetype) initWithUsername:(NSString*)username
                      accountName:(NSString*)accountName
                         protocol:(NSString*)protocol
                      fingerprint:(NSData*)fingerprint
                       trustLevel:(OTRTrustLevel)trustLevel {
    NSParameterAssert(username != nil);
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(fingerprint != nil);
    if (self = [super init]) {
        _username = [username copy];
        _accountName = [accountName copy];
        _protocol = [protocol copy];
        _fingerprint = [fingerprint copy];
        _trustLevel = trustLevel;
    }
    return self;
}

/** Returns true if trustLevel = (OTRTrustLevelTrustedTofu || OTRTrustLevelTrustedTofu) */
- (BOOL) isTrusted {
    return self.trustLevel == OTRTrustLevelTrustedUser ||
    self.trustLevel == OTRTrustLevelTrustedTofu;
}

- (BOOL) isEqualToFingerprint:(OTRFingerprint*)fingerprint
{
    if (!fingerprint) { return NO; }
    
    return [self.username isEqualToString:fingerprint.username] &&
           [self.accountName isEqualToString:fingerprint.accountName] &&
           [self.protocol isEqualToString:self.protocol] &&
           [self.fingerprint isEqualToData:fingerprint.fingerprint] &&
           self.trustLevel == fingerprint.trustLevel;
}

@end
