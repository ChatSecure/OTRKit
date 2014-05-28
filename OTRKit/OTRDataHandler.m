//
//  OTRDataHandler.m
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/15/14.
//
//

#import "OTRDataHandler.h"
#import "HTTPMessage.h"
#import "OTRKit.h"
#import "OTRDataTransfer.h"

static NSString * const kOTRDataHandlerURLScheme = @"otr-in-band";
static NSString * const kOTRDataErrorDomain = @"org.chatsecure.OTRDataError";

static NSString * const kHTTPHeaderRequestID = @"Request-Id";
static NSString * const kHTTPHeaderFileLength = @"File-Length";
static NSString * const kHTTPHeaderFileHashSHA1 = @"File-Hash-SHA1";
static NSString * const kHTTPHeaderMimeType = @"Mime-Type";


@interface OTRDataHandler()
@property (nonatomic, strong) NSMutableDictionary *activeTransfers;
@end

@implementation OTRDataHandler

- (id) init {
    if (self = [super init]) {
        self.transferCache = [[NSMutableDictionary alloc] init];
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
    NSString *requestID = [request headerField:kHTTPHeaderRequestID];
    NSURL *url = request.url;
    
    if (![url.scheme isEqualToString:kOTRDataHandlerURLScheme]) {
        [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Unknown scheme" httpBody:nil];
        return;
    }
    
    if ([requestMethod isEqualToString:@"OFFER"]) {
        NSLog(@"Incoming offer: %@", request);
        [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:200 httpStatusString:@"OK" httpBody:nil];
        NSString *fileLengthString = [request headerField:kHTTPHeaderFileLength];
        if (!fileLengthString) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"File-Length must be supplied" httpBody:nil];
            return;
        }
        NSInteger fileLength = [fileLengthString integerValue];
        NSString *fileHashString = [request headerField:kHTTPHeaderFileHashSHA1];
        if (!fileHashString) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"File-Hash-SHA1 must be supplied" httpBody:nil];
            return;
        }
        NSString *mimeTypeString = [request headerField:kHTTPHeaderMimeType];
        OTRDataTransfer *transfer = [[OTRDataTransfer alloc] initWithURL:url mimeType:mimeTypeString totalLength:fileLength fileHash:fileHashString username:username accountName:accountName protocol:protocol];
        [self.activeTransfers setObject:transfer forKey:url];
        // notify delegate of new offered transfer
        NSLog(@"New active transfer");
    } else if ([requestMethod isEqualToString:@"GET"]) {
        
    }
}

- (void) handleIncomingResponseData:(NSData *)responseData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol error:(NSError *__autoreleasing *)error {
    
}

- (void) sendResponseToUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                      requestID:(NSString*)requestID
                 httpStatusCode:(int)httpStatusCode
               httpStatusString:(NSString*)httpStatusString
                       httpBody:(NSData*)httpBody {
    HTTPMessage *response = [[HTTPMessage alloc] initResponseWithStatusCode:httpStatusCode description:httpStatusString version:@"1.1"];
    [response setHeaderField:kHTTPHeaderRequestID value:requestID];
    [response setBody:httpBody];
    NSData *httpData = [response messageData];
    OTRTLV *tlv = [[OTRTLV alloc] initWithType:OTRTLVTypeDataResponse data:httpData];
    if (!tlv) {
        NSLog(@"OTRDATA Error: TLV too long!");
        return;
    }
    [[OTRKit sharedInstance] encodeMessage:nil tlvs:@[tlv] username:username accountName:accountName protocol:protocol tag:nil];
}

@end
