//
//  OTRDataHandler.h
//  OTRKit
//
//  Created by Christopher Ballinger on 5/15/14.
//

#import <Foundation/Foundation.h>
#import "OTRDataTransfer.h"

@class OTRKit;
@class OTRDataHandler;

@protocol OTRDataHandlerDelegate <NSObject>

- (void)dataHandler:(OTRDataHandler*)dataHandler
           sendTLVs:(NSArray*)tlvs
           username:(NSString*)username
        accountName:(NSString*)accountName
           protocol:(NSString*)protocol
                tag:(id)tag;

- (void)dataHandler:(OTRDataHandler*)dataHandler
   errorSendingFile:(NSURL*)fileURL
              error:(NSError*)error
                tag:(id)tag;

- (void)dataHandler:(OTRDataHandler*)dataHandler
    offeredTransfer:(OTRDataTransfer*)transfer
                tag:(id)tag;

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
           progress:(float)progress
                tag:(id)tag;

- (void)dataHandler:(OTRDataHandler*)dataHandler
   transferComplete:(OTRDataTransfer*)transfer
                tag:(id)tag;

@end

@interface OTRDataHandler : NSObject

@property (nonatomic, weak, readonly) id<OTRDataHandlerDelegate> delegate;

- (instancetype) initWithDelegate:(id<OTRDataHandlerDelegate>)delegate;

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

- (void)receiveTLVs:(NSArray*)tlvs
           username:(NSString*)username
        accountName:(NSString*)accountName
           protocol:(NSString*)protocol
                tag:(id)tag;

@end
