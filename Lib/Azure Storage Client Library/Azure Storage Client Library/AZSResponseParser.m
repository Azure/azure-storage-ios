// -----------------------------------------------------------------------------------------
// <copyright file="AZSResponseParser.m" company="Microsoft">
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

#import "AZSConstants.h"
#import "AZSResponseParser.h"
#import "AZSErrors.h"
#import "AZSOperationContext.h"

@implementation AZSStorageXMLParserDelegate

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    self.parseBeginElement(parser, elementName, attributeDict);
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    self.parseEndElement(parser, elementName);
}
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    self.foundCharacters(parser, string);
}

@end


@implementation AZSResponseParser
+(NSError *)preprocessResponseWithResponse:(NSHTTPURLResponse *)response requestResult:(id)requestResult operationContext:(AZSOperationContext *)operationContext
{
    switch (response.statusCode)
    {
        case 200:
        case 201:
        case 202:
        case 204:
        case 206:
            break;
        default:
        {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            userInfo[AZSCHttpStatusCode] = [NSNumber numberWithInteger:response.statusCode];
            userInfo[AZSCXmlUrlResponse] = response;
            userInfo[AZSCXmlRequestResult] = requestResult;
            userInfo[AZSCXmlOperationContext] = operationContext;
            NSError *storageError = [NSError errorWithDomain:AZSErrorDomain code:AZSEServerError userInfo:userInfo];
            return storageError;
        }
            break;
    }
    return nil;
}

+(void)processErrorResponseWithData:(NSData *)data errorToPopulate:(NSError **)errorToPopulate operationContext:(AZSOperationContext *)operationContext error:(NSError **)error
{
    AZSStorageXMLParserDelegate *parserDelegate = [[AZSStorageXMLParserDelegate alloc] init];
    
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    parser.shouldProcessNamespaces = NO;
    
    
    __block NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:(*errorToPopulate).userInfo];
    __block NSMutableDictionary *additionalErrorInfo = [NSMutableDictionary dictionary];
    __block NSMutableArray *elementStack = [NSMutableArray arrayWithCapacity:10];
    __block NSMutableString *builder = [[NSMutableString alloc] init];
    
    parserDelegate.parseBeginElement = ^(NSXMLParser *parser, NSString *elementName,NSDictionary *attributeDict)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Beginning to parse element with name = %@", elementName];
        [elementStack addObject:elementName];
        if ([builder length] > 0)
        {
            builder = [[NSMutableString alloc] init];
        }
    };
    
    parserDelegate.parseEndElement = ^(NSXMLParser *parser, NSString *elementName)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Ending to parse element with name = %@", elementName];
        NSString *currentNode = elementStack.lastObject;
        [elementStack removeLastObject];
        
        if (![elementName isEqualToString:currentNode])
        {
            // Malformed XML
            [parser abortParsing];
        }
        
        NSString *parentNode = elementStack.lastObject;
        
        if ([parentNode isEqualToString:AZSCXmlError])
        {
            if ([currentNode isEqualToString:AZSCXmlCode])
            {
                userInfo[currentNode] = builder;
                builder = [[NSMutableString alloc] init];
            }
            else if ([currentNode isEqualToString:AZSCXmlMessage])
            {
                userInfo[currentNode] = builder;
                builder = [[NSMutableString alloc] init];
            }
            else
            {
                additionalErrorInfo[currentNode] = builder;
                builder = [[NSMutableString alloc] init];
            }
        }
    };
    
    parserDelegate.foundCharacters = ^(NSXMLParser *parser, NSString *characters)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Found characters = %@", characters];
        [builder appendString:characters];
    };
    
    parser.delegate = parserDelegate;
    
    BOOL parseSuccessful = [parser parse];
    userInfo[@"AdditionalErrorDetails"] = additionalErrorInfo;
    *errorToPopulate = [NSError errorWithDomain:(*errorToPopulate).domain code:(*errorToPopulate).code userInfo:userInfo];

    if (!parseSuccessful)
    {
        [operationContext logAtLevel:AZSLogLevelDebug withMessage:@"Parse unsuccessful."];
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEParseError userInfo:@{@"InnerError":*errorToPopulate}];
    }
    
    return;
}
@end
