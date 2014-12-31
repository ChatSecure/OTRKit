//
//  OTRDataIncomingTransfer.m
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataIncomingTransfer.h"

@implementation OTRDataIncomingTransfer

- (instancetype) initWithRequestID:(NSString*)requestID
                        fileLength:(NSUInteger)fileLength
                          username:(NSString*)username
                       accountName:(NSString*)accountName
                          protocol:(NSString*)protocol
                               tag:(id)tag {
    if (self = [super initWithRequestID:requestID fileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag]) {
        self.fileData = [NSMutableData dataWithCapacity:fileLength];
    }
    return self;
}

@end
