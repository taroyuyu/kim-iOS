//
//  ChatGroupSessionMessageModel.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "MessageModel.h"

NS_ASSUME_NONNULL_BEGIN
@interface ChatGroupSessionMessageModel : MessageModel
@property(nonatomic,copy)NSString * groupId;
@property(nonatomic,copy)NSString * groupName;
@property(nonatomic,strong)NSData * groupIcon;
@property(nonatomic,copy)NSString * content;
@end

NS_ASSUME_NONNULL_END
