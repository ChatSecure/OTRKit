//
//  OTRCryptoUtility.h
//  Pods
//
//  Created by David Chiles on 10/3/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OTRCryptoUtility : NSObject

/**
 Encrypt data with key and IV using AES-128-GCM
 
 @param data The data to be encrypted.
 @param iv The initialization vector. Must be 16 bytes in length.
 @param key The symmetric key. Must be 16 bytes in length.
 @param error Any errors that result.
 
 @return The encrypted data.
 */
+ (nullable NSData *)encryptAESGCMData:(NSData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError **)error;

/**
 Decrypt data with key and IV using AES-128-GCM
 
 @param data The data to be decrypted.
 @param iv The initialization vector. Must be 16 bytes in length.
 @param key The symmetric key. Must be 16 bytes in length.
 @param error Any errors that result.
 
 @return The decrypted data.
 */
+ (nullable NSData *)decryptAESGCMData:(NSData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
