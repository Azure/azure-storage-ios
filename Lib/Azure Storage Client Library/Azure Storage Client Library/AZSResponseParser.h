// -----------------------------------------------------------------------------------------
// <copyright file="AZSResponseParser.h" company="Microsoft">
//    Copyright 2015 Microsoft Corporation
//
//    Licensed under the MIT License;
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//      http://spdx.org/licenses/MIT
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// </copyright>
// -----------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>
@class AZSRequestResult;
@class AZSOperationContext;

@interface AZSStorageXMLParserDelegate : NSObject <NSXMLParserDelegate>
@property (copy) void(^parseBeginElement)(NSXMLParser * parser, NSString * elementName, NSDictionary * attributes);
@property (copy) void(^parseEndElement)(NSXMLParser * parser, NSString * elementName);
@property (copy) void(^foundCharacters)(NSXMLParser * parser, NSString * characters);

@end


@interface AZSResponseParser : NSObject
+(id)preprocessResponseWithResponse:(NSHTTPURLResponse *)response requestResult:(AZSRequestResult *)requestResult operationContext:(AZSOperationContext*)operationContext;
+(void)processErrorResponseWithData:(NSData *)data errorToPopulate:(NSError **)errorToPopulate operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;
@end
