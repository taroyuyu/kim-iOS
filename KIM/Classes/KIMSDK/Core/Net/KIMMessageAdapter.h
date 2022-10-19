//
//  KakaIMMessageAdapter.h
//  KakaIM
//
//  Created by taroyuyu on 2018/4/6.
//  Copyright © 2018年 taroyuyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KIMCircleBuffer.h"
#import "GPBProtocolBuffers.h"
@interface KIMMessageAdapter : NSObject
- (void)encapsulateMessageToByteStream:(GPBMessage * const)message outputBuffer:(KIMCircleBuffer * const)outputBuffer;
- (bool)tryToretriveMessage:(KIMCircleBuffer * const) inputBuffer message:(GPBMessage ** const)message;
@end
