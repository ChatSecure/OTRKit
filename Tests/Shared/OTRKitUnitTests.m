//
//  OTRKitUnitTests.m
//  OTRKit
//
//  Created by Christopher Ballinger on 1/15/15.
//
//

#import <XCTest/XCTest.h>
@import OTRKit;

@interface OTRKitUnitTests : XCTestCase <OTRKitDelegate>
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
    self.otrKit = [[OTRKit alloc] initWithDelegate:self dataPath:path];
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


- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ send message: %d %@->%@ tag: %@", otrKit, [OTRKit stringStartsWithOTRPrefix:message], accountName, username, tag);
    NSLog(@"%@ receive message: %d %@->%@ tag: %@", otrKit, [OTRKit stringStartsWithOTRPrefix:message], username, accountName, tag);
}

- (void) otrKit:(OTRKit*)otrKit
 encodedMessage:(NSString*)encodedMessage
   wasEncrypted:(BOOL)wasEncrypted
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag
          error:(nullable NSError*)error {
    XCTAssertNotNil(otrKit);
    if (!wasEncrypted) {
        NSLog(@"%@ encodedMessage: %@ %@->%@ tag: %@", otrKit, encodedMessage, accountName, username, tag);
    } else {
        NSLog(@"%@ encodedMessage: <ciphertext> %@->%@ tag: %@", otrKit, accountName, username, tag);
    }
}


- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(nullable NSString*)decodedMessage
   wasEncrypted:(BOOL)wasEncrypted
           tlvs:(NSArray<OTRTLV*>*)tlvs
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ decodedMessage(%d): %@ username: %@ accountName: %@ tag: %@", otrKit, wasEncrypted, decodedMessage, username, accountName, tag);
}

/**
 *  When the encryption status changes this method is called
 *
 *  @param otrKit      reference to shared instance
 *  @param messageState plaintext, encrypted or finished
 *  @param username     buddy whose state has changed
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 */
- (void)    otrKit:(OTRKit*)otrKit
updateMessageState:(OTRKitMessageState)messageState
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
       fingerprint:(OTRFingerprint*)fingerprint
{
    XCTAssertNotNil(otrKit);
    XCTAssertNotNil(username);
    XCTAssertNotNil(accountName);
    XCTAssertNotNil(protocol);
    XCTAssertNotNil(fingerprint);
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
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

/**
 *  Show a dialog here so the user can confirm when a user's fingerprint changes.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param username    buddy whose fingerprint has changed
 *  @param theirHash   buddy's fingerprint
 *  @param ourHash     our fingerprint
 */
- (void)                           otrKit:(OTRKit*)otrKit
  showFingerprintConfirmationForTheirHash:(NSString*)theirHash
                                  ourHash:(NSString*)ourHash
                                 username:(NSString*)username
                              accountName:(NSString*)accountName
                                 protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
}

/**
 *  Implement this if you plan to handle SMP.
 *
 *  @param otrKit      reference to shared instance
 *  @param event    SMP event
 *  @param progress percent progress of SMP negotiation
 *  @param question question that should be displayed to user
 */
- (void) otrKit:(OTRKit*)otrKit
 handleSMPEvent:(OTRKitSMPEvent)event
       progress:(double)progress
       question:(NSString*)question
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
}

/**
 *  Implement this delegate method to handle message events.
 *
 *  @param otrKit      reference to shared instance
 *  @param event   message event
 *  @param message offending message
 *  @param error   error describing the problem
 */
- (void)    otrKit:(OTRKit*)otrKit
handleMessageEvent:(OTRKitMessageEvent)event
           message:(NSString*)message
          username:(NSString*)username
       accountName:(NSString*)accountName
          protocol:(NSString*)protocol
               tag:(id)tag
             error:(NSError*)error {
    XCTAssertNotNil(otrKit);
    XCTAssertNil(error);
    if (error) {
        NSLog(@"handleMessageEvent error: %@", error);
    }
    NSLog(@"handleMessageEvent %d", (int)event);
}

/**
 *  When another buddy requests a shared symmetric key this will be called.
 *
 *  @param otrKit      reference to shared instance
 *  @param symmetricKey key data
 *  @param use          integer tag for identifying the use for the key
 *  @param useData      any extra data to attach
 */
- (void)        otrKit:(OTRKit*)otrKit
  receivedSymmetricKey:(NSData*)symmetricKey
                forUse:(NSUInteger)use
               useData:(NSData*)useData
              username:(NSString*)username
           accountName:(NSString*)accountName
              protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
}

/**
 *  Called when starting to generate a private key, may take a while.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 */
- (void)                             otrKit:(OTRKit *)otrKit
willStartGeneratingPrivateKeyForAccountName:(NSString*)accountName
                                   protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    NSLog(@"willStartGeneratingPrivateKeyForAccountName: %@", accountName);
}

/**
 *  Called when key generation has finished, canceled, or there was an error.
 *
 *  @param otrKit      reference to shared instance
 *  @param accountName your account name
 *  @param protocol    the protocol of accountName, such as @"xmpp"
 *  @param error       any error that may have occurred
 */
- (void)                             otrKit:(OTRKit *)otrKit
didFinishGeneratingPrivateKeyForAccountName:(NSString*)accountName
                                   protocol:(NSString*)protocol
                                      error:(NSError*)error {
    XCTAssertNotNil(otrKit);
    XCTAssertNil(error);
    NSLog(@"didFinishGeneratingPrivateKeyForAccountName: %@", accountName);
}

@end
