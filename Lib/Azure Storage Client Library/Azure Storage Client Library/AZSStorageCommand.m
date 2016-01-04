// -----------------------------------------------------------------------------------------
// <copyright file="AZSStorageCommand.m" company="Microsoft">
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
#import "AZSStorageCommand.h"
#import "AZSOperationContext.h"
#import "AZSRequestResult.h"
#import "AZSAuthenticationHandler.h"
#import "AZSResponseParser.h"
#import "AZSStorageCredentials.h"

@interface AZSStorageCommand()

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSStorageCommand

-(instancetype)init
{
    return nil;
}

-(instancetype) initWithStorageCredentials:(AZSStorageCredentials *)credentials storageUri:(AZSStorageUri *)storageUri operationContext:(AZSOperationContext *)operationContext
{
    return [self initWithStorageCredentials:credentials storageUri:storageUri calculateResponseMD5:NO operationContext:operationContext];
}

-(instancetype) initWithStorageCredentials:(AZSStorageCredentials *)credentials storageUri:(AZSStorageUri *)storageUri calculateResponseMD5:(BOOL)calculateResponseMD5 operationContext:(AZSOperationContext *)operationContext
{
    self = [super init];
    if (self)
    {
        _storageUri = storageUri;
        _calculateResponseMD5 = calculateResponseMD5;
        
        // Give a default error-processing implementation.
        // TODO: This now couples the execution layer with the protocol layer.  Decide if this is correct or not.
        self.processError = ^void(NSOutputStream *outputStream, NSError **errorToPopulate, NSError **error) {
            NSData *rawErrorData = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
            if (rawErrorData.length > 0)
            {
                NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:(*errorToPopulate).userInfo];
                userInfo[AZSCRawErrorData] = rawErrorData;
                *errorToPopulate = [NSError errorWithDomain:(*errorToPopulate).domain code:(*errorToPopulate).code userInfo:userInfo];
                [AZSResponseParser processErrorResponseWithData:rawErrorData errorToPopulate:errorToPopulate operationContext:operationContext error:error];
            }
        };
        _credentials = credentials;
    }
    
    return self;
}

-(void) setAuthenticationHandler:(id<AZSAuthenticationHandler>)authenticationHandler
{
    [self setSignRequest:^void(NSMutableURLRequest * urlRequest, AZSOperationContext * operationContext) {
        [authenticationHandler signRequest:urlRequest operationContext:operationContext];
    }];
}

@end