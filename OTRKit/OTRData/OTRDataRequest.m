//
//  OTRDataRequest.m
//  Pods
//
//  Created by Christopher Ballinger on 1/19/15.
//
//

#import "OTRDataRequest.h"

@implementation OTRDataRequest
- (instancetype) initWithRequestId:(NSString*)requestId
                               url:(NSURL*)url
                        httpMethod:(NSString*)httpMethod
                       httpHeaders:(NSDictionary*)httpHeaders {
    if (self = [super init]) {
        _url = url;
        _httpMethod = httpMethod;
        _requestId = requestId;
        _httpHeaders = httpHeaders;
    }
    return self;
}
@end
