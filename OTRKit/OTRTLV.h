//
//  OTRTLV.h
//  OTRKit
//
//  Created by Christopher Ballinger on 3/19/14.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint16_t, OTRTLVType) {
    /* This is just padding for the encrypted message, and should be ignored. */
    OTRTLVTypePadding = 0x0000,
    /* The sender has thrown away his OTR session keys with you */
    OTRTLVTypeDisconnected =  0x0001,
    /* The message contains a step in the Socialist Millionaires' Protocol. */
    OTRTLVTypeSMP1 =          0x0002,
    OTRTLVTypeSMP2 =          0x0003,
    OTRTLVTypeSMP3 =          0x0004,
    OTRTLVTypeSMP4 =          0x0005,
    OTRTLVTypeSMP_ABORT =     0x0006,
    /* Like OTRL_TLV_SMP1, but there's a question for the buddy at the
         * beginning */
    OTRTLVTypeSMP1Question =  0x0007,
    /* Tell the application the current "extra" symmetric key */
    /* XXX: Document this in the protocol spec:
     * The body of the TLV will begin with a 4-byte indication of what this
     * symmetric key will be used for (file transfer, voice encryption,
     * etc.).  After that, the contents are use-specific (which file, etc.).
     * There are no currently defined uses. */
    OTRTLVTypeSymmetricKey =  0x0008,
    /* For OTRDATA, see
     https://dev.guardianproject.info/projects/gibberbot/wiki/OTRDATA_Specifications */
    OTRTLVTypeDataRequest = 0x0100,
    OTRTLVTypeDataResponse = 0x0101
};

@interface OTRTLV : NSObject

@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly) OTRTLVType type;

/**
 * @param type: TLV type
 * @param data: this data must be of length shorter than UINT16_MAX bytes
 */
- (instancetype) initWithType:(OTRTLVType)type data:(NSData*)data;

/**
 * returns NO if data.length > UINT16_MAX
 */
- (BOOL) isValidLength;

@end
