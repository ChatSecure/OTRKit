//
//  OTRDataRequest.h
//  Pods
//
//  Created by Christopher Ballinger on 1/19/15.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OTRDataRequest : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *requestId;
@property (nonatomic, strong, readonly) NSString *httpMethod;
@property (nonatomic, strong, readonly) NSDictionary *httpHeaders;

@property (nonatomic) NSRange range;

- (instancetype) initWithRequestId:(NSString*)requestId
                               url:(NSURL*)url
                        httpMethod:(NSString*)httpMethod
                       httpHeaders:(NSDictionary*)httpHeaders;

@end
NS_ASSUME_NONNULL_END
