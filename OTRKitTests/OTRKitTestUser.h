//
//  OTRKitTestUser.h
//  OTRKit
//
//  Created by Christopher Ballinger on 3/6/14.
//
//

#import <Foundation/Foundation.h>
#import "OTRKit.h"

@interface OTRKitTestUser : NSObject <OTRKitDelegate>

@property (nonatomic, strong) NSString *accountName;
@property (nonatomic, strong) NSString *protocol;
@property (nonatomic, strong) OTRKit *otr;

- (void) sendMessage:(NSString*)message recipient:(OTRKitTestUser*)recipient;
- (void) receiveMessage:(NSString*)message sender:(OTRKitTestUser*)sender;



@end
