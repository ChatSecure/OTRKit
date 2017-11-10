/*
 * OTRKit.m
 * OTRKit
 *
 * Created by Chris Ballinger on 9/4/11.
 * Copyright (c) 2012 Chris Ballinger. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "OTRKit.h"
#import "OTRTLV.h"
#import "proto.h"
#import "message.h"
#import "privkey.h"
#import "proto.h"
#import "OTRDataHandler.h"
#import "OTRErrorUtility.h"

static NSString * const kOTRKitPrivateKeyFileName = @"otr.private_key";
static NSString * const kOTRKitFingerprintsFileName = @"otr.fingerprints";
static NSString * const kOTRKitInstanceTagsFileName =  @"otr.instance_tags";

/** Length of Fingerprint->fingerprint in libotr struct */
static const NSUInteger kOTRKitFingerprintBytes = 20;

/**
 *  This structure will be passed through the opdata parameter in libotr functions
 *  and will allow for a reference to OTRKit "self" as well as a user-defined tag supplied
 *  to the encoding/decoding functions.
 */
@interface OTROpData : NSObject
@property (nonatomic, strong, readonly) OTRKit *otrKit;
@property (nonatomic, strong, readonly) id tag;
- (instancetype) initWithOTRKit:(OTRKit*)otrKit tag:(id)tag;
@end

@implementation OTROpData
- (instancetype) initWithOTRKit:(OTRKit*)otrKit tag:(id)tag {
    if (self = [super init]) {
        _otrKit = otrKit;
        _tag = tag;
    }
    return self;
}
@end


@interface OTRKit() {
    /** Used for determining correct usage of dispatch_sync */
    void *IsOnInternalQueueKey;
}
@property (nonatomic, readonly) dispatch_queue_t internalQueue;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, readonly) OtrlUserState userState;
@property (nonatomic, strong) NSMutableDictionary<NSString*,NSNumber*> *protocolMaxSize;

/**
 *  OTRTLVHandler keyed to boxed NSNumber of OTRTLVType
 */
@property (nonatomic, strong, readonly) NSMutableDictionary<NSNumber*, id<OTRTLVHandler>> *tlvHandlers;


/** Will perform block asynchronously on the internalQueue, unless we're already on internalQueue */
- (void) performBlockAsync:(dispatch_block_t)block;

/** Will perform block synchronously on the internalQueue and block for result if called on another queue. */
- (void) performBlock:(dispatch_block_t)block;

@end

@implementation OTRKit
@synthesize otrPolicy = _otrPolicy;
@synthesize callbackQueue = _callbackQueue;

#pragma mark libotr ui_ops callback functions

static OtrlPolicy policy_cb(void *opdata, ConnContext *context)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    OtrlPolicy policy = OTRL_POLICY_DEFAULT;
    if (otrKit) {
        policy = [otrKit otrlPolicy];
    }
    return policy;
}

static void create_privkey_cb(void *opdata, const char *accountname,
                              const char *protocol)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    NSString *accountNameString = [NSString stringWithUTF8String:accountname];
    NSString *protocolString = [NSString stringWithUTF8String:protocol];
    if ([otrKit.delegate respondsToSelector:@selector(otrKit:willStartGeneratingPrivateKeyForAccountName:protocol:)]) {
        dispatch_async(otrKit.callbackQueue, ^{
            [otrKit.delegate otrKit:otrKit willStartGeneratingPrivateKeyForAccountName:accountNameString   protocol:protocolString];
        });
    }
    void *newkeyp;
    gcry_error_t generateError = otrl_privkey_generate_start(otrKit.userState, accountname, protocol, &newkeyp);
    FILE *privf;
    NSString *path = [otrKit privateKeyPath];
    privf = fopen([path UTF8String], "w+b");
    if (generateError == gcry_error(GPG_ERR_NO_ERROR)) {
            otrl_privkey_generate_calculate(newkeyp);
            otrl_privkey_generate_finish_FILEp(otrKit.userState, newkeyp, privf);
            if ([otrKit.delegate respondsToSelector:@selector(otrKit:didFinishGeneratingPrivateKeyForAccountName:protocol:error:)]) {
                dispatch_async(otrKit.callbackQueue, ^{
                    [otrKit.delegate otrKit:otrKit didFinishGeneratingPrivateKeyForAccountName:accountNameString protocol:protocolString error:nil];
                });
            }
    } else {
        NSError *error = [OTRErrorUtility errorForGPGError:generateError];
        if ([otrKit.delegate respondsToSelector:@selector(otrKit:didFinishGeneratingPrivateKeyForAccountName:protocol:error:)]) {
            dispatch_async(otrKit.callbackQueue, ^{
                [otrKit.delegate otrKit:otrKit didFinishGeneratingPrivateKeyForAccountName:accountNameString protocol:protocolString error:error];
            });
        }
    }
    fclose(privf);
}

static int is_logged_in_cb(void *opdata, const char *accountname,
                           const char *protocol, const char *recipient)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    if (![otrKit.delegate respondsToSelector:@selector(otrKit:isUsernameLoggedIn:accountName:protocol:)]) {
        return -1;
    }
    __block BOOL loggedIn = NO;
    dispatch_sync(otrKit.callbackQueue, ^{
        loggedIn = [otrKit.delegate otrKit:otrKit
                        isUsernameLoggedIn:[NSString stringWithUTF8String:recipient]
                               accountName:[NSString stringWithUTF8String:accountname]
                                  protocol:[NSString stringWithUTF8String:protocol]];
    });
    return loggedIn;
}

static void inject_message_cb(void *opdata, const char *accountname,
                              const char *protocol, const char *recipient, const char *message)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    if (!otrKit.delegate) {
        return;
    }
    NSString *messageString = [NSString stringWithUTF8String:message];
    NSString *usernameString = [NSString stringWithUTF8String:recipient];
    NSString *accountNameString = [NSString stringWithUTF8String:accountname];
    NSString *protocolString = [NSString stringWithUTF8String:protocol];
    
    id tag = data.tag;
    OTRFingerprint *fingerprint = [otrKit activeFingerprintForUsername:usernameString accountName:accountNameString protocol:protocolString];
    dispatch_async(otrKit.callbackQueue, ^{
        [otrKit.delegate otrKit:otrKit injectMessage:messageString username:usernameString accountName:accountNameString protocol:protocolString fingerprint:fingerprint tag:tag];
    });
}

static void update_context_list_cb(void *opdata)
{
}

static void confirm_fingerprint_cb(void *opdata, OtrlUserState us,
                                   const char *accountname, const char *protocol, const char *username,
                                   unsigned char fingerprint[kOTRKitFingerprintBytes])
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (![otrKit.delegate respondsToSelector:@selector(otrKit:showFingerprintConfirmationForTheirHash:ourHash:username:accountName:protocol:)]) {
        return;
    }
    char our_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN], their_hash[OTRL_PRIVKEY_FPRINT_HUMAN_LEN];
    
    ConnContext *context = otrl_context_find(otrKit.userState, username,accountname, protocol,OTRL_INSTAG_BEST, NO,NULL,NULL, NULL);
    if (!context) {
        return;
    }
    
    otrl_privkey_fingerprint(otrKit.userState, our_hash, context->accountname, context->protocol);
    
    otrl_privkey_hash_to_human(their_hash, fingerprint);
    
    NSString *ourHash = [NSString stringWithUTF8String:our_hash];
    NSString *theirHash = [NSString stringWithUTF8String:their_hash];
    NSString *accountNameString = [NSString stringWithUTF8String:accountname];
    NSString *usernameString = [NSString stringWithUTF8String:username];
    NSString *protocolString = [NSString stringWithUTF8String:protocol];
    dispatch_async(otrKit.callbackQueue, ^{
        [otrKit.delegate otrKit:otrKit showFingerprintConfirmationForTheirHash:theirHash ourHash:ourHash username:usernameString accountName:accountNameString protocol:protocolString];
    });
}

