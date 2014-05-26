//
//  OTRDataHandler.h
//  OTRKit
//
//  Created by Christopher Ballinger on 5/15/14.
//

#import <Foundation/Foundation.h>


@interface OTRDataHandler : NSObject



- (void) handleIncomingRequestData:(NSData*)requestData
                          username:(NSString*)username
                       accountName:(NSString*)accountName
                          protocol:(NSString*)protocol
                             error:(NSError**)error;

- (void) handleIncomingResponseData:(NSData*)responseData
                           username:(NSString*)username
                        accountName:(NSString*)accountName
                           protocol:(NSString*)protocol
                              error:(NSError**)error;

@end
