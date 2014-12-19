//
//  OTRDataHandler.m
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/15/14.
//
//

#import "OTRDataHandler.h"
#import "OTRHTTPMessage.h"
#import "OTRDataTransfer.h"
#import "OTRTLV.h"

static NSString * const kOTRDataHandlerURLScheme = @"otr-in-band";
static NSString * const kOTRDataErrorDomain = @"org.chatsecure.OTRDataError";

static NSString * const kHTTPHeaderRequestID = @"Request-Id";
static NSString * const kHTTPHeaderFileLength = @"File-Length";
static NSString * const kHTTPHeaderFileHashSHA1 = @"File-Hash-SHA1";
static NSString * const kHTTPHeaderMimeType = @"Mime-Type";

static NSUInteger kOTRDataMaxChunkLength = 16384;

@interface OTRDataHandler()
@property (nonatomic, strong, readonly) NSMutableDictionary *activeTransfers;
@end

@implementation OTRDataHandler

- (instancetype) initWithDelegate:(id<OTRDataHandlerDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _activeTransfers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)receiveTLVs:(NSArray*)tlvs
           username:(NSString*)username
        accountName:(NSString*)accountName
           protocol:(NSString*)protocol
                tag:(id)tag {
    [tlvs enumerateObjectsUsingBlock:^(OTRTLV *tlv, NSUInteger idx, BOOL *stop) {
        if (tlv.type == OTRTLVTypeDataRequest) {
            [self handleIncomingRequestData:tlv.data username:username accountName:accountName protocol:protocol tag:tag];
        } else if (tlv.type == OTRTLVTypeDataResponse) {
            [self handleIncomingResponseData:tlv.data username:username accountName:accountName protocol:protocol tag:tag];
        }
    }];
}

- (void) handleIncomingRequestData:(NSData *)requestData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag {
    NSError *error = nil;
    OTRHTTPMessage *request = [[OTRHTTPMessage alloc] initEmptyRequest];
    [request appendData:requestData];
    if (request.isHeaderComplete) {
        NSLog(@"Headers: %@", request.allHTTPHeaderFields);
    } else {
        error = [NSError errorWithDomain:kOTRDataErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"Message has incomplete headers"}];
        return;
    }
    
    NSString *requestMethod = request.HTTPMethod;
    NSString *requestID = [request valueForHTTPHeaderField:kHTTPHeaderRequestID];
    NSURL *url = request.url;
    
    if (![url.scheme isEqualToString:kOTRDataHandlerURLScheme]) {
        [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Unknown scheme" httpBody:nil tag:tag];
        return;
    }
    
    if ([requestMethod isEqualToString:@"OFFER"]) {
        NSLog(@"Incoming offer: %@", request);
        [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:200 httpStatusString:@"OK" httpBody:nil tag:tag];
        NSString *fileLengthString = [request valueForHTTPHeaderField:kHTTPHeaderFileLength];
        if (!fileLengthString) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"File-Length must be supplied" httpBody:nil tag:tag];
            return;
        }
        NSInteger fileLength = [fileLengthString integerValue];
        NSString *fileHashString = [request valueForHTTPHeaderField:kHTTPHeaderFileHashSHA1];
        if (!fileHashString) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"File-Hash-SHA1 must be supplied" httpBody:nil tag:tag];
            return;
        }
        NSString *mimeTypeString = [request valueForHTTPHeaderField:kHTTPHeaderMimeType];
        OTRDataTransfer *transfer = [[OTRDataTransfer alloc] initWithURL:url mimeType:mimeTypeString totalLength:fileLength fileHash:fileHashString username:username accountName:accountName protocol:protocol];
        [self.activeTransfers setObject:transfer forKey:url];
        // notify delegate of new offered transfer
        [self.delegate dataHandler:self offeredTransfer:transfer tag:tag];
    } else if ([requestMethod isEqualToString:@"GET"]) {
        NSLog(@"Get");
        OTRDataTransfer *transfer = [self.activeTransfers objectForKey:url];
        if (!transfer) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"No such offer made" httpBody:nil tag:tag];
            return;
        }
                
        NSString *rangeHeader = [request valueForHTTPHeaderField:@"Range"];
        if (!rangeHeader) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Must have Range header" httpBody:nil tag:tag];
            return;
        }
        
        NSArray *rangeComponents = [rangeHeader componentsSeparatedByString:@"="];
        if (rangeComponents.count != 2 || ![[rangeComponents firstObject] isEqualToString:@"bytes"]) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Range must start with bytes=" httpBody:nil tag:tag];
            return;
        }
        
        NSArray *startEndRanges = [[rangeComponents lastObject] componentsSeparatedByString:@"-"];
        
        if (startEndRanges.count != 2) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Range must be START-END" httpBody:nil tag:tag];
            return;
        }
        
        NSUInteger startOfRange = [[startEndRanges firstObject] unsignedIntegerValue];
        NSUInteger endOfRange = [[startEndRanges lastObject] unsignedIntegerValue];
        
        if (endOfRange - startOfRange + 1 > kOTRDataMaxChunkLength || startOfRange > endOfRange) {
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Invalid Range" httpBody:nil tag:tag];
            return;
        }
        NSRange range = NSMakeRange(startOfRange, endOfRange - startOfRange);
        NSData *subdata = [transfer.fileData subdataWithRange:range];
        float percentageComplete = (float)endOfRange / (float)transfer.fileData.length;
        
        [self.delegate dataHandler:self transfer:transfer progress:percentageComplete tag:tag];
        
        if (percentageComplete > 0.98f) {
            [self.delegate dataHandler:self transferComplete:transfer tag:tag];
        }
        
        [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:200 httpStatusString:@"OK" httpBody:subdata tag:tag];
    }
}

- (void) handleIncomingResponseData:(NSData *)responseData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag {
    
}

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithURL:(NSURL*)fileURL
                username:(NSString*)username
             accountName:(NSString*)accountName
                protocol:(NSString*)protocol
                     tag:(id)tag {
    NSString *fileName = [[fileURL path] lastPathComponent];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    [self sendFileWithName:fileName fileData:fileData username:username accountName:accountName protocol:protocol tag:tag];
}

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithName:(NSString*)fileName
                 fileData:(NSData*)fileData
                 username:(NSString*)username
              accountName:(NSString*)accountName
                 protocol:(NSString*)protocol
                      tag:(id)tag {
    
}


- (void) sendResponseToUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                      requestID:(NSString*)requestID
                 httpStatusCode:(int)httpStatusCode
               httpStatusString:(NSString*)httpStatusString
                       httpBody:(NSData*)httpBody
                            tag:(id)tag {
    OTRHTTPMessage *response = [[OTRHTTPMessage alloc] initResponseWithStatusCode:httpStatusCode description:httpStatusString version:OTRHTTPVersion1_1];
    [response setValue:requestID forHTTPHeaderField:kHTTPHeaderRequestID];
    response.HTTPBody = httpBody;
    NSData *httpData = [response HTTPMessageData];
    OTRTLV *tlv = [[OTRTLV alloc] initWithType:OTRTLVTypeDataResponse data:httpData];
    if (!tlv) {
        NSLog(@"OTRDATA Error: TLV too long!");
        return;
    }
    [self.delegate dataHandler:self sendTLVs:@[tlv] username:username accountName:accountName protocol:protocol tag:tag];
}

@end