static void write_fingerprints_cb(void *opdata)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    FILE *storef;
    NSString *path = [otrKit fingerprintsPath];
    storef = fopen([path UTF8String], "wb");
    if (!storef) return;
    otrl_privkey_write_fingerprints_FILEp(otrKit.userState, storef);
    fclose(storef);
}

static void gone_secure_cb(void *opdata, ConnContext *context)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    [otrKit updateEncryptionStatusWithContext:context];
}

static void gone_insecure_cb(void *opdata, ConnContext *context)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    [otrKit updateEncryptionStatusWithContext:context];
}

static void still_secure_cb(void *opdata, ConnContext *context, int is_reply)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    [otrKit updateEncryptionStatusWithContext:context];
}


static int max_message_size_cb(void *opdata, ConnContext *context)
{
    NSString *protocol = [NSString stringWithUTF8String:context->protocol];
    if (!protocol.length) {
        return 0;
    }
    
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return 0;
    }
    NSNumber *maxMessageSize = [otrKit.protocolMaxSize objectForKey:protocol];
    if (maxMessageSize) {
        return maxMessageSize.intValue;
    }
    return 0;
}

static const char* otr_error_message_cb(void *opdata, ConnContext *context,
                                        OtrlErrorCode err_code)
{
    NSString *errorString = nil;
    switch (err_code)
    {
        case OTRL_ERRCODE_NONE :
            break;
        case OTRL_ERRCODE_ENCRYPTION_ERROR :
            errorString = @"Error occurred encrypting message.";
            break;
        case OTRL_ERRCODE_MSG_NOT_IN_PRIVATE :
            if (context) {
                errorString = [NSString stringWithFormat:@"You sent encrypted data to %s, who wasn't expecting it.", context->accountname];
            }
            break;
        case OTRL_ERRCODE_MSG_UNREADABLE :
            errorString = @"You transmitted an unreadable encrypted message.";
            break;
        case OTRL_ERRCODE_MSG_MALFORMED :
            errorString = @"You transmitted a malformed data message.";
            break;
    }
    if (!errorString.length) {
        return NULL;
    }
    NSUInteger length = [errorString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    char *err_msg = malloc(length);
    if (!err_msg) {
        return NULL;
    }
    strncpy(err_msg, [errorString UTF8String], length);
    return err_msg;
}

static void otr_error_message_free_cb(void *opdata, const char *err_msg)
{
    if (err_msg) {
        free((void*)err_msg);
    }
}

static const char *resent_msg_prefix_cb(void *opdata, ConnContext *context)
{
    NSString *resentString = @"[resent]";
    NSUInteger length = [resentString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    char *resent_msg = malloc(length);
    if (!resent_msg) {
        return NULL;
    }
    strncpy(resent_msg, [resentString UTF8String], length);
	return resent_msg;
}

static void resent_msg_prefix_free_cb(void *opdata, const char *prefix)
{
    if (prefix) {
        free((void*)prefix);
    }
}

static void handle_smp_event_cb(void *opdata, OtrlSMPEvent smp_event,
                                ConnContext *context, unsigned short progress_percent,
                                char *question)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (![otrKit.delegate respondsToSelector:@selector(otrKit:handleSMPEvent:progress:question:username:accountName:protocol:)]) {
        return;
    }
    OTRKitSMPEvent event = OTRKitSMPEventNone;
    double progress = (double)progress_percent/100.0;
    if (!context) return;
    switch (smp_event)
    {
        case OTRL_SMPEVENT_NONE :
            event = OTRKitSMPEventNone;
            break;
        case OTRL_SMPEVENT_ASK_FOR_SECRET:
            event = OTRKitSMPEventAskForSecret;
            break;
        case OTRL_SMPEVENT_ASK_FOR_ANSWER:
            event = OTRKitSMPEventAskForAnswer;
            break;
        case OTRL_SMPEVENT_CHEATED :
            event = OTRKitSMPEventCheated;
            otrl_message_abort_smp(otrKit.userState, &ui_ops, opdata, context);
            break;
        case OTRL_SMPEVENT_IN_PROGRESS :
            event = OTRKitSMPEventInProgress;
            break;
        case OTRL_SMPEVENT_SUCCESS :
            event = OTRKitSMPEventSuccess;
            break;
        case OTRL_SMPEVENT_FAILURE :
            event = OTRKitSMPEventFailure;
            break;
        case OTRL_SMPEVENT_ABORT:
            event = OTRKitSMPEventAbort;
            break;
        case OTRL_SMPEVENT_ERROR :
            event = OTRKitSMPEventError;
            otrl_message_abort_smp(otrKit.userState, &ui_ops, opdata, context);
            break;
    }
    NSString *questionString = nil;
    if (question) {
        questionString = [NSString stringWithUTF8String:question];
    }
    
    NSString *username = [NSString stringWithUTF8String:context->username];
    NSString *accountName = [NSString stringWithUTF8String:context->accountname];
    NSString *protocol = [NSString stringWithUTF8String:context->protocol];
    
    dispatch_async(otrKit.callbackQueue, ^{
        [otrKit.delegate otrKit:otrKit handleSMPEvent:event progress:progress question:questionString username:username accountName:accountName protocol:protocol];
    });
}

static void handle_msg_event_cb(void *opdata, OtrlMessageEvent msg_event,
                                ConnContext *context, const char* message, gcry_error_t err)
{
    if (!context) {
        return;
    }
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (![otrKit.delegate respondsToSelector:@selector(otrKit:handleMessageEvent:message:username:accountName:protocol:tag:error:)]) {
        return;
    }
    
    NSString *messageString = nil;
    if (message) {
        messageString = [NSString stringWithUTF8String:message];
    }
    NSError *error = [OTRErrorUtility errorForGPGError:err];
    OTRKitMessageEvent event = OTRKitMessageEventNone;
    switch (msg_event) {
        case OTRL_MSGEVENT_NONE:
            event = OTRKitMessageEventNone;
            break;
        case OTRL_MSGEVENT_ENCRYPTION_REQUIRED:
            event = OTRKitMessageEventEncryptionRequired;
            break;
        case OTRL_MSGEVENT_ENCRYPTION_ERROR:
            event = OTRKitMessageEventEncryptionError;
            break;
        case OTRL_MSGEVENT_CONNECTION_ENDED:
            event = OTRKitMessageEventConnectionEnded;
            break;
        case OTRL_MSGEVENT_SETUP_ERROR:
            event = OTRKitMessageEventSetupError;
            break;
        case OTRL_MSGEVENT_MSG_REFLECTED:
            event = OTRKitMessageEventMessageReflected;
            break;
        case OTRL_MSGEVENT_MSG_RESENT:
            event = OTRKitMessageEventMessageResent;
            break;
        case OTRL_MSGEVENT_RCVDMSG_NOT_IN_PRIVATE:
            event = OTRKitMessageEventReceivedMessageNotInPrivate;
            break;
        case OTRL_MSGEVENT_RCVDMSG_UNREADABLE:
            event = OTRKitMessageEventReceivedMessageUnreadable;
            break;
        case OTRL_MSGEVENT_RCVDMSG_MALFORMED:
            event = OTRKitMessageEventReceivedMessageMalformed;
            break;
        case OTRL_MSGEVENT_LOG_HEARTBEAT_RCVD:
            event = OTRKitMessageEventLogHeartbeatReceived;
            break;
        case OTRL_MSGEVENT_LOG_HEARTBEAT_SENT:
            event = OTRKitMessageEventLogHeartbeatSent;
            break;
        case OTRL_MSGEVENT_RCVDMSG_GENERAL_ERR:
            event = OTRKitMessageEventReceivedMessageGeneralError;
            break;
        case OTRL_MSGEVENT_RCVDMSG_UNENCRYPTED:
            event = OTRKitMessageEventReceivedMessageUnencrypted;
            break;
        case OTRL_MSGEVENT_RCVDMSG_UNRECOGNIZED:
            event = OTRKitMessageEventReceivedMessageUnrecognized;
            break;
        case OTRL_MSGEVENT_RCVDMSG_FOR_OTHER_INSTANCE:
            event = OTRKitMessageEventReceivedMessageForOtherInstance;
            break;
        default:
            break;
    }
    
    NSString *username = [NSString stringWithUTF8String:context->username];
    NSString *accountName = [NSString stringWithUTF8String:context->accountname];
    NSString *protocol = [NSString stringWithUTF8String:context->protocol];
    
    id tag = data.tag;
    dispatch_async(otrKit.callbackQueue, ^{
        [otrKit.delegate otrKit:otrKit handleMessageEvent:event message:messageString username:username accountName:accountName protocol:protocol tag:tag error:error];
    });
}

static void create_instag_cb(void *opdata, const char *accountname,
                             const char *protocol)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    FILE *instagf;
    NSString *path = [otrKit instanceTagsPath];
    instagf = fopen([path UTF8String], "w+b");
    otrl_instag_generate_FILEp(otrKit.userState, instagf, accountname, protocol);
    fclose(instagf);
}

