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

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
  // Note: You may need to add the CFNetwork Framework to your project
  #import <CFNetwork/CFNetwork.h>
#endif

#define OTRHTTPVersion1_0  ((NSString *)kCFHTTPVersion1_0)
#define OTRHTTPVersion1_1  ((NSString *)kCFHTTPVersion1_1)


@interface OTRHTTPMessage : NSObject

/**
 *  Creates empty HTTP message.
 */
- (instancetype)initEmptyRequest;

/**
 *  Initializes empty HTTP response.
 *
 *  @param method  The request method for the request. Use any of the request methods allowed by the HTTP version specified by httpVersion.
 *  @param url     The URL to which the request will be sent.
 *  @param version     The HTTP version for this message response. Pass kCFHTTPVersion1_0 or kCFHTTPVersion1_1.
 */
- (instancetype)initRequestWithMethod:(NSString *)method url:(NSURL *)url version:(NSString *)version;

/**
 *  Initializes empty HTTP response.
 *
 *  @param code        The status code for this message response. The status code can be any of the status codes defined in section 6.1.1 of RFC 2616.
 *  @param description The description that corresponds to the status code. Pass NULL to use the standard description for the given status code, as found in RFC 2616.
 *  @param version     The HTTP version for this message response. Pass OTRHTTPVersion1_0 or OTRHTTPVersion1_1.
 */
- (instancetype)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version;

/**
 *  Appends data to HTTP message.
 *  @param data data to append
 *  @return success of operation
 */
- (BOOL)appendData:(NSData *)data;

/**
 *  Whether or not HTTP header is valid and complete.
 */
@property (nonatomic, readonly) BOOL isHeaderComplete;

/**
 *  HTTP version: 1.0 or 1.1
 */
@property (nonatomic, readonly) NSString *HTTPVersion;

/**
 *  e.g. GET / POST / PUT / DELETE
 */
@property (nonatomic, readonly) NSString *HTTPMethod;

/**
 *  URL of request or response
 */
@property (nonatomic, copy, readonly) NSURL *url;

/**
 *  HTTP status code (e.g. 200)
 */
@property (nonatomic, readonly) NSInteger HTTPStatusCode;

/*!
 @abstract Returns a dictionary containing all the HTTP header fields
 of the receiver.
 @result a dictionary containing all the HTTP header fields of the
 receiver.
 */
@property (nonatomic, readonly, copy) NSDictionary *allHTTPHeaderFields;

/*!
 @method valueForHTTPHeaderField:
 @abstract Returns the value which corresponds to the given header
 field. Note that, in keeping with the HTTP RFC, HTTP header field
 names are case-insensitive.
 @param field the header field name to use for the lookup
 (case-insensitive).
 @result the value associated with the given header field, or nil if
 there is no value associated with the given header field.
 */
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/*!
 @method setValue:forHTTPHeaderField:
 @abstract Sets the value of the given HTTP header field.
 @discussion If a value was previously set for the given header
 field, that value is replaced with the given value. Note that, in
 keeping with the HTTP RFC, HTTP header field names are
 case-insensitive.
 @param value the header field value.
 @param field the header field name (case-insensitive).
 */
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/*!
 @abstract Sets the request body data of the receiver.
 @discussion This data is sent as the message body of the request, as
 in done in an HTTP POST request.
 */
@property (nonatomic, copy, readwrite) NSData *HTTPBody;

/**
 *  Fully serialized version of HTTP message.
 */
@property (nonatomic, copy, readonly) NSData *HTTPMessageData;

@end
