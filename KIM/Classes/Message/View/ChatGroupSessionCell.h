//
//  ChatGroupSessionCell.h
//  HUTLife
//
//  Created by Kakawater on 2018/12/27.
//  Copyright © 2018 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatGroupSessionMessageModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface ChatGroupSessionCell : UITableViewCell
@property(nonatomic,strong)ChatGroupSessionMessageModel * model;
@end

NS_ASSUME_NONNULL_END
