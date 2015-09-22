// -----------------------------------------------------------------------------------------
// <copyright file="Azure_Storage_Client_Library.h" company="Microsoft">
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
#import "AZSErrors.h"
#import "AZSEnums.h"
#import "AZSMacros.h"
#import "AZSOperationContext.h"
#import "AZSRequestResult.h"
#import "AZSBlobRequestOptions.h"
#import "AZSCloudBlobClient.h"
#import "AZSStorageCredentials.h"
#import "AZSStorageUri.h"
#import "AZSCloudStorageAccount.h"
#import "AZSResultSegment.h"
#import "AZSContinuationToken.h"
#import "AZSAccessCondition.h"
#import "AZSRetryInfo.h"
#import "AZSRetryContext.h"
#import "AZSRetryPolicy.h"
#import "AZSCloudBlockBlob.h"
#import "AZSCloudBlobContainer.h"
#import "AZSBlockListItem.h"
#import "AZSBlobContainerProperties.h"
#import "AZSBlobProperties.h"
#import "AZSCopyState.h"
#import "AZSBlobOutputStream.h"

// TODO: Import all the user-accessible headers, so that users only need to import this one header file.
@interface Azure_Storage_Client_Library : NSObject

@end
