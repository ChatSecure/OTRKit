//
//  OTRDataHandler.m
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/15/14.
//
//

#import "OTRDataHandler.h"
#import "HTTPMessage.h"

static NSString * const kOTRDataHandlerURLScheme = @"otr-in-band";
static NSString * const kOTRDataErrorDomain = @"org.chatsecure.OTRDataError";


@interface OTRDataHandler()

@end

@implementation OTRDataHandler

- (id) init {
    if (self = [super init]) {
    }
    return self;
}

- (void) handleIncomingRequestData:(NSData *)requestData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol error:(NSError *__autoreleasing *)error {
    HTTPMessage *request = [[HTTPMessage alloc] initEmptyRequest];
    [request appendData:requestData];
    if (request.isHeaderComplete) {
        NSLog(@"Headers: %@", request.allHeaderFields);
    } else {
        *error = [NSError errorWithDomain:kOTRDataErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"Message has incomplete headers"}];
        return;
    }
    
    NSString *requestMethod = request.method;
    NSString *uuid = [request headerField:@"Request-Id"];
    NSURL *url = request.url;
    
    if ([requestMethod isEqualToString:@"OFFER"]) {
        NSLog(@"Incoming offer: %@", request);
    } else if ([requestMethod isEqualToString:@"GET"]) {
        
    }
}

- (void) handleIncomingResponseData:(NSData *)responseData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol error:(NSError *__autoreleasing *)error {
    
}


@end
