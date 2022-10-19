//
//  VCardEditViewController.h
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>
@class KIMUserVCard;
@interface VCardEditViewController : UITableViewController
@property(nonatomic,strong)KIMUserVCard *model;
+(instancetype)vCardEditController;
@end
