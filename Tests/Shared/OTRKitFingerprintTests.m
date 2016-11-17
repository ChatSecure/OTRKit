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
    [self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
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
    if (messageState == OTRKitMessageStateEncrypted) {
        XCTAssertNotNil(fingerprint);
    }
    
    NSLog(@"updateMessageState: %@ %@ %@ %@", username, accountName, protocol, fingerprint.fingerprint);
    
    // Testing fingerprint exchange.
    if (self.fingerprintExchange &&
        messageState == OTRKitMessageStateEncrypted) {
        XCTAssertEqual(fingerprint.trustLevel, OTRTrustLevelTrustedTofu,@"This should be a trust on first use");
        
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
            
            //Change fingerprint status to untrusted
            bobsFingerprintForAlice.trustLevel = OTRTrustLevelUntrustedUser;
            [self.otrKitBob saveFingerprint:bobsFingerprintForAlice];
            OTRFingerprint* fetchedBobsFingerprintForAlice = [[self.otrKitBob allFingerprints] firstObject];
            //Make sure we successfully changed the fingerprint trust level.
            XCTAssertTrue([bobsFingerprintForAlice isEqualToFingerprint:fetchedBobsFingerprintForAlice]);
            
            if (otrKit == self.otrKitBob) {
                [otrKit encodeMessage:@"fake message" tlvs:nil username:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP tag:nil async:NO completion:^(NSString * _Nullable encodedMessage, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
                    XCTAssertEqual(32872, error.code);
                    XCTAssertNotNil(error);
                    XCTAssertNil(encodedMessage);
                }];
            }
            
            [self.otrKitBob disableEncryptionWithUsername:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP];
        }
    } else if (self.fingerprintExchange && messageState == OTRKitMessageStatePlaintext) {
        OTRFingerprint *bobsFingerprintForAlice = [self.allBobFingerprints firstObject];
        
        //Change fingerprint status
        bobsFingerprintForAlice.trustLevel = OTRTrustLevelTrustedUser;
        [self.otrKitBob saveFingerprint:bobsFingerprintForAlice];
        OTRFingerprint* fetchedBobsFingerprintForAlice = [[self.otrKitBob allFingerprints] firstObject];
        //Make sure we successfully changed the fingerprint trust level.
        XCTAssertTrue([bobsFingerprintForAlice isEqualToFingerprint:fetchedBobsFingerprintForAlice]);
        
        NSError *error = nil;
        [self.otrKitBob deleteFingerprint:fetchedBobsFingerprintForAlice error:&error];
        XCTAssertNil(error);
        XCTAssertEqual([self.otrKitBob allFingerprints].count, 0);
        
        [self.fingerprintExchange fulfill];
        self.fingerprintExchange = nil;
    }
}

@end
