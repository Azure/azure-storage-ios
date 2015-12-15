// -----------------------------------------------------------------------------------------
// <copyright file="AZSEnums.h" company="Microsoft">
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

/** The different Storage Locations */
typedef NS_ENUM(NSInteger, AZSStorageLocation)
{
    /** The Primary Stoarge Location.*/
    AZSStorageLocationPrimary//,
    
    /** The Secondary Storage Location.*/
//    AZSStorageLocationSecondary
};

/** The mode in which the library will target storage locations for requests when retrying.*/
typedef NS_ENUM(NSInteger, AZSStorageLocationMode)
{
    /** No location mode specified.*/
    AZSStorageLocationModeUnspecified,
    
    /** Target only the primary storage location.*/
    AZSStorageLocationModePrimaryOnly//,
//    AZSStorageLocationModePrimaryThenSecondary,
//    AZSStorageLocationModeSecondaryOnly,
//    AZSStorageLocationModeSecondaryThenPrimary
};

/** The different possible Container Public Access Types.*/
typedef NS_ENUM(NSInteger, AZSContainerPublicAccessType)
{
    /** No public access.  This should be the default for many scenarios.*/
    AZSContainerPublicAccessTypeOff,
    
    /** Container-level public access.
     
     If this is selected, then all blobs in the container will be publically readable and listable.
     */
    AZSContainerPublicAccessTypeContainer,
    
    /** Blob-level public access.
     
     If this is selected, then all blobs in the container will be publically readable, but not listable.
     */
    AZSContainerPublicAccessTypeBlob
};

/** The different possible Container Listing Details.*/
typedef NS_OPTIONS(NSUInteger, AZSContainerListingDetails)
{
    /** No additional details retrieved with the container listing operation.*/
    AZSContainerListingDetailsNone = 0x0,
    
    /** Retrieve container metadata as well in the listing operation.*/
    AZSContainerListingDetailsMetadata = 0x1 << 0,
    
    /** Retrieve all details in the listing operation.*/
    AZSContainerListingDetailsAll = AZSContainerListingDetailsMetadata
};

/** The different possible Blob Listing Details.*/
typedef NS_OPTIONS(NSUInteger, AZSBlobListingDetails)
{
    /** List only committed blobs, and do not return blob metadata.*/
    AZSBlobListingDetailsNone = 0x0,
    
    /** List committed blobs and blob snapshots.*/
    AZSBlobListingDetailsSnapshots = 0x1 << 0,
    
    /** Retrieve blob metadata for each blob returned in the listing.*/
    AZSBlobListingDetailsMetadata = 0x1 << 1,
    
    /** List committed and uncommittee blobs.*/
    AZSBlobListingDetailsUncommittedBlobs = 0x1 << 2,
    
    /** Include copy propertied in the listing.*/
    AZSBlobListingDetailsCopy = 0x1 << 3,
    
    /** List all available committed blobs, uncommitted blobs, and snapshots, and return all metadata and copy status for those blobs.*/
    AZSBlobListingDetailsAll = AZSBlobListingDetailsSnapshots | AZSBlobListingDetailsMetadata | AZSBlobListingDetailsUncommittedBlobs | AZSBlobListingDetailsCopy
};

/** The different possible block list modes.

 When uploading a block list, this specifies where to search for the blocks.
 When downloading a block list, this specifies where the individual blocks are found.*/
typedef NS_ENUM(NSInteger, AZSBlockListMode)
{
    /** Search in both the committed block list and the uncommitted block list for a block with the given ID, and 
     use whichever is latest.  This should be the default for most blocklist-upload operations.*/
    AZSBlockListModeLatest,
    
    /** The block is in the committed block list.*/
    AZSBlockListModeCommitted,
    
    /** The block is in the uncommitted block list.*/
    AZSBlockListModeUncommitted
};

/** Which block lists to fetch during a download block list operation.*/
typedef NS_ENUM(NSInteger, AZSBlockListFilter)
{
    /** Fetch only committed blocks.*/
    AZSBlockListFilterCommitted,
    
    /** Fetch only uncommitted blocks.*/
    AZSBlockListFilterUncommitted,
    
    /** Fetch all blocks.*/
    AZSBlockListFilterAll
};

