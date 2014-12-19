//
//  OTRDataTransfer.m
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import "OTRDataTransfer.h"

@implementation OTRDataTransfer

- (instancetype) initWithURL:(NSURL*)url
                    mimeType:(NSString*)mimeType
                 totalLength:(NSUInteger)totalLength
                    fileHash:(NSString*)fileHash
                    username:(NSString*)username
                 accountName:(NSString*)accountName
                    protocol:(NSString*)protocol {
    if (self = [super init]) {
        _url = url;
        _mimeType = mimeType;
        _totalLength = totalLength;
        _fileHash = fileHash;
        _username = username;
        _accountName = accountName;
        _protocol = protocol;
    }
    return self;
}

@end
