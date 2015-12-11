//
//  OTRDataHandler+Private.h
//  Pods
//
//  Created by David Chiles on 12/9/15.
//
//

extern const NSString * kHTTPHeaderRange;
extern const NSString * kHTTPHeaderRequestID;

@interface OTRDataHandler ()

- (void) sendRequest:(OTRDataRequest*)request
            username:(NSString*)username
         accountName:(NSString*)accountName
            protocol:(NSString*)protocol
                 tag:(id)tag;

@end