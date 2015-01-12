//
//  OTRDataTransfer.h
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import <Foundation/Foundation.h>

@interface OTRDataTransfer : NSObject

@property (nonatomic, strong, readonly) NSString *requestID;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *accountName;
@property (nonatomic, strong, readonly) NSString *protocol;
@property (nonatomic, strong, readonly) id tag;

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSData *fileData;
@property (nonatomic, strong) NSString *mimeType;

/** SHA-1 for now */
@property (nonatomic, strong) NSString *fileHash;

/**
 *  Total file length in bytes
 */
@property (nonatomic, readonly) NSUInteger fileLength;

- (instancetype) initWithRequestID:(NSString*)requestID
                       fileLength:(NSUInteger)fileLength
                          username:(NSString*)username
                       accountName:(NSString*)accountName
                          protocol:(NSString*)protocol
                               tag:(id)tag;

@end
