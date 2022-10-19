//
//  ChatSessionMessageModel.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import "MessageModel.h"

NS_ASSUME_NONNULL_BEGIN
@interface ChatSessionMessageModel : MessageModel
@property(nonatomic,copy)NSString * peerAccount;
@property(nonatomic,copy)NSString * nickName;
@property(nonatomic,strong)NSData * avatar;
@property(nonatomic,copy)NSString * content;
@end

NS_ASSUME_NONNULL_END
