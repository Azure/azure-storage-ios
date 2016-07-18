// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobTestBase.h" company="Microsoft">
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

#import "AZSTestBase.h"
@class AZSCloudBlobClient;
@class AZSCloudBlob;
@class AZSByteValidationStream;

@interface AZSBlobTestSpinWrapper : NSObject
@property NSStream *stream;
@property AZSByteValidationStream *delegate;
@property (copy) void (^completionHandler)();
@end

@interface AZSBlobTestBase : AZSTestBase
@property AZSCloudBlobClient *blobClient;

-(void)waitForCopyToCompleteWithBlob:(AZSCloudBlob *)blobToMonitor completionHandler:(void (^)(NSError *, BOOL))completionHandler;
-(void)scheduleStreamInNewThreaAndRunWithWrapper:(AZSBlobTestSpinWrapper *)wrapper;

@end

