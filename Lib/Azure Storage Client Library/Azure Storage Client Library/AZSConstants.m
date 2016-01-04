// -----------------------------------------------------------------------------------------
// <copyright file="AZSConstants.m" company="Microsoft">
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

// Miscellaneous
NSString *const AZSCBlob = @"blob";
NSString *const AZSCContainer = @"container";
NSString *const AZSCDateFormatColloquial = @"%a, %d %b %Y %T GMT";
NSString *const AZSCDateFormatIso8601 = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
NSString *const AZSCDateFormatRFC = @"EEE, dd MMM yyyy HH':'mm':'ss 'GMT'";
NSString *const AZSCDateFormatRoundtrip = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSSSSSS'Z'";
NSString *const AZSCDefaultSuffix = @"core.windows.net";
NSString *const AZSCEmptyString = @"";
NSString *const AZSCHttpStatusCode = @"HTTP Status Code";
NSString *const AZSCPosix = @"en_US_POSIX";
NSString *const AZSCRawErrorData = @"rawErrorData";
NSString *const AZSCTargetStorageVersion = @"2015-04-05";
NSString *const AZSCUserAgent = @"iOS-v0.1.1";
NSString *const AZSCUtc = @"UTC";

NSInteger const AZSCKilobyte = 1024;
NSInteger const AZSCMaxBlockSize = 4 * AZSCKilobyte * AZSCKilobyte;
NSInteger const AZSCSnapshotIndex = 2;


// Account Settings
NSString *const AZSCSettingsAccountKey = @"AccountKey";
NSString *const AZSCSettingsAccountName = @"AccountName";
NSString *const AZSCSettingsBlobEndpoint = @"BlobEndpoint";
NSString *const AZSCSettingsEndpointSuffix = @"EndpointSuffix";
NSString *const AZSCSettingsEndpointsProtocol = @"DefaultEndpointsProtocol";
NSString *const AZSCSettingsHttp = @"http";
NSString *const AZSCSettingsHttps = @"https";
NSString *const AZSCSettingsSas = @"SharedAccessSignature";

// Headers
NSString *const AZSCHeaderPrefix = @"x-ms-";
NSString *const AZSCHeaderMetaPrefix = @"x-ms-meta-";
NSString *const AZSCHeaderAuthorization = @"Authorization";
NSString *const AZSCHeaderBlobPublicAccess = @"x-ms-blob-public-access";
NSString *const AZSCHeaderBlobCacheControl = @"x-ms-blob-cache-control";
NSString *const AZSCHeaderBlobContentDisposition = @"x-ms-blob-content-disposition";
NSString *const AZSCHeaderBlobContentEncoding = @"x-ms-blob-content-encoding";
NSString *const AZSCHeaderBlobContentLanguage = @"x-ms-blob-content-language";
NSString *const AZSCHeaderBlobContentLength = @"x-ms-blob-content-length";
NSString *const AZSCHeaderBlobContentMd5 = @"x-ms-blob-content-md5";
NSString *const AZSCHeaderBlobContentType = @"x-ms-blob-content-type";
NSString *const AZSCHeaderBlobSequenceNumber = @"x-ms-blob-sequence-number";
NSString *const AZSCHeaderBlobType = @"x-ms-blob-type";
NSString *const AZSCHeaderClientRequestId = @"x-ms-client-request-id";
NSString *const AZSCHeaderCopyAction = @"x-ms-copy-action";
NSString *const AZSCHeaderCopyStatus = @"x-ms-copy-status";
NSString *const AZSCHeaderCopyId = @"x-ms-copy-id";
NSString *const AZSCHeaderCopySource = @"x-ms-copy-source";
NSString *const AZSCHeaderCopyProgress = @"x-ms-copy-progress";
NSString *const AZSCHeaderCopyCompletionTime = @"x-ms-copy-completion-time";
NSString *const AZSCHeaderCopyStatusDescription = @"x-ms-copy-status-description";
NSString *const AZSCHeaderDate = @"x-ms-date";
NSString *const AZSCHeaderDeleteSnapshots = @"x-ms-delete-snapshots";
NSString *const AZSCHeaderLeaseAction = @"x-ms-lease-action";
NSString *const AZSCHeaderLeaseId = @"x-ms-lease-id";
NSString *const AZSCHeaderLeaseBreakPeriod = @"x-ms-lease-break-period";
NSString *const AZSCHeaderLeaseDuration = @"x-ms-lease-duration";
NSString *const AZSCHeaderLeaseState = @"x-ms-lease-state";
NSString *const AZSCHeaderLeaseStatus = @"x-ms-lease-status";
NSString *const AZSCHeaderLeaseTime = @"x-ms-lease-time";
NSString *const AZSCHeaderProposedLeaseId = @"x-ms-proposed-lease-id";
NSString *const AZSCHeaderRange = @"x-ms-range";
NSString *const AZSCHeaderRangeGetContent = @"x-ms-range-get-content-md5";
NSString *const AZSCHeaderRequestId = @"x-ms-request-id";
NSString *const AZSCHeaderSnapshot = @"x-ms-snapshot";
NSString *const AZSCHeaderUserAgent = @"User-Agent";
NSString *const AZSCHeaderSourceIfMatch = @"x-ms-source-if-match";
NSString *const AZSCHeaderSourceIfNoneMatch = @"x-ms-source-if-none-match";
NSString *const AZSCHeaderSourceIfModifiedSince = @"x-ms-source-if-modified-since";
NSString *const AZSCHeaderSourceIfUnmodifiedSince = @"x-ms-source-if-unmodified-since";
NSString *const AZSCHeaderVersion = @"x-ms-version";

