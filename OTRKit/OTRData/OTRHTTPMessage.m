/**
 * The HTTPMessage class is a simple Objective-C wrapper around Apple's CFHTTPMessage class.
 * From Robbie Hanson's CocoaHTTPServer https://github.com/robbiehanson/CocoaHTTPServer
 * Software License Agreement (BSD License)
 
 Copyright (c) 2011, Deusty, LLC
 All rights reserved.
 
 Redistribution and use of this software in source and binary forms,
 with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above
 copyright notice, this list of conditions and the
 following disclaimer.
 
 * Neither the name of Deusty nor the names of its
 contributors may be used to endorse or promote products
 derived from this software without specific prior
 written permission of Deusty, LLC.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 **/

#import "OTRHTTPMessage.h"
#import "OTRDataHandler.h"

@interface OTRHTTPMessage()
@property (nonatomic) CFHTTPMessageRef message;
@property (nonatomic, strong) NSURL *requestURL;
@end

@implementation OTRHTTPMessage
@dynamic HTTPBody;
@dynamic HTTPMessageData;
@dynamic HTTPStatusCode;
@dynamic isHeaderComplete;
@dynamic HTTPVersion;
@dynamic HTTPMethod;
@dynamic url;

- (id)initEmptyRequest
{
	if ((self = [super init]))
	{
		_message = CFHTTPMessageCreateEmpty(NULL, YES);
	}
	return self;
}

- (id)initRequestWithMethod:(NSString *)method url:(NSURL *)url version:(NSString *)version
{
	if ((self = [super init]))
	{
        _requestURL = url;
		_message = CFHTTPMessageCreateRequest(NULL,
		                                    (__bridge CFStringRef)method,
		                                    (__bridge CFURLRef)url,
		                                    (__bridge CFStringRef)version);
	}
	return self;
}

- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version
{
	if ((self = [super init]))
	{
		_message = CFHTTPMessageCreateResponse(NULL,
		                                      (CFIndex)code,
		                                      (__bridge CFStringRef)description,
		                                      (__bridge CFStringRef)version);
	}
	return self;
}

- (void)dealloc
{
	if (_message)
	{
		CFRelease(_message);
	}
}

- (BOOL)appendData:(NSData *)data
{
	return CFHTTPMessageAppendBytes(_message, [data bytes], [data length]);
}

- (BOOL)isHeaderComplete
{
	return CFHTTPMessageIsHeaderComplete(_message);
}

- (NSString *)HTTPVersion
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyVersion(_message);
}

- (NSString *)HTTPMethod
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyRequestMethod(_message);
}

- (NSURL *)url
{
	return (__bridge_transfer NSURL *)CFHTTPMessageCopyRequestURL(_message);
}

- (NSInteger)statusCode
{
	return (NSInteger)CFHTTPMessageGetResponseStatusCode(_message);
}

- (NSDictionary *)allHTTPHeaderFields
{
	return (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(_message);
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyHeaderFieldValue(_message, (__bridge CFStringRef)field);
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
{
	CFHTTPMessageSetHeaderFieldValue(_message,
	                                 (__bridge CFStringRef)field,
	                                 (__bridge CFStringRef)value);
}

- (NSData *)HTTPMessageData
{
    NSData *messageData = (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(_message);
    if (!self.requestURL) {
        return messageData;
    }
    
    // This is to work around a 'bug' in Apple's HTTP parser where it doesn't handle
    // funky URL schemes (otr-in-band) required for compatibility with the Android version of OTRDATA
    //
    //  OFFER otr-in-band:/storage/IMG_20141224_160749%281%29.jpg HTTP/1.1
    //  Request-Id: 2ee20a87-7ef0-46dd-8ada-49e3e31f2124
    //  File-Length: 1208869
    //  File-Hash-SHA1: c1b279ff4e7afe00f0ca26bc41003087b71f5786
    //  Mime-Type: image/jpeg
    //
    // Apple's library will result in the first line reading:
    //
    //  OFFER /storage/IMG_20141224_160749%281%29.jpg HTTP/1.1
    //  Request-Id: 2ee20a87-7ef0-46dd-8ada-49e3e31f2124
    //  ...
    //
    // Which breaks the Android implementation because everything is keyed to the URL, not the request UUID.
    
    if (![self.requestURL.scheme isEqualToString:kOTRDataHandlerURLScheme]) {
        return messageData;
    }
    
    NSString *messageString = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
    NSString *replacementString = [NSString stringWithFormat:@"%@:/", kOTRDataHandlerURLScheme];
    NSRange range = [messageString rangeOfString:@"/"];
    NSString *replacedMessageString = [messageString stringByReplacingCharactersInRange:range withString:replacementString];
    messageData = [replacedMessageString dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"message: %@", messageString);
    return messageData;
}

- (NSData *)HTTPBody
{
	return (__bridge_transfer NSData *)CFHTTPMessageCopyBody(_message);
}

- (void)setHTTPBody:(NSData *)body
{
	CFHTTPMessageSetBody(_message, (__bridge CFDataRef)body);
}

- (NSString*) description {
    return [[NSString alloc] initWithData:[self HTTPMessageData] encoding:NSUTF8StringEncoding];
}

@end
