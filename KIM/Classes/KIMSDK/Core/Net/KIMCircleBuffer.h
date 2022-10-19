//
//  CircleBuffer.h
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KIMCircleBuffer : NSObject
@property(nonatomic,readonly)size_t used;
-(instancetype)initWithInitialCapacity:(size_t)initialCapacity;
-(void)appendContent:(const void * )buffer bufferLength:(const size_t) bufferLength;
-(size_t)retriveWithBuffer:(const void *)buffer bufferLength:(const size_t) bufferCapacity;
-(size_t)headWithBuffer:(const void *)buffer bufferLength:(const size_t) bufferLength;
@end
