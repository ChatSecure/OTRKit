//
//  OTRDataIncomingTransfer.m
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataIncomingTransfer.h"

@interface OTRDataIncomingTransfer()
@property (nonatomic, strong) NSMutableData *incomingFileData;
@end

@implementation OTRDataIncomingTransfer

- (instancetype) initWithFileLength:(NSUInteger)fileLength
                           username:(NSString*)username
                        accountName:(NSString*)accountName
                           protocol:(NSString*)protocol
                                tag:(id)tag {
    if (self = [super initWithFileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag]) {
        self.incomingFileData = [NSMutableData dataWithLength:fileLength];
    }
    return self;
}

- (void) handleResponse:(NSData*)response forRequest:(OTRDataRequest*)request {
    NSRange range = request.range;
    if (!response.length) {
        return;
    }
    NSAssert(response.length == range.length, @"Data length and range must match!");
    if (response.length != range.length) {
        return;
    }
    [self.incomingFileData replaceBytesInRange:range withBytes:response.bytes length:response.length];
    
    self.bytesTransferred += response.length;
    if (self.bytesTransferred == self.fileLength) {
        self.fileData = self.incomingFileData;
    }
}


@end
