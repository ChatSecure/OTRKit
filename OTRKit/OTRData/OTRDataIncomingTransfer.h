//
//  OTRDataIncomingTransfer.h
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataTransfer.h"
#import "OTRDataRequest.h"

NS_ASSUME_NONNULL_BEGIN
@interface OTRDataIncomingTransfer : OTRDataTransfer

@property (nonatomic, strong, nullable) NSURL *offeredURL;

- (void) handleResponse:(NSData*)response forRequest:(OTRDataRequest*)request;

@end
NS_ASSUME_NONNULL_END