// Header Values
NSString *const AZSCHeaderValueAbort = @"abort";
NSString *const AZSCHeaderValueAcquire = @"acquire";
NSString *const AZSCHeaderValueAll = @"all";
NSString *const AZSCHeaderValueBreak = @"break";
NSString *const AZSCHeaderValueChange = @"change";
NSString *const AZSCHeaderValueCommitted = @"committed";
NSString *const AZSCHeaderValueCopy = @"copy";
NSString *const AZSCHeaderValueDate = @"Date";
NSString *const AZSCHeaderValueIfMatch = @"If-Match";
NSString *const AZSCHeaderValueIfNoneMatch = @"If-None-Match";
NSString *const AZSCHeaderValueIfModifiedSince = @"If-Modified-Since";
NSString *const AZSCHeaderValueIfUnmodifiedSince = @"If-Unmodified-Since";
NSString *const AZSCHeaderValueInclude = @"include";
NSString *const AZSCHeaderValueMetadata = @"metadata";
NSString *const AZSCHeaderValueOnly = @"only";
NSString *const AZSCHeaderValueRelease = @"release";
NSString *const AZSCHeaderValueRenew = @"renew";
NSString *const AZSCHeaderValueSnapshots = @"snapshots";
NSString *const AZSCHeaderValueTrue = @"true";
NSString *const AZSCHeaderValueUncommitted = @"uncommitted";
NSString *const AZSCHeaderValueUncommittedBlobs = @"uncommittedblobs";
NSString *const AZSCHeaderValueUserAgent = @"Azure-Storage/0.1.1-preview (iOS %@)";

// HTTP Methods
NSString *const AZSCHttpDelete = @"DELETE";
NSString *const AZSCHttpHead = @"HEAD";
NSString *const AZSCHttpGet = @"GET";
NSString *const AZSCHttpPut = @"PUT";

// Query Parameters
NSString *const AZSCQueryApiVersion = @"api-version";
NSString *const AZSCQueryComp = @"comp";
NSString *const AZSCQueryRestype = @"restype";
NSString *const AZSCQuerySig = @"sig";
NSString *const AZSCQuerySnapshot = @"snapshot";

// Query Parameters and Values
NSString *const AZSCQueryCompAcl = @"comp=acl";
NSString *const AZSCQueryCompBlock = @"comp=block";
NSString *const AZSCQueryCompBlockList = @"comp=blocklist";
NSString *const AZSCQueryCompCopy = @"comp=copy";
NSString *const AZSCQueryCompLease = @"comp=lease";
NSString *const AZSCQueryCompList = @"comp=list";
NSString *const AZSCQueryCompMetadata = @"comp=metadata";
NSString *const AZSCQueryCompProperties = @"comp=properties";
NSString *const AZSCQueryCompSnapshot = @"comp=snapshot";
NSString *const AZSCQueryIncludeMetadata = @"include=metadata";
NSString *const AZSCQueryRestypeContainer = @"restype=container";

