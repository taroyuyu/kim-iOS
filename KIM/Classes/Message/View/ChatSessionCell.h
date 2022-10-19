//
//  ChatSessionCell.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSessionMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface ChatSessionCell : UITableViewCell
@property(nonatomic,strong)ChatSessionMessageModel * model;
@end

NS_ASSUME_NONNULL_END
