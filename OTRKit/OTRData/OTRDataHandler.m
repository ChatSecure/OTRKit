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
#import "OTRDataIncomingTransfer.h"
#import "OTRDataOutgoingTransfer.h"
#import "OTRTLV.h"
#import "OTRKit.h"
#import "NSData+OTRDATA.h"

static NSString * const kOTRDataHandlerURLScheme = @"otr-in-band";
static NSString * const kOTRDataErrorDomain = @"org.chatsecure.OTRDataError";

static NSString * const kHTTPHeaderRequestID = @"Request-Id";
static NSString * const kHTTPHeaderFileLength = @"File-Length";
static NSString * const kHTTPHeaderFileHashSHA1 = @"File-Hash-SHA1";
static NSString * const kHTTPHeaderMimeType = @"Mime-Type";

static const NSUInteger kOTRDataMaxChunkLength = 16384;
static const NSUInteger kOTRDataMaxFileSize = 1024*1024*64;


@interface OTRDataHandler()

@property (nonatomic) dispatch_queue_t internalQueue;

/**
 *  Keyed to Request-Id
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *incomingTransfers;

/**
 *  Keyed to Request-Id
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *outgoingTransfers;

@end

@implementation OTRDataHandler

- (instancetype) init {
    if (self = [self initWithOTRKit:nil delegate:nil]) {
    }
    return self;
}

- (instancetype) initWithOTRKit:(OTRKit*)otrKit delegate:(id<OTRDataHandlerDelegate>)delegate {
    if (self = [super init]) {
        _internalQueue = dispatch_queue_create("OTRDATA Queue", 0);
        _delegate = delegate;
        _otrKit = otrKit;
        _callbackQueue = dispatch_get_main_queue();
        _incomingTransfers = [[NSMutableDictionary alloc] init];
        _outgoingTransfers = [[NSMutableDictionary alloc] init];
        [otrKit registerTLVHandler:self];
    }
    return self;
}

- (void) handleIncomingRequestData:(NSData *)requestData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag {
    dispatch_async(self.internalQueue, ^{
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
            NSLog(@"Unrecognized URL scheme %@", url.scheme);
            //[self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Unknown scheme" httpBody:nil tag:tag];
            //return;
            // Using alternate schemes doesn't appear to work at the moment
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
            NSString *fileNameString = [request valueForHTTPHeaderField:@"File-Name"];
            OTRDataIncomingTransfer *transfer = [[OTRDataIncomingTransfer alloc] initWithRequestID:requestID fileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag];
            transfer.mimeType = mimeTypeString;
            transfer.fileName = fileNameString;
            transfer.fileHash = fileHashString;
            [self.incomingTransfers setObject:transfer forKey:requestID];
            // notify delegate of new offered transfer
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self offeredTransfer:transfer];
            });
        } else if ([requestMethod isEqualToString:@"GET"]) {
            NSLog(@"Get");
            OTRDataOutgoingTransfer *transfer = [self.outgoingTransfers objectForKey:requestID];
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
            
            NSString *startRangeString = [startEndRanges firstObject];
            NSString *endRangeString = [startEndRanges lastObject];
            NSUInteger startOfRange = [startRangeString integerValue];
            NSUInteger endOfRange = [endRangeString integerValue];
            NSUInteger chunkLength = endOfRange - startOfRange;
            
            if (chunkLength > kOTRDataMaxChunkLength || startOfRange > endOfRange) {
                [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"Invalid Range" httpBody:nil tag:tag];
                return;
            }
            NSRange range = NSMakeRange(startOfRange, endOfRange - startOfRange);
            NSData *subdata = [transfer.fileData subdataWithRange:range];
            float percentageComplete = (float)endOfRange / (float)transfer.fileData.length;
            
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self transfer:transfer progress:percentageComplete];
            });
            
            if (percentageComplete > 0.98f) {
                dispatch_async(self.callbackQueue, ^{
                    [self.delegate dataHandler:self transferComplete:transfer];
                });
            }
            
            [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:200 httpStatusString:@"OK" httpBody:subdata tag:tag];
        }
    });
}

- (void) handleIncomingResponseData:(NSData *)responseData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag {
    dispatch_async(self.internalQueue, ^{
        OTRHTTPMessage *incomingResponse = [[OTRHTTPMessage alloc] initEmptyRequest];
        [incomingResponse appendData:responseData];
        NSError *error = nil;
        if (incomingResponse.isHeaderComplete) {
            NSLog(@"handleIncomingResponseData: %@", incomingResponse);
        } else {
            error = [NSError errorWithDomain:kOTRDataErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"Message has incomplete headers"}];
            return;
        }
        NSString *requestID = [incomingResponse valueForHTTPHeaderField:@"Request-Id"];
        
        if (!requestID) {
            return;
        }
        
        OTRDataIncomingTransfer *transfer = [self.incomingTransfers objectForKey:requestID];
        if (!transfer) {
            return;
        }
        [transfer.fileData appendData:incomingResponse.HTTPBody];
        if (transfer.fileData.length == transfer.fileLength) {
            NSData *fileHash = [transfer.fileData otr_SHA1];
            NSString *fileHashString = [fileHash otr_hexString];
            if ([transfer.fileHash isEqualToString:fileHashString]) {
                dispatch_async(self.callbackQueue, ^{
                    [self.delegate dataHandler:self transferComplete:transfer];
                });
            } else {
                dispatch_async(self.callbackQueue, ^{
                    [self.delegate dataHandler:self transfer:transfer error:[NSError errorWithDomain:kOTRDataErrorDomain code:102 userInfo:@{NSLocalizedDescriptionKey: @"Bad SHA hash"}]];
                });
            }
            
        } else {
            float progress = (float)transfer.fileData.length / (float)transfer.fileLength;
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self transfer:transfer progress:progress];
            });
            [self requestOutstandingDataForIncomingTransfer:transfer];
        }
    });
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
    dispatch_async(self.internalQueue, ^{
        NSUInteger fileLength = fileData.length;
        
        if (fileLength > kOTRDataMaxFileSize) {
            dispatch_async(self.callbackQueue, ^{
                //[self.delegate dataHandler:self errorSendingFile:fileName error:[NSError errorWithDomain:kOTRDataErrorDomain code:101 userInfo:@{NSLocalizedDescriptionKey: @"File too large"}] tag:tag];
            });
            return;
        }
        
        NSString *urlString = [NSString stringWithFormat:@"%@://%@", kOTRDataHandlerURLScheme, fileName];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSString *requestID = [[NSUUID UUID] UUIDString];
        
        NSData *fileHash = [fileData otr_SHA1];
        NSString *fileHashString = [fileHash otr_hexString];
        
        NSDictionary *httpHeaders = @{@"File-Length": @(fileLength).stringValue,
                                      @"File-Hash-SHA1": fileHashString,
                                      @"File-Name": fileName,
                                      @"Request-Id": requestID};
        
        OTRDataOutgoingTransfer *transfer = [[OTRDataOutgoingTransfer alloc] initWithRequestID:requestID fileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag];
        transfer.fileData = fileData;
        [self.outgoingTransfers setObject:transfer forKey:requestID];
        
        [self sendRequestToUsername:username accountName:accountName protocol:protocol url:url httpMethod:@"OFFER" httpHeaders:httpHeaders tag:tag];
    });
}

- (void) sendRequestToUsername:(NSString*)username
                   accountName:(NSString*)accountName
                      protocol:(NSString*)protocol
                           url:(NSURL*)url
                    httpMethod:(NSString*)httpMethod
                   httpHeaders:(NSDictionary*)httpHeaders
                           tag:(id)tag {
    OTRHTTPMessage *message = [[OTRHTTPMessage alloc] initRequestWithMethod:httpMethod url:url version:OTRHTTPVersion1_1];
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [message setValue:obj forHTTPHeaderField:key];
    }];
    NSData *httpData = [message HTTPMessageData];
    OTRTLV *tlv = [[OTRTLV alloc] initWithType:OTRTLVTypeDataRequest data:httpData];
    if (!tlv) {
        NSLog(@"OTRDATA Error: TLV too long!");
        return;
    }
    [self.otrKit encodeMessage:nil tlvs:@[tlv] username:username accountName:accountName protocol:protocol tag:tag];
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
    [self.otrKit encodeMessage:nil tlvs:@[tlv] username:username accountName:accountName protocol:protocol tag:tag];
}

- (void) startIncomingTransfer:(OTRDataIncomingTransfer *)transfer {
    [self requestOutstandingDataForIncomingTransfer:transfer];
}

- (void) requestOutstandingDataForIncomingTransfer:(OTRDataIncomingTransfer*)transfer {
    NSUInteger requestLength = transfer.fileLength - transfer.fileData.length;
    if (requestLength > kOTRDataMaxChunkLength) {
        requestLength = kOTRDataMaxChunkLength;
    }
    
    NSRange range = NSMakeRange(transfer.fileData.length, requestLength);
    NSString *rangeString = [NSString stringWithFormat:@"bytes=%d-%d", (int)range.location, (int)(range.location + range.length)];
    
    NSDictionary *headers = @{@"Range": rangeString,
                              @"Request-Id": transfer.requestID};
    
    [self sendRequestToUsername:transfer.username accountName:transfer.accountName protocol:transfer.protocol url:[NSURL URLWithString:@"/"] httpMethod:@"GET" httpHeaders:headers tag:transfer.tag];
}

#pragma mark OTRTLVDelegate

/**
 *  Process OTRTLV.
 *  @see OTRTLV
 *
 *  @param tlvs        array of OTRTLV objects
 *  @param username The intended recipient of the message
 *  @param accountName Your account name
 *  @param protocol the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void)receiveTLV:(OTRTLV*)tlv
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
               tag:(id)tag {
    if (tlv.type == OTRTLVTypeDataRequest) {
        [self handleIncomingRequestData:tlv.data username:username accountName:accountName protocol:protocol tag:tag];
    } else if (tlv.type == OTRTLVTypeDataResponse) {
        [self handleIncomingResponseData:tlv.data username:username accountName:accountName protocol:protocol tag:tag];
    }
}

- (NSArray*) handledTLVTypes {
    return @[@(OTRTLVTypeDataRequest), @(OTRTLVTypeDataResponse)];
}

@end
