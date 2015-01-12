//
//  NSData+OTRDATA.m
//  Pods
//
//  Created by Christopher Ballinger on 1/12/15.
//
//

#import "NSData+OTRDATA.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSData (OTRDATA)

- (NSData*) otr_SHA1 {
    uint8_t *digest = malloc(sizeof(uint8_t) * CC_SHA1_DIGEST_LENGTH);
    if (!digest) {
        return nil;
    }
    CC_SHA1(self.bytes, (CC_LONG)self.length, digest);
    NSData *digestData = [NSData dataWithBytesNoCopy:digest length:CC_SHA1_DIGEST_LENGTH freeWhenDone:YES];
    return digestData;
}

// http://stackoverflow.com/a/9084784/805882
- (NSString *)otr_hexString {    
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    
    if (!dataBuffer)
        return [NSString string];
    
    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return [NSString stringWithString:hexString];
}

@end
