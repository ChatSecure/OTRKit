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
#import "message.h"
#import "privkey.h"

static OTRKit *sharedKit = nil;

#define PRIVKEYFNAME @"otr.private_key"
#define STOREFNAME @"otr.fingerprints"

@implementation OTRKit
@synthesize userState;

-(id)init
{
    if(self = [super init])
    {
        // initialize OTR
        OTRL_INIT;
        userState = otrl_userstate_create();
        //s_OTR_userState = userState;
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        //otrl_privkey_read(OTR_userState,"privkeyfilename");
        FILE *privf;
        NSString *path = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@",PRIVKEYFNAME]];
        privf = fopen([path UTF8String], "rb");
        
        if(privf)
            otrl_privkey_read_FILEp(userState, privf);
        fclose(privf);
        
        //otrl_privkey_read_fingerprints(OTR_userState, "fingerprintfilename", NULL, NULL);
        FILE *storef;
        path = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@",STOREFNAME]];
        storef = fopen([path UTF8String], "rb");
        
        if (storef)
            otrl_privkey_read_fingerprints_FILEp(userState, storef, NULL, NULL);
        fclose(storef);
    }
    
    return self;
}

#pragma mark -
#pragma mark Singleton Object Methods

+ (OTRKit*)sharedInstance {
    @synchronized(self) {
        if (sharedKit == nil) {
            sharedKit = [[self alloc] init];
        }
    }
    return sharedKit;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedKit == nil) {
            sharedKit = [super allocWithZone:zone];
            return sharedKit;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end