static void timer_control_cb(void *opdata, unsigned int interval)
{
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (!otrKit) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (otrKit.pollTimer) {
            [otrKit.pollTimer invalidate];
            otrKit.pollTimer = nil;
        }
        if (interval > 0) {
            otrKit.pollTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:otrKit selector:@selector(messagePoll:) userInfo:nil repeats:YES];
        }
    });
}

static void received_symkey_cb(void *opdata, ConnContext *context,
                               unsigned int use, const unsigned char *usedata,
                               size_t usedatalen, const unsigned char *symkey) {
    OTROpData *data = (__bridge OTROpData*)opdata;
    OTRKit *otrKit = data.otrKit;
    NSCParameterAssert(otrKit);
    if (![otrKit.delegate respondsToSelector:@selector(otrKit:receivedSymmetricKey:forUse:useData:username:accountName:protocol:)]) {
        return;
    }
    NSData *symmetricKey = [[NSData alloc] initWithBytes:symkey length:OTRL_EXTRAKEY_BYTES];
    NSData *useDescriptionData = [[NSData alloc] initWithBytes:usedata length:usedatalen];
    
    NSString *username = [NSString stringWithUTF8String:context->username];
    NSString *accountName = [NSString stringWithUTF8String:context->accountname];
    NSString *protocol = [NSString stringWithUTF8String:context->protocol];
    
    dispatch_async(otrKit.callbackQueue, ^{
        [otrKit.delegate otrKit:otrKit receivedSymmetricKey:symmetricKey forUse:use useData:useDescriptionData username:username accountName:accountName protocol:protocol];
    });
}

static OtrlMessageAppOps ui_ops = {
    policy_cb,
    create_privkey_cb,
    is_logged_in_cb,
    inject_message_cb,
    update_context_list_cb,
    confirm_fingerprint_cb,
    write_fingerprints_cb,
    gone_secure_cb,
    gone_insecure_cb,
    still_secure_cb,
    max_message_size_cb,
    NULL,                   /* account_name */
    NULL,                   /* account_name_free */
    received_symkey_cb,
    otr_error_message_cb,
    otr_error_message_free_cb,
    resent_msg_prefix_cb,
    resent_msg_prefix_free_cb,
    handle_smp_event_cb,
    handle_msg_event_cb,
    create_instag_cb,
    NULL,		    /* convert_data */
    NULL,		    /* convert_data_free */
    timer_control_cb
};

#pragma mark Initialization

+ (void) initialize {
    // This is needed to suppress the initialization warning
    gcry_check_version(NULL);
}

- (void) dealloc {
    [self.pollTimer invalidate];
    [self performBlock:^{
        otrl_userstate_free(_userState);
        _userState = NULL;
    }];
}

- (instancetype) initWithDelegate:(id<OTRKitDelegate>)delegate dataPath:(nullable NSString*)dataPath {
    NSParameterAssert(delegate != nil);
    if (self = [super init]) {
        _delegate = delegate;
        _callbackQueue = dispatch_get_main_queue();
        _internalQueue = dispatch_queue_create("OTRKit Internal Queue", 0);
        
        // For safe usage of dispatch_sync
        IsOnInternalQueueKey = &IsOnInternalQueueKey;
        void *nonNullUnusedPointer = (__bridge void *)self;
        dispatch_queue_set_specific(_internalQueue, IsOnInternalQueueKey, nonNullUnusedPointer, NULL);
        
        _otrPolicy = OTRKitPolicyDefault;
        _tlvHandlers = [NSMutableDictionary dictionary];
        NSDictionary *protocolDefaults = @{@"prpl-msn":   @(1409),
                                           @"prpl-icq":   @(2346),
                                           @"prpl-aim":   @(2343),
                                           @"prpl-yahoo": @(832),
                                           @"prpl-gg":    @(1999),
                                           @"prpl-irc":   @(417),
                                           @"prpl-oscar": @(2343)};
        _protocolMaxSize = [NSMutableDictionary dictionaryWithDictionary:protocolDefaults];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            OTRL_INIT;
        });
        _userState = otrl_userstate_create();
        if (!dataPath) {
            _dataPath = [self documentsDirectory];
        } else {
            _dataPath = [dataPath copy];
        }
        [self readLibotrConfiguration];
    }
    return self;
}

- (void) readLibotrConfiguration {
    [self performBlockAsync:^{
        FILE *privf = NULL;
        NSString *path = [self privateKeyPath];
        privf = fopen([path UTF8String], "rb");
        if(privf) {
            otrl_privkey_read_FILEp(_userState, privf);
            fclose(privf);
        }
        
        FILE *storef = NULL;
        path = [self fingerprintsPath];
        storef = fopen([path UTF8String], "rb");
        if (storef) {
            otrl_privkey_read_fingerprints_FILEp(_userState, storef, NULL, NULL);
            fclose(storef);
        }
        
        FILE *tagf = NULL;
        path = [self instanceTagsPath];
        tagf = fopen([path UTF8String], "rb");
        if (tagf) {
            otrl_instag_read_FILEp(_userState, tagf);
            fclose(tagf);
        }
    }];
}

- (NSString*) documentsDirectory {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  return documentsDirectory;
}

- (NSString*) privateKeyPath {
  return [self.dataPath stringByAppendingPathComponent:kOTRKitPrivateKeyFileName];
}

- (NSString*) fingerprintsPath {
  return [self.dataPath stringByAppendingPathComponent:kOTRKitFingerprintsFileName];
}

- (NSString*) instanceTagsPath {
    return [self.dataPath stringByAppendingPathComponent:kOTRKitInstanceTagsFileName];
}

- (void) setMaximumProtocolSize:(NSUInteger)maxSize forProtocol:(NSString *)protocol {
    NSParameterAssert(protocol != nil);
    if (!protocol) { return; }
    [self performBlockAsync:^{
        [self.protocolMaxSize setObject:@(maxSize) forKey:protocol];
    }];
}

