//
//  OTRDataIncomingTransfer.h
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import "OTRDataTransfer.h"

@interface OTRDataIncomingTransfer : OTRDataTransfer

@property (nonatomic, strong) NSURL *offeredURL;

/**
 *  This property is not thread-safe. Do not read it until dataHandler:transferComplete: is called.
 */
@property (nonatomic, strong) NSMutableData *fileData;

@end
