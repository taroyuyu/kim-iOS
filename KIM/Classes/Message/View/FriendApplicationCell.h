//
//  FriendApplicationCell.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/23.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
@interface FriendApplicationCell : UITableViewCell
@property(nonatomic,readonly)UIImageView *avatar;
@property(nonatomic,readonly)UILabel * peerUserName;
@property(nonatomic,readonly)UILabel * introduction;
@property(nonatomic,readonly)UIButton * handleButton;
@end
