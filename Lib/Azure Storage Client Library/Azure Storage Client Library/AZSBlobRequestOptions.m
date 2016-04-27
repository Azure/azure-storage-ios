// -----------------------------------------------------------------------------------------
// <copyright file="AZSBlobRequestOptions.m" company="Microsoft">
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

#import "AZSBlobRequestOptions.h"

@interface AZSBlobRequestOptions()
{
    BOOL _useTransactionalMD5Set;
    BOOL _storeBlobContentMD5Set;
    BOOL _disableContentMD5ValidationSet;
    BOOL _parallelismFactorSet;
    BOOL _absorbConditionalErrorsOnRetrySet;
}

@end

@implementation AZSBlobRequestOptions

@synthesize useTransactionalMD5 = _useTransactionalMD5;
@synthesize storeBlobContentMD5 = _storeBlobContentMD5;
@synthesize disableContentMD5Validation = _disableContentMD5Validation;
@synthesize parallelismFactor = _parallelismFactor;
@synthesize absorbConditionalErrorsOnRetry = _absorbConditionalErrorsOnRetry;

-(instancetype)init
{
    self = [super init];
    if (self)
    {
        // Set defaults for blob-specific options
        _useTransactionalMD5 = NO;
        _useTransactionalMD5Set = NO;
        _storeBlobContentMD5 = NO;
        _storeBlobContentMD5Set = NO;
        _disableContentMD5Validation = NO;
        _disableContentMD5ValidationSet = NO;
        _parallelismFactor = 3;
        _parallelismFactorSet = NO;
        _absorbConditionalErrorsOnRetry = NO;
        _absorbConditionalErrorsOnRetrySet = NO;
    }
    
    return self;
}

-(instancetype)copy
{
    AZSBlobRequestOptions *newOptions = [[AZSBlobRequestOptions alloc] init];
    [newOptions  applyDefaultsFromOptions:self];
    return newOptions;
}

-(instancetype)applyDefaultsFromOptions:(AZSBlobRequestOptions *)sourceOptions
{
    if (sourceOptions != nil)
    {
        [super applyDefaultsFromOptions:sourceOptions];
        // Apply blob-specific options.
        
        if (sourceOptions->_useTransactionalMD5Set)
        {
            self.useTransactionalMD5 = sourceOptions.useTransactionalMD5;
        }
        
        if (sourceOptions->_storeBlobContentMD5Set)
        {
            self.storeBlobContentMD5 = sourceOptions.storeBlobContentMD5;
        }
        
        if (sourceOptions->_disableContentMD5ValidationSet)
        {
            self.disableContentMD5Validation = sourceOptions.disableContentMD5Validation;
        }
        
        if (sourceOptions->_parallelismFactorSet)
        {
            self.parallelismFactor = sourceOptions.parallelismFactor;
        }
        
        if (sourceOptions->_absorbConditionalErrorsOnRetrySet)
        {
            self.absorbConditionalErrorsOnRetry = sourceOptions.absorbConditionalErrorsOnRetry;
        }
    }
    
    return self;
}

+(instancetype)copyOptions:(AZSBlobRequestOptions *)optionsToCopy
{
    if (optionsToCopy != nil)
    {
        return [optionsToCopy copy];
    }
    else
    {
        return [[AZSBlobRequestOptions alloc] init];
    }
}


-(BOOL)useTransactionalMD5
{
    return _useTransactionalMD5;
}

-(void)setUseTransactionalMD5:(BOOL)useTransactionalMD5
{
    _useTransactionalMD5 = useTransactionalMD5;
    _useTransactionalMD5Set = YES;
}

-(BOOL)storeBlobContentMD5
{
    return _storeBlobContentMD5;
}

-(void)setStoreBlobContentMD5:(BOOL)storeBlobContentMD5
{
    _storeBlobContentMD5 = storeBlobContentMD5;
    _storeBlobContentMD5Set = YES;
}

-(BOOL)disableContentMD5Validation
{
    return _disableContentMD5Validation;
}

-(void)setDisableContentMD5Validation:(BOOL)disableContentMD5Validation
{
    _disableContentMD5Validation = disableContentMD5Validation;
    _disableContentMD5ValidationSet = YES;
}

-(NSInteger)parallelismFactor
{
    return _parallelismFactor;
}

-(void)setParallelismFactor:(NSInteger)parallelismFactor
{
    _parallelismFactor = parallelismFactor;
    _parallelismFactorSet = YES;
}

-(BOOL)absorbConditionalErrorsOnRetry
{
    return _absorbConditionalErrorsOnRetry;
}

-(void)setAbsorbConditionalErrorsOnRetry:(BOOL)absorbConditionalErrorsOnRetry
{
    _absorbConditionalErrorsOnRetry = absorbConditionalErrorsOnRetry;
    _absorbConditionalErrorsOnRetrySet = YES;
}

@end
