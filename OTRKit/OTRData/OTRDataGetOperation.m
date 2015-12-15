//
//  OTRDataGetOperation.m
//  Pods
//
//  Created by David Chiles on 12/9/15.
//
//

#import "OTRDataGetOperation.h"
#import "OTRDataHandler.h"
#import "OTRDataRequest.h"
#import "OTRDataIncomingTransfer.h"

@interface OTRDataGetOperation ()

@property (nonatomic) BOOL requesting;
@property (nonatomic) BOOL completed;

@end

@implementation OTRDataGetOperation

- (instancetype)initWithRange:(NSRange)range incomingTransfer:(OTRDataIncomingTransfer *)transfer dataHandler:(OTRDataHandler *)dataHandler
{
    if (self = [super init]) {
        _dataHandler = dataHandler;
        _incomingTransfer = transfer;
        self.requesting = NO;
        
        NSString *rangeString = [NSString stringWithFormat:@"bytes=%d-%d", (int)range.location, (int)(range.location + range.length - 1)];
        
        NSString *requestId = [[NSUUID UUID] UUIDString];
        NSDictionary *headers = @{kHTTPHeaderRange: rangeString, kHTTPHeaderRequestID: requestId};
        
        _request = [[OTRDataRequest alloc] initWithRequestId:requestId url:transfer.offeredURL httpMethod:@"GET" httpHeaders:headers];
        _request.range = range;
        
    }
    return self;
}

- (void)requestCompleted {
    [self willChangeValueForKey:NSStringFromSelector(@selector(isFinished))];
    self.completed = YES;
    [self didChangeValueForKey:NSStringFromSelector(@selector(isFinished))];
}

#pragma MARK - NSOperation Overrides

- (void)start
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    self.requesting = YES;
    [self didChangeValueForKey:NSStringFromSelector(@selector(isExecuting))];
    
    //Send Request
    [self.dataHandler sendRequest:self.request username:self.incomingTransfer.username accountName:self.incomingTransfer.accountName protocol:self.incomingTransfer.protocol tag:self.incomingTransfer.tag];
    
}

- (BOOL)isAsynchronous
{
    return YES;
}

- (BOOL)isExecuting
{
    return self.requesting;
}

- (BOOL)isFinished
{
    return self.completed;
}

@end
