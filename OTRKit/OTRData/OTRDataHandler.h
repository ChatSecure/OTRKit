//
//  OTRDataHandler.h
//  OTRKit
//
//  Created by Christopher Ballinger on 5/15/14.
//

#import <Foundation/Foundation.h>
#import "OTRDataTransfer.h"
#import "OTRDataOutgoingTransfer.h"
#import "OTRDataIncomingTransfer.h"
#import "OTRTLVHandler.h"

@class OTRKit;
@class OTRDataHandler;

NS_ASSUME_NONNULL_BEGIN
extern  NSString* OTRKitGetMimeTypeForExtension(NSString* extension);
extern  NSString *const kHTTPHeaderRange;
extern  NSString *const kHTTPHeaderRequestID;

@protocol OTRDataHandlerDelegate <NSObject>

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint
              error:(NSError*)error;

- (void)dataHandler:(OTRDataHandler*)dataHandler
    offeredTransfer:(OTRDataIncomingTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint;

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
           progress:(float)progress
        fingerprint:(OTRFingerprint*)fingerprint;

- (void)dataHandler:(OTRDataHandler*)dataHandler
   transferComplete:(OTRDataTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint;

@end

@interface OTRDataHandler : NSObject <OTRTLVHandler>

/**
 *  This reference is needed to inject messages over the network.
 *  @see registerTLVHandler:
 */
@property (nonatomic, weak, readonly) OTRKit *otrKit;

/**
 *  All OTRDataHandlerDelegate callbacks will be done on this queue.
 *  Defaults to main queue.
 */
@property (nonatomic, strong, readwrite, nullable) dispatch_queue_t callbackQueue;

/**
 *  Implement a delegate listener to handle file events.
 */
@property (nonatomic, weak, readonly) id<OTRDataHandlerDelegate> delegate;

/**
 *  This method will automatically register itself with OTRKit via registerTLVHandler:
 */
- (instancetype) initWithOTRKit:(OTRKit*)otrKit delegate:(id<OTRDataHandlerDelegate>)delegate;

- (instancetype) init NS_UNAVAILABLE;

#pragma mark Sending Data

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithURL:(NSURL*)fileURL
                username:(NSString*)username
             accountName:(NSString*)accountName
                protocol:(NSString*)protocol
                     tag:(nullable id)tag;

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithName:(NSString*)fileName
                 fileData:(NSData*)fileData
                 username:(NSString*)username
              accountName:(NSString*)accountName
                 protocol:(NSString*)protocol
                      tag:(nullable id)tag;

/** Used internally for access to directly send a request */
- (void) sendRequest:(OTRDataRequest*)request
            username:(NSString*)username
         accountName:(NSString*)accountName
            protocol:(NSString*)protocol
                 tag:(nullable id)tag;

#pragma mark Receiving Data

/**
 *  Use this to start a transfer offered by the delegate method dataHandler:offeredTransfer:
 *
 *  @param transfer transfer to be started
 */
- (void) startIncomingTransfer:(OTRDataIncomingTransfer*)transfer;

@end

#pragma mark Constants

/** otr-in-band */
extern NSString * const kOTRDataHandlerURLScheme;
NS_ASSUME_NONNULL_END
