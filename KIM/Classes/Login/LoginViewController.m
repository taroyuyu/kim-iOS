//
//  LoginViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/16.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "LoginViewController.h"
#import "MainViewController.h"
#import "RegisterViewController.h"
#include "KIMClient.h"


@interface LoginViewController ()<CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *hutAccount;
@property (weak, nonatomic) IBOutlet UITextField *hutPasswordPassword;
@property(nonatomic,strong)CLLocationManager * locationManager;
@property(nonatomic,strong)NSCondition * locationCondition;
@property(nonatomic,assign)double latitude;
@property(nonatomic,assign)double longitude;
@end

@implementation LoginViewController

+(instancetype)loginController
{
    return [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"loginController"];
}

-(CLLocationManager*)locationManager
{
    if (self->_locationManager) {
        return self->_locationManager;
    }
    
    self->_locationManager = [[CLLocationManager alloc] init];
    self->_locationManager.delegate = self;
    return self->_locationManager;
}
-(NSCondition*)locationCondition
{
    if (self->_locationCondition) {
        return self->_locationCondition;
    }
    self->_locationCondition = [[NSCondition alloc] init];
    return self->_locationCondition;
}
- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    [manager stopUpdatingLocation];
    self.latitude = locations.firstObject.coordinate.latitude;
    self.longitude = locations.firstObject.coordinate.longitude;
    [self.locationCondition signal];
}

- (IBAction)loginButtonClicked:(UIButton *)sender {

    [[self hutAccount] resignFirstResponder];
    [[self hutPasswordPassword] resignFirstResponder];
    
    NSString *hutAccount = [[self hutAccount] text];
    NSString *hutPassword = [[self hutPasswordPassword] text];
    
    if (!hutAccount.length) {
        [MBProgressHUD showError:@"请输入要登陆的账号"];
    }
    if (!hutPassword.length) {
        [MBProgressHUD showError:@"请输入密码"];
    }
    
    self.latitude = 39.92;
    self.longitude = 116.46;
    if([CLLocationManager locationServicesEnabled]){//定位服务是否可用
        switch ([CLLocationManager authorizationStatus]) {
            case kCLAuthorizationStatusNotDetermined://还未请求
            {
                [self.locationManager requestWhenInUseAuthorization];
                return;
            }
                break;
            case kCLAuthorizationStatusAuthorizedAlways://允许
            case kCLAuthorizationStatusAuthorizedWhenInUse:
            {
                [self.locationManager startUpdatingLocation];
                [MBProgressHUD showMessage:@"正在登录"];
                __weak LoginViewController * weakSelf = self;
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    if (!weakSelf) {
                        return;
                    }
                    [weakSelf.locationCondition wait];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf loginWithUserAccount:hutAccount andPassword:hutPassword longitude:weakSelf.longitude andLatitude:weakSelf.latitude];
                    });
                });
            }
                break;
            case kCLAuthorizationStatusDenied://拒绝
            case kCLAuthorizationStatusRestricted:
            default:
            {
                goto reject;
            }
                break;
        }
    }else{
reject:
        [MBProgressHUD showMessage:@"正在登录"];
        [self loginWithUserAccount:hutAccount andPassword:hutPassword longitude:self.longitude andLatitude:self.latitude];
    }
}

-(void)loginWithUserAccount:(NSString*)userAccount andPassword:(NSString*)userPassword longitude:(double)longitude andLatitude:(double)latitude
{
    [((AppDelegate*)UIApplication.sharedApplication.delegate).imClient signInWithUserAccount:userAccount userPassword:userPassword longitude:longitude latitude:latitude andCompletion:^(KIMClient *imClient, NSError *error) {
        [MBProgressHUD hideHUD];
        if (error) {
            KIMClientLoginFailedType failedType = error.code;
            NSString * errorMessage = @"客户端内部错误";
            switch (failedType) {
                case KIMClientLoginFailedType_NetworkError:
                {
                    errorMessage = @"网络异常";
                }
                    break;
                case KIMClientLoginFailedType_ServerInternalError:
                {
                    errorMessage = @"服务器内部错误";
                }
                    break;
                case KIMClientLoginFailedType_WrongAccountOrPassword:
                {
                    errorMessage = @"用户名或者密码错误";
                }
                    break;
                default:
                {
                    errorMessage = @"客户端内部错误";
                }
                    break;
            }
            [MBProgressHUD showError:errorMessage];
            return;
        }
        [MBProgressHUD showSuccess:@"登陆成功"];
        [self performSelector:@selector(showMainViewController) withObject:nil afterDelay:1];
    }];
}

-(void)showMainViewController
{
    CATransition *transition = [CATransition animation];
    [transition setType:kCATransitionPush];
    transition.duration = 0.4;
    transition.subtype = kCATransitionFromLeft;
    [[[[[UIApplication sharedApplication] delegate] window] layer]addAnimation:transition forKey:nil];
    
    MainViewController *mainController = [MainViewController new];
    [[[[UIApplication sharedApplication] delegate] window] setRootViewController:mainController];
}

- (IBAction)registerButtonClicked:(UIButton *)sender {
    //创建核心动画
        CATransition *transition=[CATransition animation];
         //告诉要执行什么动画
         //设置过度效果
         transition.type=@"cube";
         //设置动画的过度方向（向右）
         transition.subtype=kCATransitionFromRight;
         //设置动画的时间
         transition.duration=0.4;
         //添加动画
    [[[[[UIApplication sharedApplication] delegate] window] layer]addAnimation:transition forKey:nil];
    
    [[[[UIApplication sharedApplication] delegate] window] setRootViewController:[RegisterViewController registeViewController]];
}

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.hutAccount resignFirstResponder];
    [self.hutPasswordPassword resignFirstResponder];
}



@end