// Query Parameter Templates
NSString *const AZSCQueryTemplateBlockId = @"blockid=%@";
NSString *const AZSCQueryTemplateBlockListType = @"blocklisttype=%@";
NSString *const AZSCQueryTemplateCopyId = @"copyid=%@";
NSString *const AZSCQueryTemplateDelimiter = @"delimiter=%@";
NSString *const AZSCQueryTemplateInclude = @"include=%@";
NSString *const AZSCQueryTemplateMarker = @"marker=%@";
NSString *const AZSCQueryTemplateMaxResults = @"maxresults=%ld";
NSString *const AZSCQueryTemplatePrefix = @"prefix=%@";
NSString *const AZSCQueryTemplateSnapshot = @"snapshot=%@";

// Shared Key
NSString *const AZSCSharedTemplateAuthorization = @"SharedKey %@:%@";
NSString *const AZSCSharedTemplateBlobEndpoint = @"%@;BlobEndpoint=%@";
NSString *const AZSCSharedTemplateCredentials = @"%@AccountName=%@;AccountKey=%@";
NSString *const AZSCSharedTemplateDefaultEndpoint = @"DefaultEndpointsProtocol=%@%@";
NSString *const AZSCSharedTemplateEndpointSuffix = @"DefaultEndpointsProtocol=%@%@;EndpointSuffix=%@";
NSString *const AZSCSharedTemplatePrimaryUri = @"%@://%@.%@.%@";
NSString *const AZSCSharedTemplateSecondaryUri = @"%@://%@-secondary.%@.%@";

// SAS
NSString *const AZSCSasCacheControl = @"rscc";
NSString *const AZSCSasContentType = @"rsct";
NSString *const AZSCSasContentEncoding = @"rsce";
NSString *const AZSCSasContentLanguage = @"rscl";
NSString *const AZSCSasContentDisposition = @"rscd";
NSString *const AZSCSasEndPartionKey = @"epk";
NSString *const AZSCSasEndRowKey = @"erk";
NSString *const AZSCSasExpiryTime = @"se";
NSString *const AZSCSasPermissions = @"sp";
NSString *const AZSCSasPermissionsRead = @"r";
NSString *const AZSCSasPermissionsAdd = @"a";
NSString *const AZSCSasPermissionsCreate = @"c";
NSString *const AZSCSasPermissionsWrite = @"w";
NSString *const AZSCSasPermissionsDelete = @"d";
NSString *const AZSCSasPermissionsList = @"l";
NSString *const AZSCSasResource = @"sr";
NSString *const AZSCSasServiceVersion = @"sv";
NSString *const AZSCSasStartTime = @"st";
NSString *const AZSCSasStartPartionKey = @"spk";
NSString *const AZSCSasStartRowKey = @"srk";
NSString *const AZSCSasStoredIdentifier = @"si";
NSString *const AZSCSasTableName = @"tn";
NSString *const AZSCSasTemplateBlobCanonicalName = @"/%@/%@/%@/%@";
NSString *const AZSCSasTemplateBlobParameters = @"%@\n%@\n%@\n%@\n%@\n%@";
NSString *const AZSCSasTemplateBlobStringToSign =  @"%@\n%@\n%@\n%@\n%@\n\n\n%@";
NSString *const AZSCSasTemplateContainerCanonicalName = @"/%@/%@/%@";
NSString *const AZSCSasTemplateCredentials = @";SharedAccessSignature=%@";

