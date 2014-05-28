//
//  OTRDataTransfer.h
//  ServerlessDemo
//
//  Created by Christopher Ballinger on 5/27/14.
//
//

#import <Foundation/Foundation.h>

@interface OTRDataTransfer : NSObject

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *fileHash;
@property (nonatomic) NSUInteger totalChunks;
@property (nonatomic) NSUInteger chunksReceived;

@property (nonatomic) NSUInteger totalLength;
@property (nonatomic) NSUInteger currentChunk;

@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *accountName;
@property (nonatomic, strong) NSString *protocol;

- (instancetype) initWithURL:(NSURL*)url
                    mimeType:(NSString*)mimeType
                 totalLength:(NSUInteger)totalLength
                    fileHash:(NSString*)fileHash
                    username:(NSString*)username
                 accountName:(NSString*)accountName
                    protocol:(NSString*)protocol;

@end