- (void) setCallbackQueue:(dispatch_queue_t)callbackQueue {
    if (!callbackQueue) { return; }
    [self performBlockAsync:^{
        _callbackQueue = callbackQueue;
    }];
}

- (dispatch_queue_t) callbackQueue {
    __block dispatch_queue_t callbackQueue = nil;
    [self performBlock:^{
        callbackQueue = _callbackQueue;
    }];
    return callbackQueue;
}

- (void) messagePoll:(NSTimer*)timer {
    [self performBlockAsync:^{
        if (self.userState) {
            OTROpData *opdata = [[OTROpData alloc] initWithOTRKit:self tag:nil];
            otrl_message_poll(_userState, &ui_ops, (__bridge void *)(opdata));
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [timer invalidate];
            });
        }
    }];
}

#pragma mark Key Generation
//////////////////////////////////////////////////////////////////////
/// @name Key Generation
//////////////////////////////////////////////////////////////////////

/**
 *  Initiates the generation of a new key pair for a given account/protocol, and optionally returns the fingerprint of the generated key via the completionBlock. If the key already exists this is a no-op that quickly returns the fingerprint (uppercase, without spaces).
 *
 *  @param accountName Your account name
 *  @param protocol the protocol of accountName, such as @"xmpp"
 *  @param completion optional.
 */
- (void) generatePrivateKeyForAccountName:(NSString*)accountName
                                 protocol:(NSString*)protocol
                               completion:(void (^)(OTRFingerprint *fingerprint, NSError *error))completionBlock {
    NSParameterAssert(accountName.length > 0);
    NSParameterAssert(protocol.length > 0);
    if (!accountName.length || !protocol.length) {
        if (completionBlock) {
            completionBlock(nil, [OTRErrorUtility errorForGPGError:GPG_ERR_INV_PARAMETER]);
        }
        return;
    }
    [self performBlockAsync:^{
        OTRFingerprint *fingerprint = [self fingerprintForAccountName:accountName protocol:protocol];
        if (!fingerprint) {
            OTROpData *opdata = [[OTROpData alloc] initWithOTRKit:self tag:nil];
            create_privkey_cb((__bridge void*)opdata, [accountName UTF8String], [protocol UTF8String]);
        }
        fingerprint = [self fingerprintForAccountName:accountName protocol:protocol];
        NSParameterAssert(fingerprint != nil);

        if (completionBlock) {
            dispatch_async(self.callbackQueue, ^{
                completionBlock(fingerprint, nil);
            });
        }
    }];
}

#pragma mark Messaging

- (void)decodeMessage:(NSString*)message
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag
{
    [self decodeMessage:message username:username accountName:accountName protocol:protocol tag:tag async:YES completion:^(NSString * _Nullable decodedMessage, NSArray<OTRTLV *> * _Nonnull tlvs, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
        if ([self.delegate respondsToSelector:@selector(otrKit:decodedMessage:tlvs:wasEncrypted:username:accountName:protocol:fingerprint:tag:error:)]) {
            [self.delegate otrKit:self
                   decodedMessage:decodedMessage
                             tlvs:tlvs
                     wasEncrypted:wasEncrypted
                         username:username
                      accountName:accountName
                         protocol:protocol
                      fingerprint:fingerprint
                              tag:tag
                            error:error];
        }
    }];
}

- (void)decodeMessage:(NSString*)message
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag
                async:(BOOL)async
           completion:(void (^)(NSString* _Nullable decodedMessage, NSArray<OTRTLV*>* tlvs, BOOL wasEncrypted, OTRFingerprint* _Nullable fingerprint, NSError* _Nullable error))completion {
    NSParameterAssert(message.length);
    NSParameterAssert(username.length);
    NSParameterAssert(accountName.length);
    NSParameterAssert(protocol.length);
    NSParameterAssert(completion != nil);
    if (![message length] || ![username length] || ![accountName length] || ![protocol length] || !completion) {
        return;
    }
    __block dispatch_block_t finishBlock = nil;
    dispatch_block_t decodeBlock = ^{
        int ignore_message;
        char *newmessage = NULL;
        ConnContext *context = [self contextForUsername:username accountName:accountName protocol:protocol];
        NSParameterAssert(context != NULL);
        if (!context) { return; } // Maybe don't fail silently here
        
        OTROpData *opdata = [[OTROpData alloc] initWithOTRKit:self tag:tag];
        
        OTRFingerprint *fingerprint = [self activeFingerprintForCurrentContext:context];
        if (fingerprint && fingerprint.trustLevel == OTRTrustLevelUnknown) {
            fingerprint = [self fixUnknownFingerprint:fingerprint];
        }
        
        OtrlTLV *otr_tlvs = NULL;
        ignore_message = otrl_message_receiving(_userState, &ui_ops, (__bridge void*)opdata, [accountName UTF8String], [protocol UTF8String], [username UTF8String], [message UTF8String], &newmessage, &otr_tlvs, &context, NULL, NULL);
        
        
        
        
        // Handle TLVs
        NSArray *tlvs = @[];
        if (otr_tlvs) {
            tlvs = [[self class] tlvArrayForTLVChain:otr_tlvs];
        }
        [tlvs enumerateObjectsUsingBlock:^(OTRTLV *tlv, NSUInteger idx, BOOL *stop) {
            OTRTLVType tlvType = tlv.type;
            id<OTRTLVHandler> handler = [self.tlvHandlers objectForKey:@(tlvType)];
            if (handler) {
                [handler receiveTLV:tlv username:username accountName:accountName protocol:protocol fingerprint:fingerprint tag:tag];
            }
        }];
        if (otr_tlvs) {
            otrl_tlv_free(otr_tlvs);
        }
        
        BOOL wasEncrypted = [OTRKit stringStartsWithOTRPrefix:message];
        NSString *decodedMessage = nil;
        if(ignore_message == 0 || !wasEncrypted)
        {
            if(newmessage) {
                decodedMessage = [NSString stringWithUTF8String:newmessage];
                otrl_message_free(newmessage);
            } else {
                decodedMessage = [message copy];
            }
        }
        
        NSError *error = nil;
        
        if (context) {
            if (context->msgstate == OTRL_MSGSTATE_FINISHED) {
                [self disableEncryptionWithUsername:username accountName:accountName protocol:protocol];
            }
        } else {
            // This happens when one side has a stale OTR session for the 1st message. Is it a bug in libotr?
            context = [self contextForUsername:username accountName:accountName protocol:protocol];
            if (context->msgstate == OTRL_MSGSTATE_PLAINTEXT && ignore_message == 1) {
                error = [OTRErrorUtility errorForGPGError:GPG_ERR_BAD_DATA];
            }
        }
        finishBlock = ^{
            completion(decodedMessage, tlvs, wasEncrypted, fingerprint, error);
        };
        if (async) {
            dispatch_async(self.callbackQueue, finishBlock);
        }
    };
    
    if (async) {
        [self performBlockAsync:decodeBlock];
    } else {
        [self performBlock:decodeBlock];
        finishBlock();
    }
}


- (void)encodeMessage:(nullable NSString*)message
                 tlvs:(nullable NSArray<OTRTLV*>*)tlvs
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag {
    [self encodeMessage:message tlvs:tlvs username:username accountName:accountName protocol:protocol tag:tag async:YES completion:^(NSString * _Nullable encodedMessage, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
        if ([self.delegate respondsToSelector:@selector(otrKit:encodedMessage:wasEncrypted:username:accountName:protocol:fingerprint:tag:error:)]) {
            [self.delegate otrKit:self encodedMessage:encodedMessage wasEncrypted:wasEncrypted username:username accountName:accountName protocol:protocol fingerprint:fingerprint tag:tag error:error];
        }
    }];
}

