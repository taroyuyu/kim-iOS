//
//  CreateChatGroupViewController.m
//  HUTLife
//
//  Created by Kakawater on 2018/4/24.
//  Copyright © 2018年 Kakawater. All rights reserved.
//

#import "CreateChatGroupViewController.h"

@interface CreateChatGroupViewController ()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *groupAvatarButtonTopConstraint;
@property (weak, nonatomic) IBOutlet UIButton *groupAvatarButton;
@property (weak, nonatomic) IBOutlet UITextField *groupNameField;
@property (weak, nonatomic) IBOutlet UIButton *createGroupButton;
@end

@implementation CreateChatGroupViewController
+(instancetype)createChatGroupViewController
{
    CreateChatGroupViewController * viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"createChatGroupController"];
    
    return viewController;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setTitle:@"创建群"];
    
    [[self groupNameField]addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    
    [self textFieldEditingChanged:[self groupNameField]];
    
    //监听键盘事件
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyBoardWillChangedFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (IBAction)createGroupButtonClicked:(UIButton *)sender {
    KIMChatGroupModule * chatGroupModel = [[(AppDelegate*)[[UIApplication sharedApplication] delegate] imClient] chatGroupModule];
    NSString * groupName = [[[self groupNameField] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString * groupDescription = @"";
    [MBProgressHUD showMessage:@"正在创建"];
    [chatGroupModel createChatGroupWitGroupName:groupName groupDescription:groupDescription success:^(KIMChatGroupModule *chatGroupModule, KIMChatGroup *chatGroup) {
        [MBProgressHUD hideHUD];
        [MBProgressHUD showSuccess:@"创建成功"];
        [[self navigationController] popViewControllerAnimated:YES];
    } failure:^(KIMChatGroupModule *chatGroupModle, CreateChatGroupFailedType failedType) {
        [MBProgressHUD hideHUD];
        [MBProgressHUD showError:@"创建失败"];
        switch (failedType) {
            case CreateChatGroupFailedType_ModuleStoped:
            {
                NSLog(@"模块停止工作");
            }
                break;
            case CreateChatGroupFailedType_ParameterError:
            {
                NSLog(@"参数错误");
            }
                break;
            case CreateChatGroupFailedType_ClientInteralError:
            {
                NSLog(@"客户端内部错误");
            }
                break;
            case CreateChatGroupFailedType_NetworkError:
            {
                NSLog(@"网络异常");
            }
                break;
            case CreateChatGroupFailedType_Timeout:
            {
                NSLog(@"操作超时");
            }
                break;
            case CreateChatGroupFailedType_ServerInteralError:
            {
                NSLog(@"服务器内部错误");
            }
                break;
            default:
                break;
        }
    }];
}

- (void)textFieldEditingChanged:(UITextField *)textField
{
    if (textField != [self groupNameField]) {
        return;
    }
    
    if ([[[[self groupNameField] text]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
        [[self createGroupButton] setEnabled:YES];
        [[self createGroupButton]setBackgroundColor:[UIColor colorWithRed:0 green:157/255.0 blue:254/255.0 alpha:1.0f]];
    }else{
        [[self createGroupButton]setEnabled:NO];
        [[self createGroupButton]setBackgroundColor:[UIColor grayColor]];
    }
}

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [[self groupNameField] resignFirstResponder];
}

-(void)keyBoardWillChangedFrame:(NSNotification*)notification
{
    static BOOL isShowKeyboard = NO;
    static CGFloat changeHeight = 0;
    CGRect keyboardFrameBegin = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardFrameEnd = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGFloat changeY = keyboardFrameEnd.origin.y - keyboardFrameBegin.origin.y;
    
    if (changeY < 0) {
        if (!isShowKeyboard) {
            changeHeight = ABS(keyboardFrameEnd.origin.y - CGRectGetMaxY([[self groupNameField]frame]));
            [[self groupAvatarButtonTopConstraint] setConstant:[[self groupAvatarButtonTopConstraint]constant] - changeHeight];
            isShowKeyboard = YES;
        }
    }else if(changeY > 0) {
        if (isShowKeyboard) {
            [[self groupAvatarButtonTopConstraint] setConstant:[[self groupAvatarButtonTopConstraint]constant] + changeHeight];
            changeHeight = 0;
            isShowKeyboard = NO;
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
