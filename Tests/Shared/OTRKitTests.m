//
//  OTRKitTestsiOS.m
//  OTRKitTestsiOS
//
//  Created by Christopher Ballinger on 7/21/14.
//
//

#import "OTRKitSessionBase.h"

static NSString * const kOTRTestMessage = @"Hello World";

@interface OTRKitTestsiOS : OTRKitSessionBase <OTRDataHandlerDelegate>

@property (nonatomic, strong) OTRDataHandler *dataHandlerAlice;
@property (nonatomic, strong) OTRDataHandler *dataHandlerBob;
@property (nonatomic, strong) NSData *testFileData;


@property (nonatomic, strong) XCTestExpectation *aliceExp;
@property (nonatomic, strong) XCTestExpectation *aliceDecodedExp;
@property (nonatomic, strong) XCTestExpectation *aliceSessionEnd;
@property (nonatomic, strong) XCTestExpectation *bobExp;
@property (nonatomic, strong) XCTestExpectation *bobDecodedExp;
@property (nonatomic, strong) XCTestExpectation *bobSessionEnd;

@property (nonatomic, strong) XCTestExpectation *fileTransferExp;

@property (nonatomic, strong) XCTestExpectation *tofuExp;

@end

@implementation OTRKitTestsiOS

- (void)setUp
{
    [super setUp];
    
    self.dataHandlerAlice = [[OTRDataHandler alloc] initWithOTRKit:self.otrKitAlice delegate:self];
    self.dataHandlerBob = [[OTRDataHandler alloc] initWithOTRKit:self.otrKitBob delegate:self];

}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMessaging
{
    self.aliceExp = [self expectationWithDescription:@"testMessaging alice"];
    self.bobExp = [self expectationWithDescription:@"testMessaging bob"];
    self.tofuExp = [self expectationWithDescription:@"tofu test"];
    self.bobDecodedExp = [self expectationWithDescription:@"bob decoded"];
    self.aliceDecodedExp = [self expectationWithDescription:@"alice decoded"];
    self.aliceSessionEnd = [self expectationWithDescription:@"alice session ended"];
    self.bobSessionEnd = [self expectationWithDescription:@"bob session ended"];
    
    self.fileTransferExp = [self expectationWithDescription:@"File transfer ended"];

    [self.otrKitAlice initiateEncryptionWithUsername:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP];

    [self waitForExpectationsWithTimeout:10 handler:^(NSError *error) {
        if (error) {
            NSLog(@"failed waitForExpectationsWithTimeout: %@", error);
        }
    }];
}

#pragma mark OTRKitDelegate



- (void) otrKit:(OTRKit*)otrKit
 encodedMessage:(nullable NSString*)encodedMessage
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
    
    if (fingerprint.trustLevel == OTRTrustLevelTrustedTofu) {
        if (self.tofuExp) {
            [self.tofuExp fulfill];
            self.tofuExp = nil;
        }
    }
    
    if (otrKit == self.otrKitAlice) { // coming from alice's otrkit
        // "send" message to bob's otrkit
        [self.otrKitBob decodeMessage:encodedMessage username:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP tag:tag];
    } else if (otrKit == self.otrKitBob) { // coming from bob's otrkit
        // "send" message to bob's otrkit
        [self.otrKitAlice decodeMessage:encodedMessage username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:tag];
    }
}


- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(nullable NSString*)decodedMessage
           tlvs:(NSArray<OTRTLV*>*)tlvs
   wasEncrypted:(BOOL)wasEncrypted
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag
          error:(nullable NSError *)error{
    XCTAssertNotNil(otrKit);
    if (error) {
        NSLog(@"%@ decodedMessageError(%d): %@ username: %@ accountName: %@ tag: %@ %@", otrKit, wasEncrypted, decodedMessage, username, accountName, tag, error);
    } else {
        NSLog(@"%@ decodedMessage(%d): %@ username: %@ accountName: %@ tag: %@", otrKit, wasEncrypted, decodedMessage, username, accountName, tag);
    }
    if (otrKit == self.otrKitAlice) {
        // decoded message from bob
        if (self.aliceDecodedExp) {
            [self.aliceDecodedExp fulfill];
            self.aliceDecodedExp = nil;
        }
    } else if (otrKit == self.otrKitBob) {
        if (self.bobDecodedExp) {
            [self.bobDecodedExp fulfill];
            self.bobDecodedExp = nil;
        }
        // decoded message from alice
        //XCTAssertEqualObjects(decodedMessage, kOTRTestMessage);
        if ([decodedMessage isEqualToString:kOTRTestMessage] && wasEncrypted) {
            NSURL *fileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"test_image" withExtension:@"jpg"];
            NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
            NSString *fileName = [fileURL lastPathComponent];
            self.testFileData = fileData;
            [self.dataHandlerAlice sendFileWithName:fileName fileData:fileData username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:tag];
        }
    }
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
    
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
    if (messageState == OTRKitMessageStateEncrypted) {
        XCTAssertNotNil(fingerprint);
        NSLog(@"%@ OTR active for %@ %@ %@", otrKit, username, accountName, protocol);
        if (otrKit == self.otrKitAlice) {
            [self.otrKitAlice encodeMessage:kOTRTestMessage tlvs:nil username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:kOTRTestMessage];
            [self.aliceExp fulfill];
        } else if (otrKit == self.otrKitBob) {
            [self.bobExp fulfill];
        }
    } else if (messageState == OTRKitMessageStatePlaintext) {
        if (otrKit == self.otrKitAlice) {
            [self.aliceSessionEnd fulfill];
        } else if (otrKit == self.otrKitBob) {
            [self.bobSessionEnd fulfill];
        }
    }
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

#pragma mark OTRDataHandlerDelegate methods

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint
              error:(NSError*)error {
    XCTAssertNotNil(dataHandler);
    XCTAssertNotNil(transfer);
    XCTAssertNotNil(fingerprint);
    XCTFail(@"error sending file: %@ %@", transfer, error);
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
    offeredTransfer:(OTRDataIncomingTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint
{
    XCTAssertNotNil(dataHandler);
    XCTAssertNotNil(transfer);
    XCTAssertNotNil(fingerprint);
    NSLog(@"offered file: %@", transfer);
    // auto-accept
    [dataHandler startIncomingTransfer:transfer];
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
           progress:(float)progress
        fingerprint:(OTRFingerprint*)fingerprint
{
    XCTAssertNotNil(dataHandler);
    XCTAssertNotNil(transfer);
    XCTAssertNotNil(fingerprint);
    NSLog(@"transfer progress: %f %@", progress, transfer);
    XCTAssert(progress > 0,@"Progress less than zero");
    XCTAssert(progress <= 1,@"Progress greater than one");
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
   transferComplete:(OTRDataTransfer*)transfer
        fingerprint:(OTRFingerprint*)fingerprint
{
    XCTAssertNotNil(dataHandler);
    XCTAssertNotNil(transfer);
    XCTAssertNotNil(fingerprint);
    NSLog(@"transfer complete: %@", transfer);
    if (dataHandler == self.dataHandlerBob) {
        if ([transfer.fileData isEqualToData:self.testFileData]) {
            [self.fileTransferExp fulfill];
        }
        [self.otrKitBob disableEncryptionWithUsername:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP];
    }
}



@end
