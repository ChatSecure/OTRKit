//
//  OTRKitTests.m
//  OTRKitTests
//
//  Created by Christopher Ballinger on 3/6/14.
//
//

#import <XCTest/XCTest.h>
#import "OTRKit.h"

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
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *alicePath = [self pathForDataWithFolderName:@"alice"];
    NSString *bobPath = [self pathForDataWithFolderName:@"bob"];
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
}

- (void)tearDown
{
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

- (void)testMessageSendingAndReceiving
{
    NSString *aliceMessage = @"hello";
    NSString *bobMessage = @"goodbye";
    __block BOOL waitingForBlock = YES;
    [self.alice encodeMessage:aliceMessage recipient:@"bob" accountName:@"alice" protocol:@"test" completionBlock:^(NSString *encodedMessage) {
        NSLog(@"Alice encoded message '%@': %@", aliceMessage, encodedMessage);
        [self.bob decodeMessage:encodedMessage sender:@"alice" accountName:@"bob" protocol:@"test" completionBlock:^(NSString *decodedMessage) {
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

- (void) otrKit:(OTRKit *)otrKit injectMessage:(NSString *)message recipient:(NSString *)recipient accountName:(NSString *)accountName protocol:(NSString *)protocol {
    //OTRKit *otrSender = otrKit;
    OTRKit *otrRecipient = nil;
    if (otrKit == self.alice) {
        otrRecipient = self.bob;
    } else {
        otrRecipient = self.alice;
    }
    NSLog(@"%@ injected to %@ with message: %@", accountName, recipient, message);
    [otrRecipient decodeMessage:message sender:accountName accountName:recipient protocol:protocol completionBlock:^(NSString *message) {
        NSLog(@"injected decoded message: %@", message);
    }];
}

@end
