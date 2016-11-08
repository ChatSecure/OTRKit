//
//  OTRDataGetOperation.h
//  Pods
//
//  Created by David Chiles on 12/9/15.
//
//

#import <Foundation/Foundation.h>
@class OTRDataRequest;
@class OTRDataHandler;
@class OTRDataIncomingTransfer;

NS_ASSUME_NONNULL_BEGIN
/**
 The `OTRDataGetOperation` class is a small wrapper to control the number of get requests that can be open at one given time.
 There's no real heavy lifting going on here just makes a request and hands it off to the dataHandler. The dataHandler is then
 in charge of keeping track of the operation and marking it as completed when the data is received.
 */
@interface OTRDataGetOperation : NSOperation

/** The dataHandler takes care of doing the heavy lifting of sending off the actual GET request */
@property (nonatomic, weak, readonly) OTRDataHandler *dataHandler;

/** The incomingTransfer is passed through on init and is used in the `start` method for NSOperation */
@property (nonatomic, strong, readonly) OTRDataIncomingTransfer *incomingTransfer;

/** The request is created on the init method from the range and transfer object*/
@property (nonatomic, strong, readonly) OTRDataRequest *request;

- (instancetype)initWithRange:(NSRange)range incomingTransfer:(OTRDataIncomingTransfer *)transfer dataHandler:(OTRDataHandler *)dataHandler;

/** To be called by the dataHandler when the requested data is received*/
- (void)requestCompleted;

@end
NS_ASSUME_NONNULL_END
