//
//  OTRCryptoUtility.h
//  Pods
//
//  Created by David Chiles on 10/3/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface OTRCryptoData : NSObject <NSCopying>

/** Encrypted data */
@property (nonatomic, readonly, strong) NSData *data;
/** GCM auth tags should be 16 bytes */
@property (nonatomic, readonly, strong) NSData *authTag;

/** Data to be decrypted. Auth tag is required for GCM mode. */
- (instancetype) initWithData:(NSData*)data
                      authTag:(NSData*)authTag NS_DESIGNATED_INITIALIZER;

/** Not available, use designated initializer */
- (instancetype) init NS_UNAVAILABLE;

@end
NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN
/** Lightweight wrapper around some libgcrypt functions */
@interface OTRCryptoUtility : NSObject

/**
 Encrypt data with key and IV using AES-128-GCM or AES-256-GCM.
 
 @param data The data to be encrypted.
 @param iv The initialization vector. Must be 16 bytes in length.
 @param key The symmetric key. Must be 16 or 32 bytes in length.
 @param error Any errors that result.
 
 @return The encrypted data.
 */
+ (nullable OTRCryptoData *)encryptAESGCMData:(NSData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError * __autoreleasing *)error;

/**
 Decrypt data with key and IV using AES-128-GCM or AES-256-GCM.
 
 @param data The data to be decrypted.
 @param iv The initialization vector. Must be 16 bytes in length.
 @param key The symmetric key. Must be 16 or 32 bytes in length.
 @param error Any errors that result.
 
 @return The decrypted data.
 */
+ (nullable NSData *)decryptAESGCMData:(OTRCryptoData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError * __autoreleasing *)error;

@end
NS_ASSUME_NONNULL_END
