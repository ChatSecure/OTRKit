//
//  OTRDataIncomingTransfer.h
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataTransfer.h"

@interface OTRDataIncomingTransfer : OTRDataTransfer

@property (nonatomic, readonly) NSUInteger totalChunks;

@property (nonatomic) NSUInteger chunksReceived;

@property (nonatomic) NSUInteger currentChunk;

@property (nonatomic, strong) NSMutableData *fileData;

@end
