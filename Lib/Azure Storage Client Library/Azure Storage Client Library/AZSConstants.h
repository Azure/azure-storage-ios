// -----------------------------------------------------------------------------------------
// <copyright file="AZSConstants.h" company="Microsoft">
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

#ifndef __AZS_CONSTANTS_DEFINED__
#define __AZS_CONSTANTS_DEFINED__

// Miscellaneous
FOUNDATION_EXPORT NSString *const AZSCBlob;
FOUNDATION_EXPORT NSString *const AZSCContainer;
FOUNDATION_EXPORT NSString *const AZSCDateFormatColloquial;
FOUNDATION_EXPORT NSString *const AZSCDateFormatIso8601;
FOUNDATION_EXPORT NSString *const AZSCDateFormatRFC;
FOUNDATION_EXPORT NSString *const AZSCDateFormatRoundtrip;
FOUNDATION_EXPORT NSString *const AZSCDefaultDirectoryDelimiter;
FOUNDATION_EXPORT NSString *const AZSCDefaultSuffix;
FOUNDATION_EXPORT NSString *const AZSCEmptyString;
FOUNDATION_EXPORT NSString *const AZSCHttp;
FOUNDATION_EXPORT NSString *const AZSCHttps;
FOUNDATION_EXPORT NSString *const AZSCHttpStatusCode;
FOUNDATION_EXPORT NSString *const AZSCPosix;
FOUNDATION_EXPORT NSString *const AZSCRawErrorData;
FOUNDATION_EXPORT NSString *const AZSCTargetStorageVersion;
FOUNDATION_EXPORT NSString *const AZSCTrue;
FOUNDATION_EXPORT NSString *const AZSCUserAgent;
FOUNDATION_EXPORT NSString *const AZSCUtc;

FOUNDATION_EXPORT NSInteger const AZSCKilobyte;
FOUNDATION_EXPORT NSInteger const AZSCMaxBlockSize;
FOUNDATION_EXPORT NSInteger const AZSCSnapshotIndex;

// Account Settings
FOUNDATION_EXPORT NSString *const AZSCSettingsAccountKey;
FOUNDATION_EXPORT NSString *const AZSCSettingsAccountName;
FOUNDATION_EXPORT NSString *const AZSCSettingsBlobEndpoint;
FOUNDATION_EXPORT NSString *const AZSCSettingsEmulator;
FOUNDATION_EXPORT NSString *const AZSCSettingsEndpointSuffix;
FOUNDATION_EXPORT NSString *const AZSCSettingsEndpointsProtocol;
FOUNDATION_EXPORT NSString *const AZSCSettingsSas;

// Emulator
FOUNDATION_EXPORT NSString *const AZSCEmulatorUrl;
FOUNDATION_EXPORT NSString *const AZSCEmulatorAccount;
FOUNDATION_EXPORT NSString *const AZSCEmulatorAccountKey;

// Headers
FOUNDATION_EXPORT NSString *const AZSCHeaderPrefix;
FOUNDATION_EXPORT NSString *const AZSCHeaderMetaPrefix;
FOUNDATION_EXPORT NSString *const AZSCHeaderAuthorization;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobPublicAccess;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobCacheControl;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentDisposition;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentEncoding;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentLanguage;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentLength;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentMd5;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobContentType;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobSequenceNumber;
FOUNDATION_EXPORT NSString *const AZSCHeaderBlobType;
FOUNDATION_EXPORT NSString *const AZSCHeaderClientRequestId;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyAction;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyStatus;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyId;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopySource;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyProgress;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyCompletionTime;
FOUNDATION_EXPORT NSString *const AZSCHeaderCopyStatusDescription;
FOUNDATION_EXPORT NSString *const AZSCHeaderDate;
FOUNDATION_EXPORT NSString *const AZSCHeaderDeleteSnapshots;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseAction;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseBreakPeriod;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseId;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseDuration;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseState;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseStatus;
FOUNDATION_EXPORT NSString *const AZSCHeaderLeaseTime;
FOUNDATION_EXPORT NSString *const AZSCHeaderProposedLeaseId;
FOUNDATION_EXPORT NSString *const AZSCHeaderRange;
FOUNDATION_EXPORT NSString *const AZSCHeaderRangeGetContent;
FOUNDATION_EXPORT NSString *const AZSCHeaderRequestId;
FOUNDATION_EXPORT NSString *const AZSCHeaderSnapshot;
FOUNDATION_EXPORT NSString *const AZSCHeaderSourceIfMatch;
FOUNDATION_EXPORT NSString *const AZSCHeaderSourceIfNoneMatch;
FOUNDATION_EXPORT NSString *const AZSCHeaderSourceIfModifiedSince;
FOUNDATION_EXPORT NSString *const AZSCHeaderSourceIfUnmodifiedSince;
FOUNDATION_EXPORT NSString *const AZSCHeaderUserAgent;
FOUNDATION_EXPORT NSString *const AZSCHeaderVersion;

