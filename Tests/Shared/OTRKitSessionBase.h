//
//  OTRKitSessionBase.h
//  OTRKit
//
//  Created by Chris Ballinger on 11/12/16.
//
//

@import XCTest;
@import OTRKit;

NS_ASSUME_NONNULL_BEGIN
extern NSString * const kOTRTestAccountAlice;
extern NSString * const kOTRTestAccountBob;
extern NSString * const kOTRTestProtocolXMPP;

@interface OTRKitSessionBase : XCTestCase <OTRKitDelegate>

@property (nonatomic, strong, readonly) OTRKit *otrKitAlice;
@property (nonatomic, strong, readonly) OTRKit *otrKitBob;

@end
NS_ASSUME_NONNULL_END
