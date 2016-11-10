//
//  OTRKitTestsiOS.m
//  OTRKitTestsiOS
//
//  Created by Christopher Ballinger on 7/21/14.
//
//

#import <XCTest/XCTest.h>
@import OTRKit;

static NSString * const kOTRTestMessage = @"Hello World";
static NSString * const kOTRTestAccountAlice = @"alice@example.com";
static NSString * const kOTRTestAccountBob = @"bob@example.com";
static NSString * const kOTRTestProtocolXMPP = @"xmpp";

@interface OTRKitTestsiOS : XCTestCase <OTRKitDelegate, OTRDataHandlerDelegate>
@property (nonatomic, strong) OTRKit *otrKitAlice;
@property (nonatomic, strong) OTRKit *otrKitBob;
@property (nonatomic, strong) OTRDataHandler *dataHandlerAlice;
@property (nonatomic, strong) OTRDataHandler *dataHandlerBob;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) NSData *testFileData;


@property (nonatomic, strong) XCTestExpectation *aliceExp;
@property (nonatomic, strong) XCTestExpectation *bobExp;
@property (nonatomic, strong) XCTestExpectation *fileTransferExp;

@end

@implementation OTRKitTestsiOS

- (void)setUp
{
    [super setUp];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path1 = [documentsDirectory stringByAppendingPathComponent:@"otrKitAlice"];
    NSString *path2 = [documentsDirectory stringByAppendingPathComponent:@"otrKitBob"];
    BOOL success = NO;
    success = [[NSFileManager defaultManager] createDirectoryAtPath:path1 withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue(success);
    success = [[NSFileManager defaultManager] createDirectoryAtPath:path2 withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue(success);
    
    self.callbackQueue = dispatch_queue_create("callback queue", 0);
    self.otrKitAlice = [[OTRKit alloc] initWithDelegate: self dataPath:path1];
    self.otrKitAlice.otrPolicy = OTRKitPolicyOpportunistic;
    self.otrKitAlice.callbackQueue = self.callbackQueue;
    self.otrKitBob = [[OTRKit alloc] initWithDelegate:self dataPath:path2];
    self.otrKitBob.otrPolicy = OTRKitPolicyOpportunistic;
    self.otrKitBob.callbackQueue = self.callbackQueue;
    self.dataHandlerAlice = [[OTRDataHandler alloc] initWithOTRKit:self.otrKitAlice delegate:self];
    self.dataHandlerAlice.callbackQueue = self.callbackQueue;
    self.dataHandlerBob = [[OTRDataHandler alloc] initWithOTRKit:self.otrKitBob delegate:self];
    self.dataHandlerBob.callbackQueue = self.callbackQueue;
    XCTAssertNotNil(self.otrKitAlice, "otrKitAlice failed to initialize");
    XCTAssertNotNil(self.otrKitBob, "otrKitBob failed to initialize");
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    self.otrKitAlice = nil;
    self.otrKitBob = nil;
}

- (void)testMessaging
{
    self.aliceExp = [self expectationWithDescription:@"testMessaging alice"];
    self.bobExp = [self expectationWithDescription:@"testMessaging bob"];

    [self.otrKitAlice initiateEncryptionWithUsername:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP];

    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
        if (error) {
            NSLog(@"failed waitForExpectationsWithTimeout: %@", error);
        }
    }];
}

#pragma mark OTRKitDelegate

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

    if (otrKit == self.otrKitAlice) { // coming from alice's otrkit
        // "send" message to bob's otrkit
        [self.otrKitBob decodeMessage:message username:kOTRTestAccountAlice accountName:kOTRTestAccountBob protocol:kOTRTestProtocolXMPP tag:tag];
    } else if (otrKit == self.otrKitBob) { // coming from bob's otrkit
        // "send" message to bob's otrkit
        [self.otrKitAlice decodeMessage:message username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:tag];
    }
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
   wasEncrypted:(BOOL)wasEncrypted
           tlvs:(NSArray<OTRTLV*>*)tlvs
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
    fingerprint:(nullable OTRFingerprint*)fingerprint
            tag:(nullable id)tag {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ decodedMessage(%d): %@ username: %@ accountName: %@ tag: %@", otrKit, wasEncrypted, decodedMessage, username, accountName, tag);
    if (otrKit == self.otrKitAlice) {
        // decoded message from bob
    } else if (otrKit == self.otrKitBob) {
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
    XCTAssertNotNil(fingerprint);
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
    if (messageState == OTRKitMessageStateEncrypted) {
        NSLog(@"%@ OTR active for %@ %@ %@", otrKit, username, accountName, protocol);
        if (otrKit == self.otrKitAlice) {
            [self.otrKitAlice encodeMessage:kOTRTestMessage tlvs:nil username:kOTRTestAccountBob accountName:kOTRTestAccountAlice protocol:kOTRTestProtocolXMPP tag:nil];
            [self.aliceExp fulfill];
        } else if (otrKit == self.otrKitBob) {
            [self.bobExp fulfill];
        }
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
              error:(NSError*)error {
    XCTFail(@"error sending file: %@ %@", transfer, error);
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
    offeredTransfer:(OTRDataIncomingTransfer*)transfer {
    NSLog(@"offered file: %@", transfer);
    // auto-accept
    [dataHandler startIncomingTransfer:transfer];
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
           transfer:(OTRDataTransfer*)transfer
           progress:(float)progress {
    NSLog(@"transfer progress: %f %@", progress, transfer);
    XCTAssert(progress > 0,@"Progress less than zero");
    XCTAssert(progress <= 1,@"Progress greater than one");
}

- (void)dataHandler:(OTRDataHandler*)dataHandler
   transferComplete:(OTRDataTransfer*)transfer {
    NSLog(@"transfer complete: %@", transfer);
    if (dataHandler == self.dataHandlerBob) {
        if ([transfer.fileData isEqualToData:self.testFileData]) {
            [self.fileTransferExp fulfill];
        }
    }
}



@end
