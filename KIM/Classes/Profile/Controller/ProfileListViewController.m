//
//  ProfileListViewController.m
//  HUT
//
//  Created by Lingyu on 16/2/16.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "ProfileListViewController.h"
#import "KIMClient.h"
#import "VCardViewController.h"
#import "AboutViewController.h"
#import "LoginViewController.h"
@interface ProfileListViewController ()
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userClassLabel;
@property (weak, nonatomic) IBOutlet UIImageView *userAvatarView;
@end

@implementation ProfileListViewController

+(instancetype)profileListController
{
    return [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"profileListController"];
}

-(void)loadView
{
    [super loadView];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[[self userAvatarView] layer] setCornerRadius:[[self userAvatarView] bounds].size.width/2];
    [[self userAvatarView]setClipsToBounds:YES];
    
    [self loadCurrentUserInfo];
}

-(void)loadCurrentUserInfo
{
    KIMRosterModule * rosterModule = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.rosterModule;
    KIMUserVCard * userVCard = [rosterModule retriveCurrentUserVCardFromLocalCache];
    if (userVCard) {
        if([[userVCard nickName] hasContent]){
            [[self userNameLabel] setText:[userVCard nickName]];
        }else{
            [[self userNameLabel] setText:userVCard.user.account];
        }
        
        if (userVCard.avatar) {
            self.userAvatarView.image = [UIImage imageWithData:userVCard.avatar];
        }
    }
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //监听用户电子名片更新通知
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userVCardUpdated:) name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
    
    [self loadCurrentUserInfo];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:KIMRosterModuleUserVCardUpdatedNotificationName object:nil];
}

-(void)userVCardUpdated:(NSNotification*)notification
{
    NSString * userAccount = [notification.userInfo objectForKey:@"user"];
    
    if ([userAccount isEqualToString:((AppDelegate*)UIApplication.sharedApplication.delegate).imClient.currentUser.account]) {
        [self loadCurrentUserInfo];
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch ([indexPath section]) {
        case 0:
        {
            if ([indexPath row] == 0) {
                VCardViewController *vCardController = [VCardViewController new];
                [[self navigationController] pushViewController:vCardController animated:YES];
            }
        }
            break;
        case 1:
        {
            if ([indexPath row] == 0) {
                [[self navigationController] pushViewController:[AboutViewController aboutController] animated:YES];

            }else if([indexPath row] == 1){
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提醒" message:@"您的真的要退出吗" preferredStyle:UIAlertControllerStyleActionSheet];
                UIAlertAction *exitAction = [UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {

                    [MBProgressHUD showMessage:@"正在退出"];
                    [((AppDelegate*)UIApplication.sharedApplication.delegate).imClient signOut];
                    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
                       [MBProgressHUD hideHUD];
                        CATransition *transition = [CATransition animation];
                        [transition setType:kCATransitionPush];
                        transition.duration = 0.4;
                        transition.subtype = kCATransitionFromRight;
                        [[[[[UIApplication sharedApplication] delegate] window] layer]addAnimation:transition forKey:nil];
                        [[[[UIApplication sharedApplication] delegate] window] setRootViewController:[LoginViewController loginController]];
                    }];
                }];
                UIAlertAction *cancleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
                [alertController addAction:cancleAction];
                [alertController addAction:exitAction];
                [self presentViewController:alertController animated:YES completion:nil];
            }
        }
        default:
            break;
    }
}

@end
