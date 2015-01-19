//
//  OTRTLV.m
//  OTRKit
//
//  Created by Christopher Ballinger on 3/19/14.
//
//

#import "OTRTLV.h"

@implementation OTRTLV

- (instancetype) initWithType:(OTRTLVType)type data:(NSData *)data {
    NSParameterAssert(data);
    if (self = [super init]) {
        _type = type;
        _data = data;
        if (![self isValidLength]) {
            return nil;
        }
    }
    return self;
}

- (BOOL) isValidLength {
    if (!self.data || self.data.length > UINT16_MAX) {
        return NO;
    }
    return YES;
}

@end
