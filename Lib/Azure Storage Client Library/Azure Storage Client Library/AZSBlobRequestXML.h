// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestXML.h" company="Microsoft">
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

@class AZSOperationContext;
@class AZSSharedAccessPolicy;
@class AZSServiceProperties;

@interface AZSBlobRequestXML : NSObject

+(NSString *) createBlockListXMLFromArray:(NSArray *)blockList operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

+(NSString *) createStoredPoliciesXMLFromPermissions:(NSMutableDictionary *)permissions operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

+(NSString *) createServicePropertiesXML:(AZSServiceProperties *)serviceProperties operationContext:(AZSOperationContext *)operationContext error:(NSError **)error;

@end
