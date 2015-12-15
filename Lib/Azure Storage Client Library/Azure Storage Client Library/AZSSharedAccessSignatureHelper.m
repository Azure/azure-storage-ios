// -----------------------------------------------------------------------------------------
// <copyright file="AZSShareAccessSignatureHelper.m" company="Microsoft">
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
#import "AZSErrors.h"
#import "AZSOperationContext.h"
#import "AZSNavigationUtil.h"
#import "AZSSharedAccessBlobParameters.h"
#import "AZSSharedAccessHeaders.h"
#import "AZSSharedAccessSignatureHelper.h"
#import "AZSStorageUri.h"
#import "AZSUtil.h"
#import "AZSStorageCredentials.h"
#import "AZSUriQueryBuilder.h"

@implementation AZSSharedAccessSignatureHelper

+(AZSUriQueryBuilder *)sharedAccessSignatureForBlobWithParameters:(AZSSharedAccessBlobParameters *)parameters resourceType:(NSString *)resourceType signature:(NSString *)signature error:(NSError **)error
{
    if (!resourceType) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing resourceType argument."];
        return nil;
    }
    
    return [self sharedAccessSignatureWithPermissions:parameters.permissions sharedAccessStartTime:parameters.sharedAccessStartTime sharedAccessExpiryTime:parameters.sharedAccessExpiryTime startPartitionKey:nil startRowKey:nil endPartitionKey:nil endRowKey:nil headers:parameters.headers storedPolicyIdentifier:parameters.storedPolicyIdentifier resourceType:resourceType tableName:nil signature:signature error:error];
}

+(NSString *)sharedAccessSignatureHashForBlobWithParameters:(AZSSharedAccessBlobParameters *)parameters resourceName:(NSString *)resourceName client:(AZSCloudClient *)client error:(NSError **)error
{
    NSString *stringToSign = [self sharedAccessSignatureStringToSignWithPermissions:parameters.permissions sharedAccessStartTime:parameters.sharedAccessStartTime sharedAccessExpiryTime:parameters.sharedAccessExpiryTime resource:resourceName storedPolicyIdentifier:parameters.storedPolicyIdentifier error:error];
    
    if (!stringToSign) {
        // An error occurred. Error will have been set by sharedAccessSignatureStringToSignWithParameters.
        return nil;
    }
    
    stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@", stringToSign, [self emptyIfNilString:parameters.headers.cacheControl], [self emptyIfNilString:parameters.headers.contentDisposition], [self emptyIfNilString:parameters.headers.contentEncoding], [self emptyIfNilString:parameters.headers.contentLanguage], [self emptyIfNilString:parameters.headers.contentType]];
    return [self sharedAccessSignatureHashWithStringToSign:stringToSign credentials:[client credentials] error:error];
}

+(NSString *)emptyIfNilString:(NSString *)testString
{
    return (testString) ? testString : @"";
}

+(AZSUriQueryBuilder *)sharedAccessSignatureWithPermissions:(AZSSharedAccessPermissions)permissions sharedAccessStartTime:(NSDate *)startTime sharedAccessExpiryTime:(NSDate *)expiryTime startPartitionKey:(NSString *)startPartitionKey startRowKey:(NSString *)startRowKey endPartitionKey:(NSString *)endPartitionKey endRowKey:(NSString *)endRowKey headers:(AZSSharedAccessHeaders *)headers storedPolicyIdentifier:(NSString *)storedPolicyIdentifier resourceType:(NSString *)resourceType tableName:(NSString *)tableName signature:(NSString *)signature error:(NSError **)error
{
    if (!signature) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing signature argument."];
        return nil;
    }
    
    AZSUriQueryBuilder *builder = [[AZSUriQueryBuilder alloc] init];
    [builder addWithKey:@"sv" value: /* Target Storage Version */ @"2015-04-05"];
    [builder addIfNotNilOrEmptyWithKey:@"sp" value:[AZSSharedAccessSignatureHelper stringFromPermissions:permissions error:error]];
    
    if (*error) {
        // An error occurred.
        return nil;
    }
    
    NSString *startString = [AZSUtil utcTimeOrEmptyWithDate:startTime];
    [builder addIfNotNilOrEmptyWithKey:@"st" value:startString];
    
    NSString *expiryString = [AZSUtil utcTimeOrEmptyWithDate:expiryTime];
    [builder addIfNotNilOrEmptyWithKey:@"se" value:expiryString];
    
    [builder addIfNotNilOrEmptyWithKey:@"spk" value:startPartitionKey];
    [builder addIfNotNilOrEmptyWithKey:@"srk" value:startRowKey];
    [builder addIfNotNilOrEmptyWithKey:@"epk" value:endPartitionKey];
    [builder addIfNotNilOrEmptyWithKey:@"erk" value:endRowKey];
    
    [builder addIfNotNilOrEmptyWithKey:@"si" value:storedPolicyIdentifier];
    [builder addIfNotNilOrEmptyWithKey:@"sr" value:resourceType];
    
    [builder addIfNotNilOrEmptyWithKey:@"tn" value:tableName];
    
    [builder addIfNotNilOrEmptyWithKey:@"rscc" value:headers.cacheControl];
    [builder addIfNotNilOrEmptyWithKey:@"rsct" value:headers.contentType];
    [builder addIfNotNilOrEmptyWithKey:@"rsce" value:headers.contentEncoding];
    [builder addIfNotNilOrEmptyWithKey:@"rscl" value:headers.contentLanguage];
    [builder addIfNotNilOrEmptyWithKey:@"rscd" value:headers.contentDisposition];
    
    [builder addIfNotNilOrEmptyWithKey:@"sig" value:signature];
    
    return builder;
}

