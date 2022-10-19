//
//  AppDelegate.m
//  KIM
//
//  Created by 凌宇 on 2022/10/18.
//

#import "AppDelegate.h"
#import "LoginViewController.h"
@interface AppDelegate ()
@property(nonatomic,strong)UIColor* themeColor;
@property(nonatomic,strong)KIMClient * imClient;
@end

@implementation AppDelegate
-(UIColor*)themeColor
{
    if (self->_themeColor) {
        return self->_themeColor;
    }
    self->_themeColor = [UIColor colorWithRed:0 green:1.f*0xb4/0xff blue:1.f alpha:1.f];
    return self->_themeColor;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

    // 自定义导航栏背景
    [[UINavigationBar appearance] setBarTintColor:[self themeColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
    
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    
    [[UITabBar appearance] setTintColor:[self themeColor]];
    [[UITabBar appearance] setBackgroundColor:[UIColor whiteColor]];
    
    [[self window] setRootViewController:[LoginViewController loginController]];
    // 配置imClient
    NSMutableArray<RTCIceServer*> * iceServerList = [NSMutableArray<RTCIceServer*> array];
    [iceServerList addObject:[[RTCIceServer alloc] initWithURLStrings:@[@"stun:apprtc.kakawater.site:3478"]]];
    [iceServerList addObject:[[RTCIceServer alloc] initWithURLStrings:@[@"turn:apprtc.kakawater.site:3478?transport=udp",@"turn:apprtc.kakawater.site:3478?transport=tcp"] username:@"kakawater" credential:@"lingyu123"]];
    
    self.imClient = [[KIMClient alloc] initWithPresidentAddr:@"172.16.181.131" presidentPort:1221 andIceServers:[iceServerList copy]];
    return YES;
}
@end
