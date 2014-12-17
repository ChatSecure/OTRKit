//
//  OTRKitTestsiOS.m
//  OTRKitTestsiOS
//
//  Created by Christopher Ballinger on 7/21/14.
//
//

#import <XCTest/XCTest.h>
#import "OTRKit.h"

static NSString * const kOTRMessage1 = @"message1";
static NSString * const kOTRMessage2 = @"message2";

@interface OTRKitTestsiOS : XCTestCase <OTRKitDelegate>
@property (nonatomic, strong) OTRKit *otrKit1;
@property (nonatomic, strong) OTRKit *otrKit2;
@property (nonatomic, strong) XCTestExpectation *expectation1;
@property (nonatomic, strong) XCTestExpectation *expectation2;
@property (nonatomic) dispatch_queue_t callbackQueue;
@end

@implementation OTRKitTestsiOS

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.callbackQueue = dispatch_queue_create("callback queue", 0);
    self.otrKit1 = [[OTRKit alloc] init];
    self.otrKit1.delegate = self;
    self.otrKit1.otrPolicy = OTRKitPolicyAlways;
    self.otrKit1.callbackQueue = self.callbackQueue;
    self.otrKit2 = [[OTRKit alloc] init];
    self.otrKit2.delegate = self;
    self.otrKit2.otrPolicy = OTRKitPolicyAlways;
    self.otrKit2.callbackQueue = self.callbackQueue;
    XCTAssertNotNil(self.otrKit1, "otrKit1 failed to initialize");
    XCTAssertNotNil(self.otrKit2, "otrKit2 failed to initialize");
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    self.otrKit1 = nil;
    self.otrKit2 = nil;
}

- (void)testMessaging
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path1 = [documentsDirectory stringByAppendingPathComponent:@"OTRKit1"];
    NSString *path2 = [documentsDirectory stringByAppendingPathComponent:@"OTRKit2"];
    BOOL success = NO;
    success = [[NSFileManager defaultManager] createDirectoryAtPath:path1 withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue(success);
    success = [[NSFileManager defaultManager] createDirectoryAtPath:path2 withIntermediateDirectories:YES attributes:nil error:nil];
    XCTAssertTrue(success);
    
    self.expectation1 = [self expectationWithDescription:@"test1"];
    self.expectation2 = [self expectationWithDescription:@"test2"];
    
    NSString *message1 = kOTRMessage1;
    NSString *message2 = kOTRMessage2;
    NSString *username1 = @"alice@example.com";
    NSString *username2 = @"bob@example.com";
    NSString *protocol = @"xmpp";
    NSString *tag1 = @"tag1";
    NSString *tag2 = @"tag2";
    
    [self.otrKit1 setupWithDataPath:path1];
    [self.otrKit2 setupWithDataPath:path2];
    
    [self.otrKit1 initiateEncryptionWithUsername:username2 accountName:username1 protocol:protocol];
    [self.otrKit1 encodeMessage:message1 tlvs:nil username:username2 accountName:username1 protocol:protocol tag:tag1];
    [self.otrKit1 encodeMessage:message1 tlvs:nil username:username2 accountName:username1 protocol:protocol tag:tag1];
    [self.otrKit2 encodeMessage:message2 tlvs:nil username:username1 accountName:username2 protocol:protocol tag:tag2];
    [self.otrKit2 encodeMessage:message2 tlvs:nil username:username1 accountName:username2 protocol:protocol tag:tag2];
    
    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
        NSLog(@"failed: %@", error);
    }];
}

#pragma mark OTRKitDelegate