+(NSString *)sharedAccessSignatureHashWithStringToSign:(NSString *)stringToSign credentials:(AZSStorageCredentials *)credentials error:(NSError **)error
{
    if (!credentials) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Client is missing credentials."];
        return nil;
    }
    
    [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelInfo withMessage:@"String To Sign:\n%@", stringToSign];
    
    /* TODO: Add AZSUtil safeDecode */;
    return [AZSUtil computeHmac256WithString:stringToSign credentials:credentials];
}

+(NSString *)sharedAccessSignatureStringToSignWithPermissions:(AZSSharedAccessPermissions)permissions sharedAccessStartTime:(NSDate *)startTime sharedAccessExpiryTime:(NSDate *)expiryTime resource:(NSString *)resource storedPolicyIdentifier:(NSString *)storedPolicyIdentifier error:(NSError **)error
{
    if (!resource) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Missing resource argument."];
        return nil;
    }
    
    // Todo: Add ipRange and procols
    NSString *stringToSign = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n\n\n%@",
                              [self emptyIfNilString:[AZSSharedAccessSignatureHelper stringFromPermissions:permissions error:error]],
                              [AZSUtil utcTimeOrEmptyWithDate:startTime], [AZSUtil utcTimeOrEmptyWithDate:expiryTime],
            resource, [self emptyIfNilString:storedPolicyIdentifier], /* Target Storage Version */ @"2015-04-05"];
    return (*error) ? nil : stringToSign;
}

+(NSString *)stringFromPermissions:(AZSSharedAccessPermissions)permissions error:(NSError **)error
{
    if (permissions & ~AZSSharedAccessPermissionsAll) {
        *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
        [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized permissions argument."];
        return nil;
    }
    
    NSMutableString *builder = [[NSMutableString alloc] init];
    if (permissions & AZSSharedAccessPermissionsRead) {
        [builder appendString:@"r"];
    }
    if (permissions & AZSSharedAccessPermissionsAdd) {
        [builder appendString:@"a"];
    }
    if (permissions & AZSSharedAccessPermissionsCreate) {
        [builder appendString:@"c"];
    }
    if (permissions & AZSSharedAccessPermissionsWrite) {
        [builder appendString:@"w"];
    }
    if (permissions & AZSSharedAccessPermissionsDelete) {
        [builder appendString:@"d"];
    }
    if (permissions & AZSSharedAccessPermissionsList) {
        [builder appendString:@"l"];
    }
    
    return builder;
}

+(AZSSharedAccessPermissions)permissionsFromString:(NSString *)permissionString error:(NSError **)error
{
    AZSSharedAccessPermissions permissions = AZSSharedAccessPermissionsNone;
    
    for (int i = 0; i < permissionString.length; i++) {
        char c = [permissionString characterAtIndex:i];
        
        if (c == 'r') {
            permissions |= AZSSharedAccessPermissionsRead;
        }
        else if (c == 'a') {
            permissions |= AZSSharedAccessPermissionsAdd;
        }
        else if (c == 'c') {
            permissions |= AZSSharedAccessPermissionsCreate;
        }
        else if (c == 'w') {
            permissions |= AZSSharedAccessPermissionsWrite;
        }
        else if (c == 'd') {
            permissions |= AZSSharedAccessPermissionsDelete;
        }
        else if (c == 'l') {
            permissions |= AZSSharedAccessPermissionsList;
        }
        else {
            *error = [NSError errorWithDomain:AZSErrorDomain code:AZSEInvalidArgument userInfo:nil];
            [[AZSUtil operationlessContext] logAtLevel:AZSLogLevelError withMessage:@"Unrecognized permissions character."];
            return NSUIntegerMax;
        }
    }
    
    return permissions;
}

@end