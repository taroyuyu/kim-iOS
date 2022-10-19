//
//  ChatGroupInfoViewController.h
//  HUTLife
//
//  Created by Kakawater on 2018/4/24.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>
@class KIMChatGroup;
@interface ChatGroupInfoViewController : UIViewController
+(instancetype)chatGroupInfoViewControllerWithChatGroup:(KIMChatGroup*)chatGroup;
@end
