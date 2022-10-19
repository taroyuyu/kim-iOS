//
//  MessageModel.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger,MessageType)
{
    MessageType_ChatSession,
    MessageType_ChatGroupSession,
    MessageType_FriendApplication,
};

@interface MessageModel : NSObject<NSCoding>
@property(nonatomic,readonly)MessageType type;
@property(nonatomic,assign)NSInteger unReadCount;
@end

NS_ASSUME_NONNULL_END
