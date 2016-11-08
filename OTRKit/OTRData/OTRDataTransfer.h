//
//  OTRDataTransfer.h
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OTRDataTransfer : NSObject

/** Unique UUID string */
@property (nonatomic, strong, readonly) NSString *transferId;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *accountName;
@property (nonatomic, strong, readonly) NSString *protocol;
@property (nonatomic, strong, readonly, nullable) id tag;

@property (nonatomic, strong, nullable) NSString *fileName;
@property (nonatomic, strong, nullable) NSData *fileData;
@property (nonatomic, strong, nullable) NSString *mimeType;

/** SHA-1 for now */
@property (nonatomic, strong, nullable) NSString *fileHash;

/**
 *  Total file length in bytes
 */
@property (nonatomic, readonly) NSUInteger fileLength;

/**
 * Total number of bytes transferred
 */
@property (nonatomic, readwrite) NSUInteger bytesTransferred;

- (instancetype) initWithFileLength:(NSUInteger)fileLength
                           username:(NSString*)username
                        accountName:(NSString*)accountName
                           protocol:(NSString*)protocol
                                tag:(nullable id)tag;

@end
NS_ASSUME_NONNULL_END
