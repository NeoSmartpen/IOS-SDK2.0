//
//  NJNode.m
//  NISDK
//
//  Copyright (c) 2017 Neolab. All rights reserved.
//

#import "NJLinearFilter.h"

static float WEIGHT_GAUSSIAN_5[] = { 0.535139208712f, 0.191553166229f, 0.0358772294153f };
@implementation NJLinearFilter {
    float *weight;
    int length;
    float *raw_buffer;
}

- (id) init
{
    self = [super init];
    if (!self) return nil;

    weight = WEIGHT_GAUSSIAN_5;
    length = sizeof(WEIGHT_GAUSSIAN_5)/sizeof(float);
    float sum = weight[0];
    for (int i = 1; i < length; i++)
        sum += 2 * weight[i];
    float normalization = 1.0f / sum;
    for (int i = 0; i < length; i++)
        weight[i] *= normalization;
    raw_buffer = NULL;
    return self;
}
+ (NJLinearFilter *) sharedInstance
{
    static NJLinearFilter *shared = nil;
    
    @synchronized(self) {
        if(!shared){
            shared = [[NJLinearFilter alloc] init];
        }
    }
    return shared;
}
- (void) applyToX :(float *)x Y:(float *)y pressure:(float *)p size:(int)size
{
    if (raw_buffer != NULL) free(raw_buffer);
    raw_buffer = calloc(size, sizeof(float));
    [self apply:x size:size];
    [self apply:y size:size];
    [self apply:p size:size];
    free(raw_buffer);
    raw_buffer = NULL;
}
- (void) apply :(float *)x size:(int)size
{
    int N = size;
    memcpy(raw_buffer, x, sizeof(float)*size);
    int i;
    float sum, norm;
    
    // split [0 .. N-1] into [ 0, .., i_pre-1] + [i_pre, ..., i_post-1], [i_post, ..., N-1 ]
    // such that i_pre = length-1 and i_post = N-length if there is enough space
    int i_pre  = MIN(length-1, N/2);
    int i_post = MAX(N-length, N/2);
    
    for (i=0; i<i_pre; i++) {
        norm = weight[0];
        sum = raw_buffer[i] * weight[0];
        for (int n=1; n<=i; n++) {
            sum += (raw_buffer[i-n] + raw_buffer[i+n]) * weight[n];
            norm += 2 * weight[n];
        }
        //x[i] = sum / norm;
    }
    
    for (i=i_pre; i<i_post; i++) {
        sum = raw_buffer[i] * weight[0];
        for (int n=1; n<length; n++)
            sum += (raw_buffer[i-n] + raw_buffer[i+n]) * weight[n];
        x[i] = sum;
    }
    
    for (i=i_post; i<N; i++) {
        norm = weight[0];
        sum = raw_buffer[i] * weight[0];
        for (int n=1; n<N-i; n++) {
            sum += (raw_buffer[i-n] + raw_buffer[i+n]) * weight[n];
            norm += 2 * weight[n];
        }
        x[i] = sum / norm;
    }
}
@end
