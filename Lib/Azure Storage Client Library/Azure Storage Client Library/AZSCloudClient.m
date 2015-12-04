// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudClient.m" company="Microsoft">
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

#import "AZSCloudClient.h"
#import "AZSStorageCredentials.h"
#import "AZSSharedKeyBlobAuthenticationHandler.h"
#import "AZSNoOpAuthenticationHandler.h"

@interface AZSCloudClient()
{
    AZSStorageCredentials *_credentials;
}

-(instancetype)init AZS_DESIGNATED_INITIALIZER;

@end

@implementation AZSCloudClient

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithStorageUri:(AZSStorageUri *)storageUri credentials:(AZSStorageCredentials *)credentials
{
    self = [super init];
    if (self)
    {
        _storageUri = storageUri;
        _credentials = credentials;
        [self setAuthenticationHandlerWithCredentials:_credentials];
    }
    return self;
}

-(AZSStorageCredentials *)credentials
{
    return _credentials;
}

-(void)setAuthenticationHandlerWithCredentials:(AZSStorageCredentials *)credentials
{
    [NSException raise:@"Cannot set auth handler on a base AZSCloudClient" format:@"Cannot set auth handler on a base AZSCloudClient"];
}


-(void)setCredentials:(AZSStorageCredentials *)credentials
{
    _credentials = credentials;
    [self setAuthenticationHandlerWithCredentials:credentials];
}



@end
