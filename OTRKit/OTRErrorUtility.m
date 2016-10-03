//
//  OTRErrorUtility.m
//  Pods
//
//  Created by David Chiles on 10/3/16.
//
//

#import "OTRErrorUtility.h"
#import "gcrypt.h"

NSString * const kOTRKitErrorDomain       = @"org.chatsecure.OTRKit";

@implementation OTRErrorUtility

+ (NSError*) errorForGPGError:(unsigned int)gpg_error {
    if (gpg_error == gcry_err_code(GPG_ERR_NO_ERROR)) {
        return nil;
    }
    const char *gpg_error_string = gcry_strerror(gpg_error);
    const char *gpg_error_source = gcry_strsource(gpg_error);
    gpg_err_code_t gpg_error_code = gcry_err_code(gpg_error);
    int errorCode = gcry_err_code_to_errno(gpg_error_code);
    NSString *errorString = nil;
    NSString *errorSource = nil;
    if (gpg_error_string) {
        errorString = [NSString stringWithUTF8String:gpg_error_string];
    }
    if (gpg_error_source) {
        errorSource = [NSString stringWithUTF8String:gpg_error_source];
    }
    NSMutableString *errorDescription = [NSMutableString string];
    if (errorString) {
        [errorDescription appendString:errorString];
    }
    if (errorSource) {
        [errorDescription appendString:errorSource];
    }
    NSError *error = [NSError errorWithDomain:kOTRKitErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorDescription}];
    return error;
}

@end
