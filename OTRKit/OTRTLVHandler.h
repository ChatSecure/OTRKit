//
//  OTRTLVHandler.h
//  Pods
//
//  Created by Christopher Ballinger on 12/23/14.
//
//

#import <Foundation/Foundation.h>
#import "OTRFingerprint.h"

@class OTRTLV;

NS_ASSUME_NONNULL_BEGIN
@protocol OTRTLVHandler <NSObject>

/**
 *  Process OTRTLV.
 *  @see OTRTLV
 *
 *  @param tlv      OTRTLV object
 *  @param username The intended recipient of the message
 *  @param accountName Your account name
 *  @param protocol the protocol of accountName, such as @"xmpp"
 *  @param tag optional tag to attach additional application-specific data to message.
 */
- (void)receiveTLV:(OTRTLV*)tlv
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
       fingerprint:(OTRFingerprint*)fingerprint
               tag:(nullable id)tag;

/**
 *  Returns array of boxed NSNumbers of OTRTLVType that instance can handle.
 *
 *  @see OTRTLV
 *  @see OTRTLVType
 */
- (NSArray<NSNumber*>*) handledTLVTypes;

@end
NS_ASSUME_NONNULL_END
