//
//  OTRKitTestsiOS.m
//  OTRKitTestsiOS
//
//  Created by Christopher Ballinger on 7/21/14.
//
//

#import <XCTest/XCTest.h>
#import "OTRKit.h"

@interface OTRKitTestsiOS : XCTestCase

@end

@implementation OTRKitTestsiOS

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitialization
{
    OTRKit *otrKit = [OTRKit sharedInstance];
    [otrKit setupWithDataPath:nil];
    XCTAssertNotNil(otrKit, "otrKit failed to initialize");
}

@end
