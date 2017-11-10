//
//  OTRCryptoUtility.m
//  Pods
//
//  Created by David Chiles on 10/3/16.
//
//

#import "OTRCryptoUtility.h"
#import "OTRErrorUtility.h"
#import "gcrypt.h"

typedef NS_ENUM(NSUInteger, OTRCryptoMode) {
    OTRCryptoModeEncrypt,
    OTRCryptoModeDecrypt
};

@interface OTRCryptoData()
/** Encrypted data */
@property (nonatomic, readwrite, strong) NSData *data;
/** GCM auth tags should be 16 bytes */
@property (nonatomic, readwrite, strong) NSData *authTag;
@end

@implementation OTRCryptoData

+ (void) initialize {
    // This is needed to suppress the initialization warning
    gcry_check_version(NULL);
}

- (instancetype) init {
    NSAssert(NO, @"Use designated initializer");
    return nil;
}

- (instancetype) initWithData:(NSData*)data
                      authTag:(NSData*)authTag {
    NSParameterAssert(data);
    NSParameterAssert(authTag);
    if (self = [super init]) {
        _data = data;
        _authTag = authTag;
    }
    return self;
}

#pragma mark NSCopying

- (instancetype)copyWithZone:(nullable NSZone *)zone {
    OTRCryptoData *data = [[[self class] alloc] initWithData:[self.data copy] authTag:[self.authTag copy]];
    return data;
}

@end

@implementation OTRCryptoUtility

+ (nullable OTRCryptoData *)encryptAESGCMData:(NSData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError * __autoreleasing *)error {
    /** Encrypt in place */
    OTRCryptoData *cryptoData = [[OTRCryptoData alloc] initWithData:data authTag:[NSData data]];
    BOOL success = [self processCryptoData:cryptoData mode:OTRCryptoModeEncrypt key:key iv:iv error:error];
    if (success) {
        return cryptoData;
    }
    return nil;
}

+ (nullable NSData *)decryptAESGCMData:(OTRCryptoData *)data key:(NSData *)key iv:(NSData *)iv error:(NSError * __autoreleasing *)error {
    OTRCryptoData *outData = [data copy];
    BOOL success = [self processCryptoData:outData mode:OTRCryptoModeDecrypt key:key iv:iv error:error];
    if (success) {
        return outData.data;
    }
    return nil;
}

/** Returns YES on success, NO on failure */
+ (BOOL)processCryptoData:(OTRCryptoData*)cryptoData mode:(OTRCryptoMode)mode key:(NSData *)key iv:(NSData *)iv error:(NSError * __autoreleasing *)error {
    NSParameterAssert(cryptoData);
    //NSParameterAssert(cryptoData.data.length != 0);
    NSParameterAssert(key.length == 16 || key.length == 32);
    NSParameterAssert(iv.length == 16);
    
    if ([key length] == 0 || [iv length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:kOTRKitErrorDomain code:8 userInfo:@{NSLocalizedDescriptionKey:@"All parameters need to be non-nil and have a length"}];
        }
        return NO;
    }
    
    gcry_cipher_hd_t handle = NULL;
    int algo = GCRY_CIPHER_AES128;
    if (key.length == 32) {
        algo = GCRY_CIPHER_AES256;
    }
    gcry_error_t err = gcry_cipher_open(&handle,algo,GCRY_CIPHER_MODE_GCM,GCRY_CIPHER_SECURE);
    
    void (^errorHandleBlock)(gcry_cipher_hd_t, gcry_error_t) = ^void(gcry_cipher_hd_t handle, gcry_error_t err) {
        if (error) {
            *error = [OTRErrorUtility errorForGPGError:err];
        }
        gcry_cipher_close(handle);
        handle = NULL;
    };
    
    if (err != GPG_ERR_NO_ERROR) {
        errorHandleBlock(handle,err);
        return NO;
    }
    
    err = gcry_cipher_setkey(handle,key.bytes,key.length);
    if (err != GPG_ERR_NO_ERROR) {
        errorHandleBlock(handle,err);
        return NO;
    }
    
    err = gcry_cipher_setiv(handle,iv.bytes,iv.length);
    if (err != GPG_ERR_NO_ERROR) {
        errorHandleBlock(handle,err);
        return NO;
    }
    
    NSMutableData *outData = [cryptoData.data mutableCopy];
    if (mode == OTRCryptoModeEncrypt) {
        err = gcry_cipher_encrypt(handle, outData.mutableBytes, outData.length, NULL, 0);
        if (err != GPG_ERR_NO_ERROR){
            errorHandleBlock(handle,err);
            return NO;
        }
        NSMutableData *tag = [NSMutableData dataWithLength:GCRY_GCM_BLOCK_LEN];
        err = gcry_cipher_gettag(handle, tag.mutableBytes, tag.length);
        if (err != GPG_ERR_NO_ERROR){
            errorHandleBlock(handle,err);
            return NO;
        }
        cryptoData.authTag = tag;
    } else if(mode == OTRCryptoModeDecrypt) {
         err = gcry_cipher_decrypt(handle, outData.mutableBytes, outData.length, NULL, 0);
        if (err != GPG_ERR_NO_ERROR){
            errorHandleBlock(handle,err);
            return NO;
        }
        err = gcry_cipher_checktag(handle, cryptoData.authTag.bytes, cryptoData.authTag.length);
    } else {
        errorHandleBlock(handle,GPG_ERR_GENERAL);
        return NO;
    }
    
    if (err != GPG_ERR_NO_ERROR) {
        errorHandleBlock(handle,err);
        return NO;
    }
    gcry_cipher_close(handle);
    cryptoData.data = outData;
    return YES;
}

@end