- (void)encodeMessage:(nullable NSString*)message
                 tlvs:(nullable NSArray<OTRTLV*>*)tlvs
             username:(NSString*)username
          accountName:(NSString*)accountName
             protocol:(NSString*)protocol
                  tag:(nullable id)tag
                async:(BOOL)async
           completion:(void (^)(NSString* _Nullable encodedMessage, BOOL wasEncrypted, OTRFingerprint* _Nullable fingerprint, NSError* _Nullable error))completion {
    NSParameterAssert(username);
    NSParameterAssert(accountName);
    NSParameterAssert(protocol);
    NSParameterAssert(completion);
    if (!username.length || !accountName.length || !protocol.length || !completion) {
        return;
    }
    // If you meant to send TLVs and message is nil,
    // libotr will ignore the encode. We fix it by
    // setting to empty string.
    if (message) {
        message = [message copy];
    } else if (tlvs.count) {
        message = @"";
    }
    __block dispatch_block_t finishBlock = nil;
    dispatch_block_t encodeBlock = ^{
        gcry_error_t err;
        char *newmessage = NULL;
        
        ConnContext *context = [self contextForUsername:username accountName:accountName protocol:protocol];
        NSParameterAssert(context);
        
        // Check trust
        OTRFingerprint *fingerprint = [self activeFingerprintForCurrentContext:context];
        if (fingerprint) {
            if (fingerprint.trustLevel == OTRTrustLevelUnknown) {
                fingerprint = [self fixUnknownFingerprint:fingerprint];
            }
            BOOL trusted = [self checkTrustForFingerprint:fingerprint];
            if (!trusted) {
                NSError *error = [OTRErrorUtility errorForGPGError:GPG_ERR_BAD_PUBKEY];
                finishBlock = ^{
                    completion(nil, NO, fingerprint, error);
                };
                if (async) {
                    dispatch_async(self.callbackQueue, finishBlock);
                }
                return;
            }
        }
        
        OtrlTLV *otr_tlvs = [[self class] tlvChainForTLVs:tlvs];
        OTROpData *opdata = [[OTROpData alloc] initWithOTRKit:self tag:tag];
        
        err = otrl_message_sending(_userState, &ui_ops, (__bridge void *)(opdata),
                                   [accountName UTF8String], [protocol UTF8String], [username UTF8String], OTRL_INSTAG_BEST, [message UTF8String], otr_tlvs, &newmessage, OTRL_FRAGMENT_SEND_SKIP, &context,
                                   NULL, NULL);
        if (otr_tlvs) {
            otrl_tlv_free(otr_tlvs);
        }
        
        BOOL wasEncrypted = NO;
        
        // If the there is a newmessage then send that otherweise OTR didn't need to modify the original message.
        NSString *encodedMessage = nil;
        if (newmessage) {
            encodedMessage = [NSString stringWithUTF8String:newmessage];
            otrl_message_free(newmessage);
            wasEncrypted = [OTRKit stringStartsWithOTRPrefix:encodedMessage];
        } else {
            encodedMessage = message;
        }
        
        NSError *error = nil;
        if (err != GPG_ERR_NO_ERROR) {
            error = [OTRErrorUtility errorForGPGError:err];
            encodedMessage = nil;
        }
        finishBlock = ^{
            completion(encodedMessage, wasEncrypted, fingerprint, error);
        };
        if (async) {
            dispatch_async(self.callbackQueue, finishBlock);
        }
    };
    
    if (async) {
        [self performBlockAsync:encodeBlock];
    } else {
        [self performBlock:encodeBlock];
        finishBlock();
    }
}

- (void)initiateEncryptionWithUsername:(NSString*)username
                           accountName:(NSString*)accountName
                              protocol:(NSString*)protocol
{
    [self encodeMessage:@"?OTRv23?" tlvs:nil username:username accountName:accountName protocol:protocol tag:nil async:YES completion:^(NSString * _Nullable encodedMessage, BOOL wasEncrypted, OTRFingerprint * _Nullable fingerprint, NSError * _Nullable error) {
        // Inject message directly to start encryption
        // We are already on callbackQueue in here
        // So safe to call delegate method directly
        [self.delegate otrKit:self injectMessage:encodedMessage username:username accountName:accountName protocol:protocol fingerprint:nil tag:nil];
    }];
}

- (void)disableEncryptionWithUsername:(NSString*)recipient
                          accountName:(NSString*)accountName
                             protocol:(NSString*)protocol {
    [self performBlockAsync:^{
        OTROpData *opdata = [[OTROpData alloc] initWithOTRKit:self tag:nil];
        otrl_message_disconnect_all_instances(_userState, &ui_ops, (__bridge void *)(opdata), [accountName UTF8String], [protocol UTF8String], [recipient UTF8String]);
        [self updateEncryptionStatusWithContext:[self contextForUsername:recipient accountName:accountName protocol:protocol]];
    }];
}

- (void)checkIfGeneratingKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol completion:(void (^)(BOOL isGeneratingKey))completion
{
    if (!accountName.length || !protocol.length) {
        if (completion) {
            dispatch_async(self.callbackQueue, ^{
                completion(NO);
            });
        }
        return;
    }
    [self performBlockAsync:^{
        __block void *newkeyp;
        __block gcry_error_t generateError;
        generateError = otrl_privkey_generate_start(_userState,[accountName UTF8String],[protocol UTF8String],&newkeyp);
        if (!generateError) {
            otrl_privkey_generate_cancelled(_userState, newkeyp);
        }
        BOOL keyExists = generateError == gcry_error(GPG_ERR_EEXIST);
        if (completion) {
            dispatch_async(self.callbackQueue, ^{
                completion(keyExists);
            });
        }
    }];
}

- (void) updateEncryptionStatusWithContext:(ConnContext*)context {
    NSParameterAssert(context != nil);
    if (!context) { return; }
    if ([self.delegate respondsToSelector:@selector(otrKit:updateMessageState:username:accountName:protocol:fingerprint:)]) {
        NSString *username = [NSString stringWithUTF8String:context->username];
        NSString *accountName = [NSString stringWithUTF8String:context->accountname];
        NSString *protocol = [NSString stringWithUTF8String:context->protocol];
        OTRFingerprint *fingerprint = [self activeFingerprintForCurrentContext:context];
        if (fingerprint && fingerprint.trustLevel == OTRTrustLevelUnknown) {
            fingerprint = [self fixUnknownFingerprint:fingerprint];
        }
        OTRKitMessageState messageState = [self messageStateForUsername:username accountName:accountName protocol:protocol];
        dispatch_async(self.callbackQueue, ^{
            [self.delegate otrKit:self updateMessageState:messageState username:username accountName:accountName protocol:protocol fingerprint:fingerprint];
        });
    }
}

- (OTRKitMessageState)messageStateForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol {
    NSParameterAssert(username.length);
    NSParameterAssert(accountName.length);
    NSParameterAssert(protocol.length);
    if (!username.length || !accountName.length || !protocol.length) {
        return OTRKitMessageStateUnknown;
    }
    __block OTRKitMessageState messageState = OTRKitMessageStateUnknown;
    [self performBlock:^{
        ConnContext *context = [self contextForUsername:username accountName:accountName protocol:protocol];
        if (context) {
            switch (context->msgstate) {
                case OTRL_MSGSTATE_ENCRYPTED:
                    messageState = OTRKitMessageStateEncrypted;
                    break;
                case OTRL_MSGSTATE_FINISHED:
                    messageState = OTRKitMessageStateFinished;
                    break;
                case OTRL_MSGSTATE_PLAINTEXT:
                    messageState = OTRKitMessageStatePlaintext;
                    break;
                default:
                    messageState = OTRKitMessageStateUnknown;
                    break;
            }
        }
    }];
    return messageState;
}


