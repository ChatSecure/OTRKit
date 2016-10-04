//
//  OTRUtilityTests.m
//  OTRKit
//
//  Created by David Chiles on 10/3/16.
//
//

#import <XCTest/XCTest.h>
@import OTRKit;

@interface OTRUtilityTests : XCTestCase

@end

@implementation OTRUtilityTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)runAESGCMWithPlaintextData:(NSData *)plaintextData {
    
    NSLog(@"PLAINTEXT DATA: %@",plaintextData);
    NSMutableData *keyData = [NSMutableData dataWithLength:16];
    int err = SecRandomCopyBytes(kSecRandomDefault, 16, [keyData mutableBytes]);
    XCTAssert(err == 0);
    NSMutableData *ivData = [NSMutableData dataWithLength:17];
    err = SecRandomCopyBytes(kSecRandomDefault, 17, [ivData mutableBytes]);
    XCTAssert(err == 0);
    
    NSError *error = nil;
    
    NSData *encryptedData = [OTRCryptoUtility encryptAESGCMData:plaintextData key:keyData iv:ivData error:&error];
    NSLog(@"ENCRYPTED: %@",encryptedData);
    XCTAssertNil(error);
    XCTAssertNotNil(encryptedData);
    
    NSData *decryptedData = [OTRCryptoUtility decryptAESGCMData:encryptedData key:keyData iv:ivData error:&error];
    NSLog(@"DECRYPTED: %@",decryptedData);
    XCTAssertNotNil(decryptedData);
    XCTAssertNil(error);
    XCTAssertEqualObjects(decryptedData, plaintextData);
}

- (void)testAESGCMEncryption {
    
    //Test strings of length 1 to 1000
    for (int count = 1; count <= 100; count++) {
        NSMutableData *data = [NSMutableData dataWithLength:count];
        int err = SecRandomCopyBytes(kSecRandomDefault, count, [data mutableBytes]);
        XCTAssert(err == 0);
        [self runAESGCMWithPlaintextData:data];
    }

}

@end
