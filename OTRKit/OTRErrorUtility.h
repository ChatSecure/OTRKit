//
//  OTRErrorUtility.h
//  Pods
//
//  Created by David Chiles on 10/3/16.
//
//

#import <Foundation/Foundation.h>


extern NSString * const kOTRKitErrorDomain;

@interface OTRErrorUtility : NSObject

/**
 An internal error conversion from gcry_error_t to NSError.
 
 @param gpg_error The gcry_error_t to be converted.
 
 @return The correct NSError.
 */
+ (NSError*) errorForGPGError:(unsigned int)gpg_error;

@end