// Header values
FOUNDATION_EXPORT NSString *const AZSCHeaderValueAbort;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueAcquire;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueAll;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueBreak;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueChange;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueCommitted;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueCopy;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueDate;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueIfMatch;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueIfNoneMatch;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueIfModifiedSince;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueIfUnmodifiedSince;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueInclude;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueMetadata;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueOnly;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueRelease;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueRenew;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueSnapshots;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueUncommitted;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueUncommittedBlobs;
FOUNDATION_EXPORT NSString *const AZSCHeaderValueUserAgent;

// HTTP Methods
FOUNDATION_EXPORT NSString *const AZSCHttpDelete;
FOUNDATION_EXPORT NSString *const AZSCHttpHead;
FOUNDATION_EXPORT NSString *const AZSCHttpGet;
FOUNDATION_EXPORT NSString *const AZSCHttpPut;

// Query Parameters
FOUNDATION_EXPORT NSString *const AZSCQueryApiVersion;
FOUNDATION_EXPORT NSString *const AZSCQueryComp;
FOUNDATION_EXPORT NSString *const AZSCQueryRestype;
FOUNDATION_EXPORT NSString *const AZSCQuerySig;
FOUNDATION_EXPORT NSString *const AZSCQuerySnapshot;

// Query Parameters and Values
FOUNDATION_EXPORT NSString *const AZSCQueryCompAcl;
FOUNDATION_EXPORT NSString *const AZSCQueryCompBlock;
FOUNDATION_EXPORT NSString *const AZSCQueryCompBlockList;
FOUNDATION_EXPORT NSString *const AZSCQueryCompCopy;
FOUNDATION_EXPORT NSString *const AZSCQueryCompLease;
FOUNDATION_EXPORT NSString *const AZSCQueryCompList;
FOUNDATION_EXPORT NSString *const AZSCQueryCompMetadata;
FOUNDATION_EXPORT NSString *const AZSCQueryCompProperties;
FOUNDATION_EXPORT NSString *const AZSCQueryCompSnapshot;
FOUNDATION_EXPORT NSString *const AZSCQueryIncludeMetadata;
FOUNDATION_EXPORT NSString *const AZSCQueryRestypeContainer;

// Query Parameter Templates
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateBlockId;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateBlockListType;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateCopyId;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateDelimiter;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateInclude;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateMarker;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateMaxResults;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplatePrefix;
FOUNDATION_EXPORT NSString *const AZSCQueryTemplateSnapshot;

// Shared Key
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateAuthorization;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateBlobEndpoint;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateCredentials;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateDefaultEndpoint;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateEndpointSuffix;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplatePrimaryUri;
FOUNDATION_EXPORT NSString *const AZSCSharedTemplateSecondaryUri;

// SAS
FOUNDATION_EXPORT NSString *const AZSCSasCacheControl;
FOUNDATION_EXPORT NSString *const AZSCSasContentDisposition;
FOUNDATION_EXPORT NSString *const AZSCSasContentEncoding;
FOUNDATION_EXPORT NSString *const AZSCSasContentLanguage;
FOUNDATION_EXPORT NSString *const AZSCSasContentType;
FOUNDATION_EXPORT NSString *const AZSCSasEndPartionKey;
FOUNDATION_EXPORT NSString *const AZSCSasEndRowKey;
FOUNDATION_EXPORT NSString *const AZSCSasExpiryTime;
FOUNDATION_EXPORT NSString *const AZSCSasIpAddressOrRange;
FOUNDATION_EXPORT NSString *const AZSCSasPermissions;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsRead;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsAdd;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsCreate;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsWrite;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsDelete;
FOUNDATION_EXPORT NSString *const AZSCSasPermissionsList;
FOUNDATION_EXPORT NSString *const AZSCSasProtocolRestriction;
FOUNDATION_EXPORT NSString *const AZSCSasProtocolsHttpsHttp;
FOUNDATION_EXPORT NSString *const AZSCSasResource;
FOUNDATION_EXPORT NSString *const AZSCSasResourceTypes;
FOUNDATION_EXPORT NSString *const AZSCSasServices;
FOUNDATION_EXPORT NSString *const AZSCSasServiceVersion;
FOUNDATION_EXPORT NSString *const AZSCSasStartTime;
FOUNDATION_EXPORT NSString *const AZSCSasStartPartionKey;
FOUNDATION_EXPORT NSString *const AZSCSasStartRowKey;
FOUNDATION_EXPORT NSString *const AZSCSasStoredIdentifier;
FOUNDATION_EXPORT NSString *const AZSCSasTableName;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateBlobCanonicalName;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateBlobParameters;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateBlobStringToSign;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateContainerCanonicalName;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateCredentials;
FOUNDATION_EXPORT NSString *const AZSCSasTemplateIpRange;

