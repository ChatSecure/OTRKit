//
//  OTRKitTests.m
//  OTRKitTests
//
//  Created by Christopher Ballinger on 3/6/14.
//
//

#import <XCTest/XCTest.h>
#import "OTRKit.h"

static NSString * const kAliceName = @"alice";
static NSString * const kBobName = @"bob";
static NSString * const kTestProtocol = @"test";

@interface OTRKitTests : XCTestCase <OTRKitDelegate>
@property (nonatomic, strong) OTRKit *alice;
@property (nonatomic, strong) OTRKit *bob;
@end

@implementation OTRKitTests

- (NSString*) pathForDataWithFolderName:(NSString*)folderName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *folderPath = [documentsDirectory stringByAppendingPathComponent:folderName];
    return folderPath;
}

- (void)setUp
{
    [super setUp];
    NSLog(@"Setup called");
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *alicePath = [self pathForDataWithFolderName:kAliceName];
    NSString *bobPath = [self pathForDataWithFolderName:kBobName];
    NSArray *paths = @[alicePath, bobPath];
    [paths enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:&error];
            if (error) {
                NSLog(@"Error removing existing OTR data: %@", error);
                error = nil;
            }
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) {
            NSLog(@"Error creating directory at path %@: %@", path, error);
        }
    }];
    
    self.alice = [[OTRKit alloc] initWithDataPath:alicePath];
    self.alice.delegate = self;
    self.bob = [[OTRKit alloc] initWithDataPath:bobPath];
    self.bob.delegate = self;
    
    [self generatePrivateKeyForOTRKit:self.alice accountName:kAliceName];
    [self generatePrivateKeyForOTRKit:self.bob accountName:kBobName];
}

- (void) generatePrivateKeyForOTRKit:(OTRKit*)otrKit accountName:(NSString*)accountName {
    __block BOOL waitingForBlock = YES;
    
    [otrKit generatePrivateKeyIfNeededForAccountName:accountName protocol:kTestProtocol completionBlock:^(BOOL success, NSError *error) {
        if (!success) {
            XCTFail(@"Error generating %@'s private key: %@", accountName, error);
        } else {
            NSLog(@"Generated private key for %@.", accountName);
        }
        waitingForBlock = NO;
    }];
    while(waitingForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    waitingForBlock = YES;
    [otrKit hasPrivateKeyForAccountName:accountName protocol:kTestProtocol completionBlock:^(BOOL hasPrivateKey) {
        if (!hasPrivateKey) {
            NSString *errorMessage = [NSString stringWithFormat:@"Private key not found for %@.", accountName];
            NSLog(@"%@", errorMessage);
            XCTFail("%@", errorMessage);
        } else {
            NSLog(@"Private key found for %@.", accountName);
        }
        waitingForBlock = NO;
    }];
    while(waitingForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}

- (void)tearDown
{
    NSLog(@"Teardown called");
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    NSArray *pathsToRemove = @[self.alice.dataPath, self.bob.dataPath];
    [pathsToRemove enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if (error) {
            NSLog(@"Error moving item at path %@: %@", path, error);
        }
    }];
}

- (void) testAliceInitiateEncryption {
    [self.alice inititateEncryptionWithRecipient:kBobName accountName:kAliceName protocol:kTestProtocol];
}

/*
- (void)testMessageSendingAndReceiving
{
    NSString *aliceMessage = @"hello";
    //NSString *bobMessage = @"goodbye";
    __block BOOL waitingForBlock = YES;
    [self.alice encodeMessage:aliceMessage recipient:kBobName accountName:kAliceName protocol:kTestProtocol completionBlock:^(NSString *encodedMessage, NSError *error) {
        if ([encodedMessage isEqualToString:aliceMessage]) {
            XCTFail(@"Failed to encode Alice message");
        }
        if (error) {
            XCTFail(@"Error encoding Alice message: %@", error);
        }
        NSLog(@"Alice encoded message '%@': %@", aliceMessage, encodedMessage);
        [self.bob decodeMessage:encodedMessage sender:kAliceName accountName:kBobName protocol:kTestProtocol completionBlock:^(NSString *decodedMessage, NSError *error) {
            NSLog(@"Bob decoded message '%@' to %@", encodedMessage, decodedMessage);
            if (![aliceMessage isEqualToString:decodedMessage]) {
                XCTFail(@"'%@' and '%@' messages not equal", aliceMessage, decodedMessage);
            }
            waitingForBlock = NO;
        }];
    }];
    while(waitingForBlock) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
}
*/

- (void) otrKit:(OTRKit *)otrKit injectMessage:(NSString *)message recipient:(NSString *)recipient accountName:(NSString *)accountName protocol:(NSString *)protocol {
    //OTRKit *otrSender = otrKit;
    OTRKit *otrRecipient = nil;
    if (otrKit == self.alice) {
        otrRecipient = self.bob;
    } else {
        otrRecipient = self.alice;
    }
    NSLog(@"%@ injected to %@ with message: %@", accountName, recipient, message);
    [otrRecipient decodeMessage:message sender:accountName accountName:recipient protocol:protocol completionBlock:^(NSString *decodedMessage, NSError *error) {
        NSLog(@"injected decoded message: %@", message);
    }];
}

- (void) otrKit:(OTRKit *)otrKit willStartGeneratingPrivateKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol {
    NSLog(@"will start private key for %@ %@", accountName, protocol);
}

- (void) otrKit:(OTRKit *)otrKit didFinishGeneratingPrivateKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol error:(NSError *)error {
    if (error) {
        XCTFail(@"Error generating private key for %@ %@: %@", accountName, protocol, error);
    } else {
        NSLog(@"did finish private key for %@ %@", accountName, protocol);
    }
}

@end
