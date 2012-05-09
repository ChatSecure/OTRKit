/*
 * OTRMessage.m
 * OTRKit
 *
 * Created by Chris Ballinger on 9/11/11.
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

#import "OTRMessage.h"

@implementation OTRMessage

@synthesize sender;
@synthesize recipient;
@synthesize message;
@synthesize protocol;

-(id)initWithSender:(NSString*)theSender recipient:(NSString*)theRecipient message:(NSString*)theMessage protocol:(NSString*)theProtocol
{
    if(self = [super init])
    {
        if(theSender)
            sender = theSender;
        else
            sender = theRecipient;
        recipient = theRecipient;
        message = theMessage;
        protocol = theProtocol;
    }
    return self;
}

+(OTRMessage*)messageWithSender:(NSString*)sender recipient:(NSString*)recipient message:(NSString*)message protocol:(NSString*)protocol
{
    OTRMessage *newMessage = [[OTRMessage alloc] initWithSender:sender recipient:recipient message:message protocol:protocol];
    
    return newMessage;
}

+(void)printDebugMessageInfo:(OTRMessage*)messageInfo;
{
#ifdef DEBUG
    NSLog(@"S:%@ R:%@ M:%@ P:%@",messageInfo.sender,messageInfo.recipient,messageInfo.message,messageInfo.protocol);
#endif
}

+(void)sendMessage:(OTRMessage *)message
{        
    [[NSNotificationCenter defaultCenter] postNotificationName:OTRSendMessageNotification object:message];
}

@end