#pragma mark Internal Messing Methods

- (nullable ConnContext*) rootContextForContext:(ConnContext*)context {
    // Get root context so fingerprint fetching is more useful
    NSParameterAssert(context != nil);
    if (!context) { return NULL; }
    while (context != context->m_context) {
        context = context->m_context;
    }
    return context;
}

- (nullable ConnContext*) contextForUsername:(NSString*)username accountName:(NSString*)accountName protocol:(NSString*) protocol {
    NSParameterAssert(username.length);
    NSParameterAssert(accountName.length);
    NSParameterAssert(protocol.length);
    NSParameterAssert(_userState);
    if (!username.length || !accountName.length || !protocol.length || !_userState) {
        return NULL;
    }
    const char *username_str = [username UTF8String];
    const char *account_str = [accountName UTF8String];
    const char *protocol_str = [protocol UTF8String];
    NSParameterAssert(username_str != NULL);
    NSParameterAssert(account_str != NULL);
    NSParameterAssert(protocol_str != NULL);
    if (!username_str || !account_str || !protocol_str) {
        return NULL;
    }
    ConnContext *context = otrl_context_find(_userState, username_str, account_str, protocol_str, OTRL_INSTAG_BEST, YES, NULL, NULL, NULL);
    NSParameterAssert(context != NULL);
    return context;
}

#pragma mark OTR Policy

-(OTRKitPolicy)otrPolicy {
    __block OTRKitPolicy otrPolicy = OTRKitPolicyDefault;
    [self performBlock:^{
        otrPolicy = _otrPolicy;
    }];
    return otrPolicy;
}

- (void) setOtrPolicy:(OTRKitPolicy)otrPolicy {
    [self performBlockAsync:^{
        _otrPolicy = otrPolicy;
    }];
}

-(OtrlPolicy)otrlPolicy {
    switch (self.otrPolicy) {
        case OTRKitPolicyDefault:
            return OTRL_POLICY_DEFAULT;
            break;
        case OTRKitPolicyAlways:
            return OTRL_POLICY_ALWAYS;
            break;
        case OTRKitPolicyManual:
            return OTRL_POLICY_MANUAL;
            break;
        case OTRKitPolicyOpportunistic:
            return OTRL_POLICY_OPPORTUNISTIC;
            break;
        case OTRKitPolicyNever:
            return OTRL_POLICY_NEVER;
            break;
        default:
            return OTRL_POLICY_DEFAULT;
            break;
    }
}

#pragma mark Fingerprints

- (NSArray<OTRFingerprint*>*) allFingerprints {
    NSMutableArray<OTRFingerprint*> *allFingerprints = [NSMutableArray array];
    [self performBlock:^{
        ConnContext * context = _userState->context_root;
        while (context) {
            Fingerprint * fingerprint = context->fingerprint_root.next;
            while (fingerprint) {
                OTRFingerprint *otrFingerprint = [self fingerprintForInternalFingerprint:fingerprint];
                [allFingerprints addObject:otrFingerprint];
                fingerprint = fingerprint->next;
            }
            context = context->next;
        }
    }];
    return allFingerprints;
}

/** Synchronously fetches your own fingerprint. */
- (nullable OTRFingerprint*)fingerprintForAccountName:(NSString*)accountName
                                             protocol:(NSString*)protocol {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    if (!accountName || !protocol) {
        return nil;
    }
    __block NSData *fingerprintData = nil;
    [self performBlock:^{
        NSMutableData *fingerprintDataBuffer = [NSMutableData dataWithLength:kOTRKitFingerprintBytes];
        if (!fingerprintDataBuffer) {
            return;
        }
        unsigned char *fingerprint = otrl_privkey_fingerprint_raw(_userState, fingerprintDataBuffer.mutableBytes, [accountName UTF8String], [protocol UTF8String]);
        if (!fingerprint) {
            return;
        }
        fingerprintData = fingerprintDataBuffer;
    }];
    if (!fingerprintData) {
        return nil;
    }
    OTRFingerprint *fingerprint = [[OTRFingerprint alloc] initWithUsername:accountName accountName:accountName protocol:protocol fingerprint:fingerprintData trustLevel:OTRTrustLevelTrustedUser];
    return fingerprint;
}

/** Synchronously fetches all fingerprints known for a given user */
- (NSArray<OTRFingerprint*>*) fingerprintsForUsername:(NSString*)username
                                          accountName:(NSString*)accountName
                                             protocol:(NSString*)protocol {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(username != nil);
    if (!accountName || !protocol || !username) {
        return @[];
    }
    NSMutableArray<OTRFingerprint*> *fingerprintsArray = [[NSMutableArray alloc] init];
    [self enumerateInternalFingerprintsForUsername:username accountName:accountName protocol:protocol block:^(Fingerprint *fingerprint, BOOL *stop) {
        OTRFingerprint *otrFingerprint = [self fingerprintForInternalFingerprint:fingerprint];
        [fingerprintsArray addObject:otrFingerprint];
    }];
    return fingerprintsArray;
}

/** Synchronously fetches fingerprint used in the current session with user. */
- (nullable OTRFingerprint*)activeFingerprintForUsername:(NSString*)username
                                             accountName:(NSString*)accountName
                                                protocol:(NSString*)protocol {
    __block OTRFingerprint *fingerprint = nil;
    [self performBlock:^{
        Fingerprint * rawFingerprint = [self internalActiveFingerprintForUsername:username accountName:accountName protocol:protocol];
        if (!rawFingerprint) { return; }
        fingerprint = [self fingerprintForInternalFingerprint:rawFingerprint];
    }];
    return fingerprint;
}



/** Update a fingerprint's trust status, or store a new one. */
- (void) saveFingerprint:(OTRFingerprint*)fingerprint {
    NSParameterAssert(fingerprint != nil);
    if (!fingerprint) { return; }
    NSString *username = fingerprint.username;
    NSString *accountName = fingerprint.accountName;
    NSString *protocol = fingerprint.protocol;
    NSData *fingerprintData = fingerprint.fingerprint;
    [self performBlock:^{
        Fingerprint * internalFingerprint = [self internalFingerprintForUsername:username accountName:accountName protocol:protocol fingerprintData:fingerprintData];
        NSString *trustLavelString = [[self class] stringForTrustLevel:fingerprint.trustLevel];
        const char * newTrust = [trustLavelString UTF8String];
        if (internalFingerprint)
        {
            otrl_context_set_trust(internalFingerprint, newTrust);
            [self writeFingerprints];
        }
    }];
}

