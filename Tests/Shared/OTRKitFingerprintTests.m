//
//  OTRKitFingerprintTests.m
//  OTRKit
//
//  Created by Chris Ballinger on 11/12/16.
//
//

#import "OTRKitSessionBase.h"

@interface OTRKitFingerprintTests : OTRKitSessionBase

// testFingerprintExchange
@property (nonatomic, strong, nullable) XCTestExpectation *fingerprintExchange;
@property (nonatomic, strong, nullable) OTRFingerprint *aliceFingerprint;
@property (nonatomic, strong, nullable) NSArray<OTRFingerprint*> *allAliceFingerprints;
@property (nonatomic, strong, nullable) OTRFingerprint *bobFingerprint;
@property (nonatomic, strong, nullable) NSArray<OTRFingerprint*> *allBobFingerprints;
@end

@implementation OTRKitFingerprintTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitialFingerprintCount {
    NSArray<OTRFingerprint*> *allAliceFingerprints = [self.otrKitAlice allFingerprints];
    NSArray<OTRFingerprint*> *allBobFingerprints = [self.otrKitBob allFingerprints];
    XCTAssertNotNil(allAliceFingerprints);
    XCTAssertNotNil(allBobFingerprints);
    XCTAssert(allAliceFingerprints.count == 0);
    XCTAssert(allBobFingerprints.count == 0);
}

- (void) testFingerprintExchange {
    self.fingerprintExchange = [self expectationWithDescription:@"Fingerprint Exchange"];
    [self.otrKitAlice initiateEncryptionWithUsername:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP];
    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"%@",error);
        }
    }];
}

#pragma mark OTRKitDelegate methods

- (void)    otrKit:(OTRKit*)otrKit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
       fingerprint:(OTRFingerprint*)fingerprint {
    XCTAssertNotNil(otrKit);
    XCTAssertNotNil(username);
    XCTAssertNotNil(accountName);
    XCTAssertNotNil(protocol);
    XCTAssertNotNil(fingerprint);
    NSLog(@"updateMessageState: %@ %@ %@ %@", username, accountName, protocol, fingerprint.fingerprint);
    
    // Testing fingerprint exchange.
    if (self.fingerprintExchange &&
        messageState == OTRKitMessageStateEncrypted) {
        if (otrKit == self.otrKitAlice) {
            self.allAliceFingerprints = [self.otrKitAlice allFingerprints];
            self.aliceFingerprint = [self.otrKitAlice fingerprintForAccountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP];
        }
        if (otrKit == self.otrKitBob) {
            self.allBobFingerprints = [self.otrKitBob allFingerprints];
            self.bobFingerprint = [self.otrKitBob fingerprintForAccountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP];

        }
        if (self.allBobFingerprints && self.allAliceFingerprints) {
            XCTAssert(self.allAliceFingerprints.count == 1);
            XCTAssert(self.allBobFingerprints.count == 1);
            OTRFingerprint *bobsFingerprintForAlice = [self.allBobFingerprints firstObject];
            OTRFingerprint *alicesFingerprintForBob = [self.allAliceFingerprints firstObject];
            XCTAssertEqualObjects(self.aliceFingerprint.fingerprint, bobsFingerprintForAlice.fingerprint);
            XCTAssertEqualObjects(self.bobFingerprint.fingerprint, alicesFingerprintForBob.fingerprint);
            [self.fingerprintExchange fulfill];
            self.fingerprintExchange = nil;
        }
    }
}

@end
