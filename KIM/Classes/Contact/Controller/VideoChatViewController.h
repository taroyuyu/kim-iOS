//
//  VideoChatViewController.h
//  HUTLife
//
//  Created by Kakawater on 2018/5/2.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KIMUser;
@interface VideoChatViewController : UIViewController
@property(nonnull,nonatomic,strong)KIMUser * peerUser;
@property(nonatomic,assign)KIMVideoChatRequestSessionType sessionType;
+(instancetype)callToFriend:(KIMUser*)peerUser sessionType:(KIMVideoChatRequestSessionType)sessionType;
+(instancetype)ringFrom:(KIMVideoChatRequest*)videoChatRequest;
@end
