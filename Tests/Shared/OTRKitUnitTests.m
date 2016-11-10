//
//  OTRKitUnitTests.m
//  OTRKit
//
//  Created by Christopher Ballinger on 1/15/15.
//
//

#import <XCTest/XCTest.h>
@import OTRKit;

@interface OTRKitUnitTests : XCTestCase
@property (nonatomic, strong) XCTestExpectation *expectation;
@property (nonatomic, strong) OTRKit *otrKit;
@end

@implementation OTRKitUnitTests

- (void)setUp {
    [super setUp];
    NSString *dirName = [NSUUID UUID].UUIDString;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error);
    self.otrKit = [[OTRKit alloc] initWithDataPath:path];
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
    self.expectation = [self expectationWithDescription:@"Generate Key"];
    NSString *protocol = @"xmpp";
    NSString *account1 = @"alice@dukgo.com";
    NSString *account2 = @"bob@dukgo.com";
    [self.otrKit generatePrivateKeyForAccountName:account1 protocol:protocol completion:^(OTRFingerprint *fingerprint, NSError *error) {
        XCTAssertNotNil(fingerprint);
        NSLog(@"Generated fingerprint for %@: %@", account1, fingerprint);
        OTRFingerprint *fingerprint1 = fingerprint;
        [self.otrKit generatePrivateKeyForAccountName:account1 protocol:protocol completion:^(OTRFingerprint *fingerprint, NSError *error) {
            XCTAssertNotNil(fingerprint);
            XCTAssertEqualObjects(fingerprint.fingerprint, fingerprint1.fingerprint);
            NSLog(@"Generated fingerprint for %@: %@", account1, fingerprint);
            [self.otrKit generatePrivateKeyForAccountName:account2 protocol:protocol completion:^(OTRFingerprint *fingerprint, NSError *error) {
                XCTAssertNotNil(fingerprint);
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
