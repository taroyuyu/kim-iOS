//
//  AppDelegate.h
//  KIM
//
//  Created by 凌宇 on 2022/10/18.
//

#import <UIKit/UIKit.h>
#import "KIMClient.h"
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (nonatomic,readonly) KIMClient * imClient;
@end