/**
 *  This method **MUST** be implemented or OTR will not work. All outgoing messages
 *  should be sent first through OTRKit encodeMessage and then passed from this delegate
 *  to the appropriate chat protocol manager to send the actual message.
 *
 *  @param otrKit      reference to shared instance
 *  @param message     message to be sent over the network. may contain ciphertext.
 *  @param recipient   intended recipient of the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attached to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
  injectMessage:(NSString*)message
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ injectMessage: %d username: %@ accountName: %@ tag: %@", otrKit, [OTRKit stringStartsWithOTRPrefix:message], username, accountName, tag);
    if (otrKit == self.otrKit1) {
        [self.otrKit2 decodeMessage:message username:accountName accountName:username protocol:protocol tag:tag];
    } else if (otrKit == self.otrKit2) {
        [self.otrKit1 decodeMessage:message username:accountName accountName:username protocol:protocol tag:tag];
    }
}

/**
 *  All outgoing messages should be sent to the OTRKit encodeMessage method before being
 *  sent over the network.
 *
 *  @param otrKit      reference to shared instance
 *  @param encodedMessage     plaintext message
 *  @param wasEncrypted whether or not encodedMessage message is ciphertext, or just plaintext appended with the opportunistic whitespace. This is just a check of the encodedMessage message for a "?OTR" prefix.
 *  @param username      buddy who sent the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 encodedMessage:(NSString*)encodedMessage
   wasEncrypted:(BOOL)wasEncrypted
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag
          error:(NSError*)error {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ encodedMessage: %d username: %@ accountName: %@ tag: %@", otrKit, wasEncrypted, username, accountName, tag);
    if (otrKit == self.otrKit1) {
        [self.otrKit2 decodeMessage:encodedMessage username:accountName accountName:username protocol:protocol tag:tag];
    } else if (otrKit == self.otrKit2) {
        [self.otrKit1 decodeMessage:encodedMessage username:accountName accountName:username protocol:protocol tag:tag];
    }
}


/**
 *  All incoming messages should be sent to the OTRKit decodeMessage method before being
 *  processed by your application. You should only display the messages coming from this delegate method.
 *
 *  @param otrKit      reference to shared instance
 *  @param decodedMessage plaintext message to display to the user. May be nil if other party is sending raw TLVs without messages attached.
 *  @param wasEncrypted whether or not the original message sent to decodeMessage: was encrypted or plaintext. This is just a check of the original message for a "?OTR" prefix.
 *  @param tlvs        OTRTLV values that may be present.
 *  @param sender      buddy who sent the message
 *  @param accountName your local account name
 *  @param protocol    protocol for account name such as "xmpp"
 *  @param tag optional tag to attach additional application-specific data to message. Only used locally.
 */
- (void) otrKit:(OTRKit*)otrKit
 decodedMessage:(NSString*)decodedMessage
   wasEncrypted:(BOOL)wasEncrypted
           tlvs:(NSArray*)tlvs
       username:(NSString*)username
    accountName:(NSString*)accountName
       protocol:(NSString*)protocol
            tag:(id)tag {
    XCTAssertNotNil(otrKit);
    NSLog(@"%@ decodedMessage(%d): %@ username: %@ accountName: %@ tag: %@", otrKit, wasEncrypted, decodedMessage, username, accountName, tag);
    if (otrKit == self.otrKit1) {
        XCTAssertEqualObjects(decodedMessage, kOTRMessage2);
        if ([decodedMessage isEqualToString:kOTRMessage2] && wasEncrypted) {
            [self.expectation1 finalize];
        }
    } else if (otrKit == self.otrKit2) {
        XCTAssertEqualObjects(decodedMessage, kOTRMessage1);
        if ([decodedMessage isEqualToString:kOTRMessage1] && wasEncrypted) {
            [self.expectation2 finalize];
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
          protocol:(NSString*)protocol {
    XCTAssertNotNil(otrKit);
    if (messageState == OTRKitMessageStateEncrypted) {
        NSLog(@"%@ OTR active for %@ %@ %@", otrKit, username, accountName, protocol);
    }
}

/**
 *  libotr likes to know if buddies are still "online". This method
 *  is called synchronously on the callback queue so be careful.
 *
 *  @param otrKit      reference to shared instance
 *  @param recipient   intended recipient of the message
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
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
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
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
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
    NSLog(@"%s %d %s %s", __FILE__, __LINE__, __PRETTY_FUNCTION__, __FUNCTION__);
}

@end