/** Options on blob deletion regarding snapshots. */
typedef NS_ENUM(NSInteger, AZSDeleteSnapshotsOption)
{
    /** Delete the blob only.  If the blob has snapshots, this option will result in an error from the service. */
    AZSDeleteSnapshotsOptionNone,
    
    /** Delete the blob and its snapshots. */
    AZSDeleteSnapshotsOptionIncludeSnapshots,
    
    /** Delete only snapshots. */
    AZSDeleteSnapshotsOptionDeleteSnapshotsOnly
};

/** The lease status of a resource */
typedef NS_ENUM(NSInteger, AZSLeaseStatus)
{
    /** The lease status is not specified. */
    AZSLeaseStatusUnspecified,
    
    /** The lease status is locked. */
    AZSLeaseStatusLocked,
    
    /** The lease status is available to be locked. */
    AZSLeaseStatusUnlocked
};

/** The lease state of a resource */
typedef NS_ENUM(NSInteger, AZSLeaseState)
{
    /** The lease state is not specified. */
    AZSLeaseStateUnspecified,
    
    /** The lease is in the Available state. */
    AZSLeaseStateAvailable,
    
    /** The lease is in the Leased state. */
    AZSLeaseStateLeased,
    
    /** The lease is in the Expired state. */
    AZSLeaseStateExpired,
    
    /** The lease is in the Breaking state. */
    AZSLeaseStateBreaking,
    
    /** The lease is in the Broken state. */
    AZSLeaseStateBroken
};

/** The lease duration of a resource */
typedef NS_ENUM(NSInteger, AZSLeaseDuration)
{
    /** The lease duration is not specified. */
    AZSLeaseDurationUnspecified,
    
    /** The lease duration is finite. */
    AZSLeaseDurationFixed,
    
    /** The lease duration is infinite. */
    AZSLeaseDurationInfinite
};

/** The type of a Blob. */
typedef NS_ENUM(NSInteger, AZSBlobType)
{
    /** The Blob type is not specified. */
    AZSBlobTypeUnspecified,
    
    /** The Blob is a Page Blob. */
    AZSBlobTypePageBlob,
    
    /** The Blob is a Block Blob. */
    AZSBlobTypeBlockBlob,
    
    /** The Blob is an Append Blob. */
    AZSBlobTypeAppendBlob
};

/** Represents the status of a copy operation. */
typedef NS_ENUM(NSInteger, AZSCopyStatus)
{
    /** The copy status is invalid. */
    AZSCopyStatusInvalid,
    
    /** The copy operation is pending. */
    AZSCopyStatusPending,
    
    /** The copy operation succeeded. */
    AZSCopyStatusSuccess,
    
    /** The copy operation has been aborted. */
    AZSCopyStatusAborted,
    
    /** The copy operation encountered an error. */
    AZSCopyStatusFailed
};

/** Represents the lease action being performed. */
typedef NS_ENUM(NSInteger, AZSLeaseAction)
{
    /** Acquire the lease. */
    AZSLeaseActionAcquire,
    
    /** Renew the lease. */
    AZSLeaseActionRenew,
    
    /** Release the lease. */
    AZSLeaseActionRelease,
    
    /** Break the lease. */
    AZSLeaseActionBreak,
    
    /** Change the lease ID. */
    AZSLeaseActionChange
};

/** The maximum level at which to log. These values correspond to their respective ASL log levels. */
typedef NS_ENUM(NSInteger, AZSLogLevel)
{
    /** Don't log anything. */
    AZSLogLevelNoLogging = 0,
    
    /** Only log critical-level messages. */
    AZSLogLevelCritical = 2,
    
    /** Log error-level and critical-level messages. */
    AZSLogLevelError = 3,
    
    /** Log warning-, error-, and critical-level messages. */
    AZSLogLevelWarning = 4,
    
    /** Log info-, warning-, error-, and critical-level messages. */
    AZSLogLevelInfo = 6,
    
    /** Log all messages, including debugging messages. */
    AZSLogLevelDebug = 7
};

