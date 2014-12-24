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

@protocol OTRDataHandlerDelegate <NSObject>

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataOutgoingTransfer*)transfer
              error:(NSError*)error;

- (void)dataHandler:(OTRDataHandler*)dataHandler
    offeredTransfer:(OTRDataIncomingTransfer*)transfer;

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
           progress:(float)progress;

- (void)dataHandler:(OTRDataHandler*)dataHandler
   transferComplete:(OTRDataTransfer*)transfer;

@end

@interface OTRDataHandler : NSObject <OTRTLVHandler>

/**
 *  This reference is needed to inject messages over the network.
 *  @see registerTLVHandler:
 */
@property (nonatomic, weak, readwrite) OTRKit *otrKit;

/**
 *  All OTRDataHandlerDelegate callbacks will be done on this queue.
 *  Defaults to main queue.
 */
@property (nonatomic, strong, readwrite) dispatch_queue_t callbackQueue;

/**
 *  Implement a delegate listener to handle file events.
 */
@property (nonatomic, weak, readwrite) id<OTRDataHandlerDelegate> delegate;

/**
 *  This method will automatically register itself with OTRKit via registerTLVHandler:
 */
- (instancetype) initWithOTRKit:(OTRKit*)otrKit delegate:(id<OTRDataHandlerDelegate>)delegate;

#pragma mark Sending Data

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithURL:(NSURL*)fileURL
                username:(NSString*)username
             accountName:(NSString*)accountName
                protocol:(NSString*)protocol
                     tag:(id)tag;

/** For now, this won't work for large files because of RAM limitations */
- (void) sendFileWithName:(NSString*)fileName
                 fileData:(NSData*)fileData
                 username:(NSString*)username
              accountName:(NSString*)accountName
                 protocol:(NSString*)protocol
                      tag:(id)tag;

#pragma mark Receiving Data

- (void) startIncomingTransfer:(OTRDataIncomingTransfer*)transfer;

@end
