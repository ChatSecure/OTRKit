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
#import "OTRDataRequest.h"
#import <MobileCoreServices/MobileCoreServices.h>

NSString * const kOTRDataHandlerURLScheme = @"otr-in-band";
static NSString * const kOTRDataErrorDomain = @"org.chatsecure.OTRDataError";

static NSString * const kHTTPHeaderRange = @"Range";
static NSString * const kHTTPHeaderRequestID = @"Request-Id";
static NSString * const kHTTPHeaderFileLength = @"File-Length";
static NSString * const kHTTPHeaderFileHashSHA1 = @"File-Hash-SHA1";
static NSString * const kHTTPHeaderMimeType = @"Mime-Type";
static NSString * const kHTTPHeaderFileName = @"File-Name";

static const NSUInteger kOTRDataMaxChunkLength = 16384;
static const NSUInteger kOTRDataMaxFileSize = 1024*1024*64;
static const NSUInteger kOTRDataMaxOutstandingRequests = 3;

NSString* OTRKitGetMimeTypeForExtension(NSString* extension) {
    NSString* mimeType = @"application/octet-stream";
    extension = [extension lowercaseString];
    if (extension.length) {
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
        if (uti) {
            mimeType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType));
            CFRelease(uti);
        }
    }
    return mimeType;
}


@interface OTRDataHandler()

@property (nonatomic) dispatch_queue_t internalQueue;

/**
 *  OTRDataIncomingTransfer keyed to URL
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *incomingTransfers;

/**
 *  OTRDataOutgoingTransfer keyed to URL
 */
@property (nonatomic, strong, readonly) NSMutableDictionary *outgoingTransfers;

/** OTRDataRequest keyed to Request-Id  */
@property (nonatomic, strong, readonly) NSMutableDictionary *requestCache;

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
        _requestCache = [[NSMutableDictionary alloc] init];
        [otrKit registerTLVHandler:self];
    }
    return self;
}

- (NSURL*)urlForTransfer:(OTRDataTransfer*)transfer {
    NSString *urlString = [NSString stringWithFormat:@"%@:/storage/%@/%@", kOTRDataHandlerURLScheme, transfer.transferId, transfer.fileName];
    NSURL *url = [NSURL URLWithString:urlString];
    return url;
}