/** Specifies the set of possible permissions for a shared access policy. **/
typedef NS_OPTIONS(NSUInteger, AZSSharedAccessPermissions)
{
    /** Specifies no access granted. **/
    AZSSharedAccessPermissionsNone            = 0x0,
    
    /** Specifies Read access granted. **/
    AZSSharedAccessPermissionsRead            = 0x1 << 0,
    
    /** Specifies Add access granted. **/
    AZSSharedAccessPermissionsAdd             = 0x1 << 1,
    
    /** Specifies Create access granted. **/
    AZSSharedAccessPermissionsCreate          = 0x1 << 2,
    
    /** Specifies Write access granted. **/
    AZSSharedAccessPermissionsWrite           = 0x1 << 3,
    
    /** Specifies Delete access granted. **/
    AZSSharedAccessPermissionsDelete          = 0x1 << 4,
    
    /** Specifies List access granted. **/
    AZSSharedAccessPermissionsList            = 0x1 << 5,
    
    /** Specifies Update access granted. **/
    AZSSharedAccessPermissionsUpdate          = 0x1 << 6,
    
    /** Specifies Process Messages access granted. **/
    AZSSharedAccessPermissionsProcessMessages = 0x1 << 7,
    
    /** Specifies All access granted. **/
    AZSSharedAccessPermissionsAll           = AZSSharedAccessPermissionsRead | AZSSharedAccessPermissionsAdd | AZSSharedAccessPermissionsCreate |
            AZSSharedAccessPermissionsWrite | AZSSharedAccessPermissionsDelete | AZSSharedAccessPermissionsList| AZSSharedAccessPermissionsUpdate |
            AZSSharedAccessPermissionsProcessMessages,
    
    /** Specifies the permissions which are valid when used on the blob service. **/
    AZSSharedAccessPermissionsBlobFull  = AZSSharedAccessPermissionsRead | AZSSharedAccessPermissionsAdd | AZSSharedAccessPermissionsCreate |
            AZSSharedAccessPermissionsWrite | AZSSharedAccessPermissionsDelete | AZSSharedAccessPermissionsList
};

/** Represents the protocols with which a SAS may be used. */
typedef NS_ENUM(NSInteger, AZSSharedAccessProtocols)
{
    /** Specifies permission granted to use SAS with any protocol. */
    AZSSharedAccessProtocolAll,
    
    /** Specifies permission granted to use SAS through HTTPS or HTTP. */
    AZSSharedAccessProtocolHttpsHttp,
    
    /** Specifies permission granted to use SAS only through HTTPS. */
    AZSSharedAccessProtocolHttpsOnly
};

/** Specifies the set of possible services for a shared access policy. **/
typedef NS_OPTIONS(NSUInteger, AZSSharedAccessServices)
{
    /** Specifies no access granted. **/
    AZSSharedAccessServicesNone   = 0x0,
    
    /** Specifies Blob access granted. **/
    AZSSharedAccessServicesBlob   = 0x1 << 0,
    
    /** Specifies File access granted. **/
    AZSSharedAccessServicesFile   = 0x1 << 1,

    /** Specifies Queue access granted. **/
    AZSSharedAccessServicesQueue  = 0x1 << 2,
    
    /** Specifies Table access granted. **/
    AZSSharedAccessServicesTable  = 0x1 << 3,
    
    /** Specifies All access granted. **/
    AZSSharedAccessServicesAll    =
            AZSSharedAccessServicesBlob | AZSSharedAccessServicesFile | AZSSharedAccessServicesQueue | AZSSharedAccessServicesTable
};

/** Specifies the set of possible resource types for a shared access policy. **/
typedef NS_OPTIONS(NSUInteger, AZSSharedAccessResourceTypes)
{
    /** Specifies no access granted. **/
    AZSSharedAccessResourceTypesNone        = 0x0,
    
    /** Specifies Service level access granted. **/
    AZSSharedAccessResourceTypesService     = 0x1 << 0,
    
    /** Specifies Container level access granted. **/
    AZSSharedAccessResourceTypesContainer   = 0x1 << 1,
    
    /** Specifies Object level access granted. **/
    AZSSharedAccessResourceTypesObject      = 0x1 << 2,
    
    /** Specifies All access granted. **/
    AZSSharedAccessResourceTypesAll         =
            AZSSharedAccessResourceTypesService | AZSSharedAccessResourceTypesContainer | AZSSharedAccessResourceTypesObject
};

/** Specifies the sequence number operator to use in a sequence number access condition.*/
typedef NS_ENUM(NSInteger, AZSSequenceNumberOperator)
{
    /** Specifies no sequence number operator.*/
    AZSSequenceNumberOperatorNone,
    
    /** Specifies that the request should only complete if the sequence number on the blob is less than or equal to the sequence number in the access condition.*/
    AZSSequenceNumberOperatorLessThanOrEqualTo,

    /** Specifies that the request should only complete if the sequence number on the blob is less than the sequence number in the access condition.*/
    AZSSequenceNumberOperatorLessThan,
    
    /** Specifies that the request should only complete if the sequence number on the blob is equal to the sequence number in the access condition.*/
    AZSSequenceNumberOperatorEqualTo
};