/** Delete fingerprint from the trust store */
- (BOOL) deleteFingerprint:(OTRFingerprint*)fingerprint error:(NSError**)error {
    NSParameterAssert(fingerprint != nil);
    __block BOOL result = NO;
    __block NSError *outError = nil;
    NSString *username = fingerprint.username;
    NSString *accountName = fingerprint.accountName;
    NSString *protocol = fingerprint.protocol;
    NSData *fingerprintData = fingerprint.fingerprint;
    [self performBlock:^{
        ConnContext * context = [self contextForUsername:username accountName:accountName protocol:protocol];
        if (!context) {
            outError = [OTRErrorUtility errorForGPGError:GPG_ERR_INV_PARAMETER];
            return;
        }
        // Get root context if we're a child context
        context = [self rootContextForContext:context];
        Fingerprint * targetFingerprint = [self internalFingerprintForUsername:username accountName:accountName protocol:protocol fingerprintData:fingerprintData];
        if (targetFingerprint) {
            //will not delete if it is the active fingerprint;
            otrl_context_forget_fingerprint(targetFingerprint, 0);
            [self writeFingerprints];
            result = YES;
        } else {
            outError = [OTRErrorUtility errorForGPGError:GPG_ERR_INV_PARAMETER];
        }
    }];
    if (error) {
        *error = outError;
    }
    return result;
}


#pragma mark Internal Fingerprint Methods

- (BOOL) checkTrustForFingerprint:(OTRFingerprint*)fingerprint {
    NSParameterAssert(fingerprint != nil);
    if (!fingerprint) { return NO; }
    __block BOOL trust = NO;
    if ([self.delegate respondsToSelector:@selector(otrKit:evaluateTrustForFingerprint:)]) {
        dispatch_sync(self.callbackQueue, ^{
            trust = [self.delegate otrKit:self evaluateTrustForFingerprint:fingerprint];
        });
    } else {
        trust = fingerprint.isTrusted;
    }
    return trust;
}

- (nullable OTRFingerprint*)fingerprintForInternalFingerprint:(Fingerprint*)fingerprint {
    if (!fingerprint) { return nil; }
    if (!fingerprint->context) { return nil; }
    NSString * username = [NSString stringWithUTF8String:fingerprint->context->username];
    NSString * accountName = [NSString stringWithUTF8String:fingerprint->context->accountname];
    NSString * protocol = [NSString stringWithUTF8String:fingerprint->context->protocol];
    NSString *trust = nil;
    if (fingerprint->trust) {
        trust = [NSString stringWithUTF8String:fingerprint->trust];
    }
    /** Raw fingerprints are always 20 bytes */
    NSData * fingerprintData = [NSData dataWithBytes:fingerprint->fingerprint length:kOTRKitFingerprintBytes];
    OTRTrustLevel trustLevel = [[self class] trustLevelForString:trust];
    OTRFingerprint *otrFingerprint = [[OTRFingerprint alloc] initWithUsername:username accountName:accountName protocol:protocol fingerprint:fingerprintData trustLevel:trustLevel];
    return otrFingerprint;
}

- (nullable OTRFingerprint*)activeFingerprintForCurrentContext:(ConnContext*)context {
    NSParameterAssert(context != nil);
    if (!context) { return nil; }
    return [self fingerprintForInternalFingerprint:context->active_fingerprint];
}

/** Must be called from performBlock/performBlockAsync to schedule on internalQueue */
- (nullable Fingerprint *)internalActiveFingerprintForUsername:(NSString*)username accountName:(NSString*)accountName protocol:(NSString*) protocol {
    Fingerprint * fingerprint = nil;
    ConnContext *context = [self contextForUsername:username accountName:accountName protocol:protocol];
    if(context)
    {
        fingerprint = context->active_fingerprint;
    }
    return fingerprint;
}

/** Enumerate all the internal fingerprints attached to the root context of the username/accounName/protocol*/
- (void)enumerateInternalFingerprintsForUsername:(NSString*)username
                                     accountName:(NSString*)accountName
                                        protocol:(NSString*)protocol
                                           block:(void (^)(Fingerprint *fingerprint, BOOL *stop))block {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(username != nil);
    NSParameterAssert(block != nil);
    if (!accountName || !protocol || !username || !block) {
        return;
    }
    
    [self performBlock:^{
        ConnContext *context = [self rootContextForContext:[self contextForUsername:username accountName:accountName protocol:protocol]];
        if(context)
        {
            Fingerprint *fingerprint = context->fingerprint_root.next;
            BOOL stop = NO;
            while (fingerprint != NULL && !stop) {
                block(fingerprint,&stop);
                fingerprint = fingerprint->next;
            }
        }
    }];
}

/** 
 * Enumerates over all fingerprints until it gets to one where teh fingerprint data matches.
 * Must be called from performBlock/performBlockAsync to schedule on internalQueue 
 */
- (nullable Fingerprint *)internalFingerprintForUsername:(NSString*)username accountName:(NSString*)accountName protocol:(NSString*) protocol fingerprintData:(NSData *)fingerprintData {
    __block Fingerprint * finalFingerprint = nil;
    [self enumerateInternalFingerprintsForUsername:username accountName:accountName protocol:protocol block:^(Fingerprint *fingerprint, BOOL *stop) {
        NSData *internalData = [NSData dataWithBytes:fingerprint->fingerprint length:kOTRKitFingerprintBytes];
        if ([internalData isEqual:fingerprintData]) {
            *stop = YES;
            finalFingerprint = fingerprint;
        }
    }];
    return finalFingerprint;
}

/** Must be called from performBlock/performBlockAsync to schedule on internalQueue */
-(void)writeFingerprints
{
    FILE *storef = NULL;
    NSString *path = [self fingerprintsPath];
    storef = fopen([path UTF8String], "wb");
    if (!storef) return;
    otrl_privkey_write_fingerprints_FILEp(_userState, storef);
    fclose(storef);
}

- (OTRFingerprint *)fixUnknownFingerprint:(OTRFingerprint *)fingerprint {
    NSArray<OTRFingerprint*> *existingFingerprints = [self fingerprintsForUsername:fingerprint.username accountName:fingerprint.accountName protocol:fingerprint.protocol];
    // Trust if this is the first fingerprint for this user,
    if (existingFingerprints.count == 1) {
        OTRFingerprint *existing = [existingFingerprints firstObject];
        if ([existing.fingerprint isEqualToData:fingerprint.fingerprint] &&
            fingerprint.trustLevel == OTRTrustLevelUnknown &&
            existing.trustLevel == OTRTrustLevelUnknown) {
            fingerprint.trustLevel = OTRTrustLevelTrustedTofu;
            [self saveFingerprint:fingerprint];
        }
        // If it's not the first fingerprint, mark as new untrusted
    } else if (existingFingerprints.count > 1 && fingerprint.trustLevel == OTRTrustLevelUnknown) {
        fingerprint.trustLevel = OTRTrustLevelUntrustedNew;
        [self saveFingerprint:fingerprint];
    } else {
        fingerprint.trustLevel = OTRTrustLevelTrustedTofu;
        [self saveFingerprint:fingerprint];
    }
    return fingerprint;
}

#pragma mark Symmetric Key

- (nullable NSData*) requestSymmetricKeyForUsername:(NSString*)username
                                        accountName:(NSString*)accountName
                                           protocol:(NSString*)protocol
                                             forUse:(NSUInteger)use
                                            useData:(nullable NSData*)useData
                                              error:(NSError**)error {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(username != nil);
    if (!accountName || !protocol || !username) {
        if (error) {
            *error = [OTRErrorUtility errorForGPGError:GPG_ERR_INV_PARAMETER];
        }
        return nil;
    }
    __block NSData *keyData = nil;
    __block NSError *outError = nil;
    [self performBlock:^{
        ConnContext * context = [self contextForUsername:username accountName:accountName protocol:protocol];
        NSError *outError = nil;
        if (context) {
            NSMutableData *symKey = [NSMutableData dataWithLength:OTRL_EXTRAKEY_BYTES];
            gcry_error_t err = otrl_message_symkey(self.userState, &ui_ops, NULL, context, (unsigned int)use, useData.bytes, useData.length, symKey.mutableBytes);
            if (err != gcry_err_code(GPG_ERR_NO_ERROR)) {
                outError = [OTRErrorUtility errorForGPGError:err];
            } else {
                keyData = symKey;
            }
        } else {
            outError = [OTRErrorUtility errorForGPGError:GPG_ERR_INV_PARAMETER];
        }
    }];
    if (error) {
        *error = outError;
    }
    return keyData;
}

