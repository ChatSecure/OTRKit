//
//  OTRDataTransfer.m
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import "OTRDataTransfer.h"

@implementation OTRDataTransfer

- (instancetype) initWithFileLength:(NSUInteger)fileLength
                          username:(NSString*)username
                       accountName:(NSString*)accountName
                          protocol:(NSString*)protocol
                               tag:(id)tag {
    if (self = [super init]) {
        _transferId = [[NSUUID UUID] UUIDString];
        _username = username;
        _fileLength = fileLength;
        _accountName = accountName;
        _protocol = protocol;
        _tag = tag;
    }
    return self;
}

@end
