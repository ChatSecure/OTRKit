//
//  OTRKitUnitTests.m
//  OTRKit
//
//  Created by Christopher Ballinger on 1/15/15.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
@import OTRKit;

@interface OTRKitUnitTests : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) OTRKit *otrKit;
@end

@implementation OTRKitUnitTests

- (void)setUp {
    [super setUp];
    self.otrKit = [OTRKit sharedInstance];
    NSString *dirName = [NSUUID UUID].UUIDString;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error);
    [self.otrKit setupWithDataPath:path];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.otrKit.dataPath error:&error];
    XCTAssertNil(error);
    self.otrKit = nil;
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

- (void) testGenerateKey {
    OTRKit *otrKit = [OTRKit sharedInstance];
    self.expectation = [self expectationWithDescription:@"Generate Key"];
    NSString *protocol = @"xmpp";
    NSString *account1 = @"alice@dukgo.com";
    NSString *account2 = @"bob@dukgo.com";
    __block NSString *fingerprint1 = nil;
    [otrKit generatePrivateKeyForAccountName:account1 protocol:protocol completion:^(NSString *fingerprint, NSError *error) {
        XCTAssert(fingerprint.length > 0);
        NSLog(@"Generated fingerprint for %@: %@", account1, fingerprint);
        fingerprint1 = fingerprint;
        [otrKit generatePrivateKeyForAccountName:account1 protocol:protocol completion:^(NSString *fingerprint, NSError *error) {
            XCTAssert(fingerprint.length > 0);
            XCTAssertEqualObjects(fingerprint, fingerprint1);
            NSLog(@"Generated fingerprint for %@: %@", account1, fingerprint);
            [otrKit generatePrivateKeyForAccountName:account2 protocol:protocol completion:^(NSString *fingerprint, NSError *error) {
                XCTAssert(fingerprint.length > 0);
                NSLog(@"Generated fingerprint for %@: %@", account2, fingerprint);
                [self.expectation fulfill];
            }];
        }];
    }];
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: %@", error);
        }
    }];
}

@end
