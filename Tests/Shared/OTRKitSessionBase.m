//
//  OTRKitSessionBase.m
//  OTRKit
//
//  Created by Chris Ballinger on 11/12/16.
//
//

#import "OTRKitSessionBase.h"

NSString * const kOTRTestAccountAlice = @"alice@example.com";
NSString * const kOTRTestAccountBob = @"bob@example.com";
NSString * const kOTRTestProtocolXMPP = @"xmpp";

@implementation OTRKitSessionBase

- (void)setUp {
    [super setUp];
    NSString *dirName1 = [NSUUID UUID].UUIDString;
    NSString *dirName2 = [NSUUID UUID].UUIDString;
    NSString *path1 = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName1];
    NSString *path2 = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName2];
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:path1 withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error);
    [[NSFileManager defaultManager] createDirectoryAtPath:path2 withIntermediateDirectories:YES attributes:nil error:&error];
    XCTAssertNil(error);
    
    _otrKitAlice = [[OTRKit alloc] initWithDelegate:self dataPath:path1];
    _otrKitBob = [[OTRKit alloc] initWithDelegate:self dataPath:path2];
    XCTAssertNotNil(self.otrKitAlice, "otrKitAlice failed to initialize");
    XCTAssertNotNil(self.otrKitBob, "otrKitBob failed to initialize");
}

- (void)tearDown {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:self.otrKitAlice.dataPath error:&error];
    XCTAssertNil(error);
    [[NSFileManager defaultManager] removeItemAtPath:self.otrKitBob.dataPath error:&error];
    XCTAssertNil(error);
    _otrKitAlice = nil;
    _otrKitBob = nil;
    [super tearDown];
}

#pragma mark OTRKitDelegate methods

- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag {
    XCTAssertNotNil(otrKit);
    XCTAssertNotNil(message);
    XCTAssertNotNil(username);
    XCTAssertNotNil(accountName);
    XCTAssertNotNil(protocol);
    NSLog(@"%@ injectMessage message: %@ %@->%@ tag: %@ fingerprint: %@", otrKit, message, accountName, username, tag, fingerprint.fingerprint);
    if (otrKit == self.otrKitAlice) { // coming from alice's otrkit
        // "send" message to bob's otrkit
        [self.otrKitBob decodeMessage:message username:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP tag:tag async:NO completion:^(NSString * _Nullable decodedMessage, NSArray<OTRTLV *> * _Nonnull tlvs, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
            NSLog(@"%@ Bob decode message: %@ %@->%@ tag: %@ fingerprint: %@", otrKit, message, accountName, username, tag, fingerprint.fingerprint);        }];
    } else if (otrKit == self.otrKitBob) { // coming from bob's otrkit
        // "send" message to bob's otrkit
        [self.otrKitAlice decodeMessage:message username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:tag async:NO completion:^(NSString * _Nullable decodedMessage, NSArray<OTRTLV *> * _Nonnull tlvs, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
            NSLog(@"%@ Alice decode message: %@ %@->%@ tag: %@ fingerprint: %@", otrKit, message, accountName, username, tag, fingerprint.fingerprint);
        }];
    }
}

/**
 *  libotr likes to know if buddies are still "online". This method
 *  is called synchronously on the callback queue so be careful.
 *
 *  @param otrKit      reference to shared instance
 *  @param username   intended recipient of the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *
 *  @return online status of recipient
 */
- (BOOL)       otrKit:(OTRKit*)otrKit
   isUsernameLoggedIn:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    return YES;
}

@end
