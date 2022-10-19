//
//  ContactDetailViewController.h
//  HUTLife
//
//  Created by Lingyu on 16/4/6.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KIMUser;

@interface ContactDetailViewController : UIViewController
@property(nonatomic,strong)KIMUser *userModel;
+(instancetype)contactDetailControllerWithModel:(KIMUser*)model;
@end
