//
//  OTRDataTransfer.h
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import <Foundation/Foundation.h>

@interface OTRDataTransfer : NSObject

@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *mimeType;
@property (nonatomic, strong, readonly) NSString *fileHash;

@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *accountName;
@property (nonatomic, strong, readonly) NSString *protocol;

@property (nonatomic, strong) NSData *fileData;
@property (nonatomic, strong) NSString *fileName;

@property (nonatomic, readonly) NSUInteger totalChunks;

@property (nonatomic) NSUInteger chunksReceived;
@property (nonatomic) NSUInteger totalLength;
@property (nonatomic) NSUInteger currentChunk;

- (instancetype) initWithURL:(NSURL*)url
                    mimeType:(NSString*)mimeType
                 totalLength:(NSUInteger)totalLength
                    fileHash:(NSString*)fileHash
                    username:(NSString*)username
                 accountName:(NSString*)accountName
                    protocol:(NSString*)protocol;

@end