- (void) handleIncomingRequestData:(NSData *)requestData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag {
    dispatch_async(self.internalQueue, ^{
        NSError *error = nil;
        OTRHTTPMessage *request = [[OTRHTTPMessage alloc] initEmptyRequest];
        [request appendData:requestData];
        if (!request.isHeaderComplete) {
            error = [NSError errorWithDomain:kOTRDataErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"Message has incomplete headers"}];
            return;
        }
        
        NSString *requestMethod = request.HTTPMethod;
        NSString *requestID = [request valueForHTTPHeaderField:kHTTPHeaderRequestID];
        NSURL *url = request.url;
        
        if ([requestMethod isEqualToString:@"OFFER"]) {
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
            NSString *fileNameString = [request valueForHTTPHeaderField:kHTTPHeaderFileName];
            OTRDataIncomingTransfer *transfer = [[OTRDataIncomingTransfer alloc] initWithFileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag];
            transfer.mimeType = mimeTypeString;
            if (fileNameString) {
                transfer.fileName = fileNameString;
            } else {
                transfer.fileName = [url lastPathComponent];
            }
            transfer.fileHash = fileHashString;
            transfer.offeredURL = url;
            [self.incomingTransfers setObject:transfer forKey:url];
            // notify delegate of new offered transfer
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self offeredTransfer:transfer];
            });
        } else if ([requestMethod isEqualToString:@"GET"]) {
            OTRDataOutgoingTransfer *transfer = [self.outgoingTransfers objectForKey:url];
            
            if (!transfer) {
                [self sendResponseToUsername:username accountName:accountName protocol:protocol requestID:requestID httpStatusCode:400 httpStatusString:@"No such offer made" httpBody:nil tag:tag];
                return;
            }
            
            NSString *rangeHeader = [request valueForHTTPHeaderField:kHTTPHeaderRange];
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
            NSRange range = NSMakeRange(startOfRange, endOfRange - startOfRange + 1);
            NSData *subdata = [transfer.fileData subdataWithRange:range];
            float percentageComplete = (float)endOfRange / (float)transfer.fileData.length;
            
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self transfer:transfer progress:percentageComplete];
            });
            
            if (endOfRange == transfer.fileData.length) {
                [self.outgoingTransfers removeObjectForKey:url];
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
        if (!incomingResponse.isHeaderComplete) {
            error = [NSError errorWithDomain:kOTRDataErrorDomain code:100 userInfo:@{NSLocalizedDescriptionKey: @"Message has incomplete headers"}];
            return;
        }
        NSString *requestID = [incomingResponse valueForHTTPHeaderField:kHTTPHeaderRequestID];
        
        if (!requestID) {
            return;
        }
        
        OTRDataRequest *request = [self.requestCache objectForKey:requestID];
        
        if (!request) {
            return;
        }
        [self.requestCache removeObjectForKey:requestID];
        
        
        OTRDataIncomingTransfer *transfer = [self.incomingTransfers objectForKey:request.url];
        if (!transfer) {
            return;
        }
        NSData *incomingData = incomingResponse.HTTPBody;
        if (incomingData.length) {
            [transfer handleResponse:incomingData forRequest:request];
        }
        if (transfer.receivedBytes == transfer.fileLength) {
            [self.incomingTransfers removeObjectForKey:request.url];
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
            float progress = (float)transfer.receivedBytes / (float)transfer.fileLength;
            dispatch_async(self.callbackQueue, ^{
                [self.delegate dataHandler:self transfer:transfer progress:progress];
            });
            [self processOutstandingRequestsForIncomingTransfer:transfer];
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
        
        NSString *requestID = [[NSUUID UUID] UUIDString];
        
        NSData *fileHash = [fileData otr_SHA1];
        NSString *fileHashString = [fileHash otr_hexString];
        NSString *fileExtension = [fileName pathExtension];
        NSString *mimeType = OTRKitGetMimeTypeForExtension(fileExtension);
        
        NSDictionary *httpHeaders = @{kHTTPHeaderFileLength: @(fileLength).stringValue,
                                      kHTTPHeaderFileHashSHA1: fileHashString,
                                      kHTTPHeaderFileName: fileName,
                                      kHTTPHeaderRequestID: requestID,
                                      kHTTPHeaderMimeType: mimeType};
        
        OTRDataOutgoingTransfer *transfer = [[OTRDataOutgoingTransfer alloc] initWithFileLength:fileLength username:username accountName:accountName protocol:protocol tag:tag];
        transfer.fileData = fileData;
        transfer.fileName = fileName;
        transfer.fileHash = fileHashString;
        transfer.mimeType = mimeType;
        
        NSURL *url = [self urlForTransfer:transfer];
        
        [self.outgoingTransfers setObject:transfer forKey:url];
        
        OTRDataRequest *request = [[OTRDataRequest alloc] initWithRequestId:requestID url:url httpMethod:@"OFFER" httpHeaders:httpHeaders];
        [self.requestCache setObject:request forKey:requestID];
        [self sendRequest:request username:username accountName:accountName protocol:protocol tag:tag];
    });
}

- (void) sendRequest:(OTRDataRequest*)request
            username:(NSString*)username
         accountName:(NSString*)accountName
            protocol:(NSString*)protocol
                 tag:(id)tag {
    NSString *httpMethod = request.httpMethod;
    NSURL *url = request.url;
    NSDictionary *httpHeaders = request.httpHeaders;
    OTRHTTPMessage *message = [[OTRHTTPMessage alloc] initRequestWithMethod:httpMethod url:url version:OTRHTTPVersion1_1];
    [httpHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [message setValue:obj forHTTPHeaderField:key];
    }];
    NSData *httpData = [message HTTPMessageData];
    OTRTLV *tlv = [[OTRTLV alloc] initWithType:OTRTLVTypeDataRequest data:httpData];
    if (!tlv) {
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
        return;
    }
    [self.otrKit encodeMessage:nil tlvs:@[tlv] username:username accountName:accountName protocol:protocol tag:tag];
}

- (void) startIncomingTransfer:(OTRDataIncomingTransfer *)transfer {
    [self processOutstandingRequestsForIncomingTransfer:transfer];
}

- (void) processOutstandingRequestsForIncomingTransfer:(OTRDataIncomingTransfer*)transfer {
    NSUInteger requestLength = transfer.fileLength - transfer.receivedBytes;
    if (requestLength > kOTRDataMaxChunkLength) {
        requestLength = kOTRDataMaxChunkLength;
    }
    NSRange range = NSMakeRange(transfer.receivedBytes, requestLength);
    
    NSString *rangeString = [NSString stringWithFormat:@"bytes=%d-%d", (int)range.location, (int)(range.location + range.length - 1)];
    
    NSString *requestId = [[NSUUID UUID] UUIDString];
    
    NSDictionary *headers = @{kHTTPHeaderRange: rangeString,
                              kHTTPHeaderRequestID: requestId};
    
    OTRDataRequest *request = [[OTRDataRequest alloc] initWithRequestId:requestId url:transfer.offeredURL httpMethod:@"GET" httpHeaders:headers];
    request.range = range;
    
    [self.requestCache setObject:request forKey:requestId];
    [self sendRequest:request username:transfer.username accountName:transfer.accountName protocol:transfer.protocol tag:transfer.tag];
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