#pragma mark SMP

- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                         secret:(NSString*)secret {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(secret != nil);
    NSParameterAssert(username != nil);
    if (!secret || !accountName || !protocol || !username) {
        return;
    }
    [self performBlockAsync:^{
        ConnContext * context = [self contextForUsername:username accountName:accountName protocol:protocol];
        if (!context) {
            return;
        }
        otrl_message_initiate_smp(self.userState, &ui_ops, NULL, context, (const unsigned char*)[secret UTF8String], [secret lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    }];
}

- (void) initiateSMPForUsername:(NSString*)username
                    accountName:(NSString*)accountName
                       protocol:(NSString*)protocol
                       question:(NSString*)question
                         secret:(NSString*)secret {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(secret != nil);
    NSParameterAssert(username != nil);
    NSParameterAssert(question != nil);
    if (!secret || !accountName || !protocol || !username || !question) {
        return;
    }
    [self performBlockAsync:^{
        ConnContext * context = [self contextForUsername:username accountName:accountName protocol:protocol];
        if (!context) {
            return;
        }
        otrl_message_initiate_smp_q(self.userState, &ui_ops, NULL, context, [question UTF8String], (const unsigned char*)[secret UTF8String], [secret lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    }];
}

- (void) respondToSMPForUsername:(NSString*)username
                     accountName:(NSString*)accountName
                        protocol:(NSString*)protocol
                          secret:(NSString*)secret {
    NSParameterAssert(accountName != nil);
    NSParameterAssert(protocol != nil);
    NSParameterAssert(secret != nil);
    NSParameterAssert(username != nil);
    if (!secret || !accountName || !protocol || !username) {
        return;
    }
    [self performBlockAsync:^{
        ConnContext * context = [self contextForUsername:username accountName:accountName protocol:protocol];
        if (!context) {
            return;
        }
        otrl_message_respond_smp(self.userState, &ui_ops, NULL, context, (const unsigned char*)[secret UTF8String], [secret lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    }];
}

#pragma mark TLV Handlers


- (void) registerTLVHandler:(id<OTRTLVHandler>)handler {
    NSParameterAssert(handler != nil);
    if (!handler) {
        return;
    }
    [self performBlockAsync:^{
        NSArray *handledTypes = [handler handledTLVTypes];
        [handledTypes enumerateObjectsUsingBlock:^(NSNumber *type, NSUInteger idx, BOOL *stop) {
            [self.tlvHandlers setObject:handler forKey:type];
        }];
    }];
}

+ (OtrlTLV*)tlvChainForTLVs:(NSArray<OTRTLV*>*)tlvs {
    if (!tlvs || !tlvs.count) {
        return NULL;
    }
    OtrlTLV *root_tlv = NULL;
    OtrlTLV *current_tlv = NULL;
    NSUInteger validTLVCount = 0;
    for (OTRTLV *tlv in tlvs) {
        if (!tlv.isValidLength) {
            continue;
        }
        OtrlTLV *new_tlv = otrl_tlv_new(tlv.type, tlv.data.length, tlv.data.bytes);
        if (validTLVCount == 0) {
            root_tlv = new_tlv;
        } else {
            current_tlv->next = new_tlv;
        }
        current_tlv = new_tlv;
        validTLVCount++;
    }
    return root_tlv;
}

+ (NSArray<OTRTLV*>*)tlvArrayForTLVChain:(OtrlTLV*)tlv_chain {
    if (!tlv_chain) {
        return @[];
    }
    NSMutableArray *tlvArray = [NSMutableArray array];
    OtrlTLV *current_tlv = tlv_chain;
    while (current_tlv) {
        NSData *tlvData = [NSData dataWithBytes:current_tlv->data length:current_tlv->len];
        OTRTLVType type = current_tlv->type;
        OTRTLV *tlv = [[OTRTLV alloc] initWithType:type data:tlvData];
        [tlvArray addObject:tlv];
        current_tlv = current_tlv->next;
    }
    return tlvArray;
}

#pragma mark Utility Methods

+ (BOOL) stringStartsWithOTRPrefix:(NSString*)string {
    return [string hasPrefix:@"?OTR"];
}

+ (NSString*) libotrVersion {
    return [NSString stringWithUTF8String:otrl_version()];
}

+ (NSString *) libgcryptVersion
{
    return [NSString stringWithUTF8String:gcry_check_version(NULL)];
}

+ (NSString *) libgpgErrorVersion
{
    return [NSString stringWithUTF8String:gpg_error_check_version(NULL)];
}

#pragma mark Internal Utilities

/** Will perform block synchronously on the internalQueue and block for result if called on another queue. */
- (void) performBlock:(dispatch_block_t)block {
    NSParameterAssert(block != nil);
    if (!block) { return; }
    if (dispatch_get_specific(IsOnInternalQueueKey)) {
        block();
    } else {
        dispatch_sync(_internalQueue, block);
    }
}

/** Will perform block asynchronously on the internalQueue, unless we're already on internalQueue */
- (void) performBlockAsync:(dispatch_block_t)block {
    NSParameterAssert(block != nil);
    if (!block) { return; }
    if (dispatch_get_specific(IsOnInternalQueueKey)) {
        block();
    } else {
        dispatch_async(_internalQueue, block);
    }
}

/** Used internally. Stringified version of trustLevel */
+ (NSString*) stringForTrustLevel:(OTRTrustLevel)trustLevel {
    NSString *trustLevelString = @"";
    switch (trustLevel) {
        case OTRTrustLevelUntrustedNew:
            trustLevelString = @"UntrustedNew";
            break;
        case OTRTrustLevelUntrustedUser:
            trustLevelString = @"UntrustedUser";
            break;
        case OTRTrustLevelTrustedTofu:
            trustLevelString = @"TrustedTofu";
            break;
        case OTRTrustLevelTrustedUser:
            trustLevelString = @"TrustedUser";
            break;
        case OTRTrustLevelUnknown:
            trustLevelString = @"";
            break;
        default:
            trustLevelString = @"";
            break;
    }
    return trustLevelString;
}

/** If unknown returns untrusted */
+ (OTRTrustLevel) trustLevelForString:(NSString*)trustString {
    if (!trustString.length) { return OTRTrustLevelUnknown; }
    OTRTrustLevel trustLevel = OTRTrustLevelUnknown;
    if ([trustString isEqualToString:@"UntrustedUser"]) {
        trustLevel = OTRTrustLevelUntrustedUser;
    } else if ([trustString isEqualToString:@"UntrustedNew"]) {
        trustLevel = OTRTrustLevelUntrustedNew;
    } else if ([trustString isEqualToString:@"TrustedUser"]) {
        trustLevel = OTRTrustLevelTrustedUser;
    } else if ([trustString isEqualToString:@"TrustedTofu"]) {
        trustLevel = OTRTrustLevelTrustedTofu;
    } else if ([trustString isEqualToString:@""]) {
        trustLevel = OTRTrustLevelUnknown;
    } else if ([trustString isEqualToString:@"verified"]) {
        // This is for legacy purposes
        trustLevel = OTRTrustLevelTrustedUser;
    }
    return trustLevel;
}

@end
