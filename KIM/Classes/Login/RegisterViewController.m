//
//  RegisterViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "RegisterViewController.h"
#import "LoginViewController.h"

@interface RegisterViewController ()
@property (weak, nonatomic) IBOutlet UITextField *account;
@property (weak, nonatomic) IBOutlet UITextField *passwordFirst;
@property (weak, nonatomic) IBOutlet UITextField *passwordSecond;

@end

@implementation RegisterViewController

+(instancetype)registeViewController
{
    RegisterViewController *viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"registerController"];
    
    return viewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (IBAction)registerButtonClicked:(UIButton *)sender {
    NSString *registerAccount = [[self account] text];
    NSString *registerPasswordFirst = [[self passwordFirst] text];
    NSString *registerPasswordSecond = [[self passwordSecond] text];
    
    if ([registerAccount hasContent] == NO ) {
        [MBProgressHUD showError:@"请输入帐号"];
        return;
    }
    
    if ([registerPasswordFirst hasContent] == NO) {
        [MBProgressHUD showError:@"请输入密码"];
        return ;
    }
    
    if ([registerPasswordSecond hasContent] == NO) {
        [MBProgressHUD showError:@"请再次输入密码，以便确保两次输入的密码相同"];
        return ;
    }
    
    if ([registerPasswordFirst isEqualToString:registerPasswordSecond]) {
        [MBProgressHUD showMessage:@"正在注册"];
        
        [((AppDelegate*)UIApplication.sharedApplication.delegate).imClient signUpWithNodeServerAddr:@"172.16.181.131" nodeServerPort:1220 userAccount:registerAccount userPassword:registerPasswordFirst userNickName:nil userGender:KIMUserGender_Unknown andCompletion:^(KIMClient *imClient, NSError *error) {
            [MBProgressHUD hideHUD];
            if (error) {
                [MBProgressHUD showError:@"注册失败,用户名可能已经被注册"];
                return;
            }
            [MBProgressHUD showSuccess:@"注册成功"];
            [self performSelector:@selector(showLoginViewController) withObject:nil afterDelay:2];
        }];
    }else{
        [MBProgressHUD showError:@"两次输入的密码不相同"];
    }
    
}
- (IBAction)backBuutonClicked:(UIButton *)sender {
    [self showLoginViewController];
}

-(void)showLoginViewController
{
    //创建核心动画
    CATransition *transition=[CATransition animation];
    //告诉要执行什么动画
    //设置过度效果
    transition.type=@"cube";
    //设置动画的过度方向（向右）
    transition.subtype=kCATransitionFromLeft;
    //设置动画的时间
    transition.duration=0.4;
    //添加动画
    [[[[[UIApplication sharedApplication] delegate] window] layer]addAnimation:transition forKey:nil];
    
    [[[[UIApplication sharedApplication] delegate] window] setRootViewController:[[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateInitialViewController]];

}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [[self view] endEditing:YES];
}


@end
