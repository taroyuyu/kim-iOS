//
//  ContactCell.h
//  HUTLife
//
//  Created by Lingyu on 16/4/6.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KIMUser;

@interface ContactCell : UITableViewCell
@property(nonatomic,strong)KIMUser *model;
@property(nonatomic,strong)UIImageView *userAvator;
@property(nonatomic,strong)UILabel *userName;
@property(nonatomic,strong)UILabel * onlineState;
+(instancetype)cellWithTableView:(UITableView*)tableView andModel:(KIMUser*)model;
@end
