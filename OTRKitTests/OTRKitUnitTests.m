//
//  OTRKitUnitTests.m
//  OTRKit
//
//  Created by Christopher Ballinger on 1/15/15.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "NSData+OTRDATA.h"

@interface OTRKitUnitTests : XCTestCase

@end

@implementation OTRKitUnitTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSHA1 {
    // da66a67a11e59a717da458d7599028100c191a95
    // test_image.jpg
    NSURL *fileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"test_image" withExtension:@"jpg"];
    XCTAssertNotNil(fileURL);
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    XCTAssertNotNil(fileData);
    NSData *fileSHA1 = [fileData otr_SHA1];
    NSString *fileSHA1String = [fileSHA1 otr_hexString];
    XCTAssertEqualObjects(@"da66a67a11e59a717da458d7599028100c191a95", fileSHA1String);
}

@end
