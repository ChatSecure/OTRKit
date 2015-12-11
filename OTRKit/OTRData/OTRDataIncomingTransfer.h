//
//  OTRDataIncomingTransfer.h
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataTransfer.h"
#import "OTRDataRequest.h"

@interface OTRDataIncomingTransfer : OTRDataTransfer

@property (nonatomic, strong) NSURL *offeredURL;

- (void) handleResponse:(NSData*)response forRequest:(OTRDataRequest*)request;

@end