// XML
FOUNDATION_EXPORT NSString *const AZSCXmlAccessPolicy;
FOUNDATION_EXPORT NSString *const AZSCXmlAvailable;
FOUNDATION_EXPORT NSString *const AZSCXmlBlob;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobs;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobAppendBlob;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobBlockBlob;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobPageBlob;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobPrefix;
FOUNDATION_EXPORT NSString *const AZSCXmlBlobType;
FOUNDATION_EXPORT NSString *const AZSCXmlBlock;
FOUNDATION_EXPORT NSString *const AZSCXmlBlockList;
FOUNDATION_EXPORT NSString *const AZSCXmlBreaking;
FOUNDATION_EXPORT NSString *const AZSCXmlBroken;
FOUNDATION_EXPORT NSString *const AZSCXmlCode;
FOUNDATION_EXPORT NSString *const AZSCXmlCommitted;
FOUNDATION_EXPORT NSString *const AZSCXmlCommittedBlocks;
FOUNDATION_EXPORT NSString *const AZSCXmlContainer;
FOUNDATION_EXPORT NSString *const AZSCXmlContainers;
FOUNDATION_EXPORT NSString *const AZSCXmlContentCacheControl;
FOUNDATION_EXPORT NSString *const AZSCXmlContentDisposition;
FOUNDATION_EXPORT NSString *const AZSCXmlContentEncoding;
FOUNDATION_EXPORT NSString *const AZSCXmlContentLanguage;
FOUNDATION_EXPORT NSString *const AZSCXmlContentLength;
FOUNDATION_EXPORT NSString *const AZSCXmlContentMd5;
FOUNDATION_EXPORT NSString *const AZSCXmlContentType;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyAborted;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyCompletionTime;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyFailed;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyId;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyPending;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyProgress;
FOUNDATION_EXPORT NSString *const AZSCXmlCopySource;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyStatus;
FOUNDATION_EXPORT NSString *const AZSCXmlCopyStatusDescription;
FOUNDATION_EXPORT NSString *const AZSCXmlCopySuccess;
FOUNDATION_EXPORT NSString *const AZSCXmlEnumerationResults;
FOUNDATION_EXPORT NSString *const AZSCXmlError;
FOUNDATION_EXPORT NSString *const AZSCXmlETag;
FOUNDATION_EXPORT NSString *const AZSCXmlExpired;
FOUNDATION_EXPORT NSString *const AZSCXmlExpiry;
FOUNDATION_EXPORT NSString *const AZSCXmlFixed;
FOUNDATION_EXPORT NSString *const AZSCXmlId;
FOUNDATION_EXPORT NSString *const AZSCXmlInfinite;
FOUNDATION_EXPORT NSString *const AZSCXmlIso;
FOUNDATION_EXPORT NSString *const AZSCXmlLastModified;
FOUNDATION_EXPORT NSString *const AZSCXmlLatest;
FOUNDATION_EXPORT NSString *const AZSCXmlLeased;
FOUNDATION_EXPORT NSString *const AZSCXmlLeaseDuration;
FOUNDATION_EXPORT NSString *const AZSCXmlLeaseState;
FOUNDATION_EXPORT NSString *const AZSCXmlLeaseStatus;
FOUNDATION_EXPORT NSString *const AZSCXmlLocked;
FOUNDATION_EXPORT NSString *const AZSCXmlMessage;
FOUNDATION_EXPORT NSString *const AZSCXmlMetadata;
FOUNDATION_EXPORT NSString *const AZSCXmlName;
FOUNDATION_EXPORT NSString *const AZSCXmlNextMarker;
FOUNDATION_EXPORT NSString *const AZSCXmlOperationContext;
FOUNDATION_EXPORT NSString *const AZSCXmlPermission;
FOUNDATION_EXPORT NSString *const AZSCXmlProperties;
FOUNDATION_EXPORT NSString *const AZSCXmlRange;
FOUNDATION_EXPORT NSString *const AZSCXmlRequestResult;
FOUNDATION_EXPORT NSString *const AZSCXmlSignedIdentifier;
FOUNDATION_EXPORT NSString *const AZSCXmlSignedIdentifiers;
FOUNDATION_EXPORT NSString *const AZSCXmlSize;
FOUNDATION_EXPORT NSString *const AZSCXmlSnapshot;
FOUNDATION_EXPORT NSString *const AZSCXmlStart;
FOUNDATION_EXPORT NSString *const AZSCXmlUncommitted;
FOUNDATION_EXPORT NSString *const AZSCXmlUncommittedBlocks;
FOUNDATION_EXPORT NSString *const AZSCXmlUnlocked;
FOUNDATION_EXPORT NSString *const AZSCXmlUrlResponse;

#endif //__AZS_CONSTANTS_DEFINED__