// XML
NSString *const AZSCXmlAccessPolicy = @"AccessPolicy";
NSString *const AZSCXmlAvailable = @"available";
NSString *const AZSCXmlBlob = @"Blob";
NSString *const AZSCXmlBlobs = @"Blobs";
NSString *const AZSCXmlBlobAppendBlob = @"AppendBlob";
NSString *const AZSCXmlBlobBlockBlob = @"BlockBlob";
NSString *const AZSCXmlBlobPageBlob = @"PageBlob";
NSString *const AZSCXmlBlobPrefix = @"BlobPrefix";
NSString *const AZSCXmlBlobType = @"BlobType";
NSString *const AZSCXmlBlock = @"Block";
NSString *const AZSCXmlBlockList = @"BlockList";
NSString *const AZSCXmlBreaking = @"breaking";
NSString *const AZSCXmlBroken = @"broken";
NSString *const AZSCXmlCode = @"Code";
NSString *const AZSCXmlCommitted = @"Committed";
NSString *const AZSCXmlCommittedBlocks = @"CommittedBlocks";
NSString *const AZSCXmlContainer = @"Container";
NSString *const AZSCXmlContainers = @"Containers";
NSString *const AZSCXmlContentCacheControl = @"Cache-Control";
NSString *const AZSCXmlContentDisposition = @"Content-Disposition";
NSString *const AZSCXmlContentEncoding = @"Content-Encoding";
NSString *const AZSCXmlContentLanguage = @"Content-Language";
NSString *const AZSCXmlContentLength = @"Content-Length";
NSString *const AZSCXmlContentMd5 = @"Content-MD5";
NSString *const AZSCXmlContentType = @"Content-Type";
NSString *const AZSCXmlCopyAborted = @"aborted";
NSString *const AZSCXmlCopyCompletionTime = @"CopyCompletionTime";
NSString *const AZSCXmlCopyFailed = @"failed";
NSString *const AZSCXmlCopyId = @"CopyId";
NSString *const AZSCXmlCopyPending = @"pending";
NSString *const AZSCXmlCopyProgress = @"CopyProgress";
NSString *const AZSCXmlCopySource = @"CopySource";
NSString *const AZSCXmlCopyStatus = @"CopyStatus";
NSString *const AZSCXmlCopyStatusDescription = @"CopyStatusDescription";
NSString *const AZSCXmlCopySuccess = @"success";
NSString *const AZSCXmlEnumerationResults = @"EnumerationResults";
NSString *const AZSCXmlError = @"Error";
NSString *const AZSCXmlETag = @"ETag";
NSString *const AZSCXmlExpired = @"expired";
NSString *const AZSCXmlExpiry = @"Expiry";
NSString *const AZSCXmlFixed = @"fixed";
NSString *const AZSCXmlId = @"Id";
NSString *const AZSCXmlInfinite = @"infinite";
NSString *const AZSCXmlIso = @"ISO-8859-1";
NSString *const AZSCXmlLastModified = @"Last-Modified";
NSString *const AZSCXmlLatest = @"Latest";
NSString *const AZSCXmlLeased = @"leased";
NSString *const AZSCXmlLeaseDuration = @"LeaseDuration";
NSString *const AZSCXmlLeaseState = @"LeaseState";
NSString *const AZSCXmlLeaseStatus = @"LeaseStatus";
NSString *const AZSCXmlLocked = @"locked";
NSString *const AZSCXmlMessage = @"Message";
NSString *const AZSCXmlMetadata = @"Metadata";
NSString *const AZSCXmlName = @"Name";
NSString *const AZSCXmlNextMarker = @"NextMarker";
NSString *const AZSCXmlOperationContext = @"OperationContext";
NSString *const AZSCXmlPermission = @"Permission";
NSString *const AZSCXmlProperties = @"Properties";
NSString *const AZSCXmlRange = @"Range";
NSString *const AZSCXmlRequestResult = @"RequestResult";
NSString *const AZSCXmlSignedIdentifier = @"SignedIdentifier";
NSString *const AZSCXmlSignedIdentifiers = @"SignedIdentifiers";
NSString *const AZSCXmlSize = @"Size";
NSString *const AZSCXmlSnapshot = @"Snapshot";
NSString *const AZSCXmlStart = @"Start";
NSString *const AZSCXmlUncommitted = @"Uncommitted";
NSString *const AZSCXmlUncommittedBlocks = @"UncommittedBlocks";
NSString *const AZSCXmlUnlocked = @"unlocked";
NSString *const AZSCXmlUrlResponse = @"URLResponse";