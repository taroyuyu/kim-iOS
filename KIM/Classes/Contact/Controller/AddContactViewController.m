//
//  AddContactViewController.m
//  HUTLife
//
//  Created by Lingyu on 16/4/13.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "AddContactViewController.h"
@interface AddContactViewController ()<UITextFieldDelegate>
@property(nonatomic,strong)UITextField *searchField;
@property(nonatomic,strong)UIBarButtonItem *addBarButtonItem;
@end

@implementation AddContactViewController


-(UITextField*)searchField
{
    if (self->_searchField) {
        return self->_searchField;
    }
    
    CGFloat interval = 10;
    CGFloat searchFieldMarginLeft = interval;
    CGFloat searchFieldMarginTop = interval + 20;
    CGFloat searchFieldHeight = 42;
    CGFloat searchFieldWidth = [[self view] bounds].size.width - 2 * searchFieldMarginLeft;
    
    
    self->_searchField = [[UITextField alloc] initWithFrame:CGRectMake(searchFieldMarginLeft, searchFieldMarginTop, searchFieldWidth, searchFieldHeight)];
    
    [self->_searchField setPlaceholder:@"请输入联系人帐号"];
    self->_searchField.returnKeyType = UIReturnKeySearch;
    [self->_searchField setBorderStyle:UITextBorderStyleBezel];
    
    [self->_searchField setDelegate:self];
    [self->_searchField addTarget:self action:@selector(searchFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    return self->_searchField;
}

-(UIBarButtonItem*)addBarButtonItem
{
    if (self->_addBarButtonItem) {
        return self->_addBarButtonItem;
    }
    
    self->_addBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"添加" style:UIBarButtonItemStylePlain target:self action:@selector(addFriend)];
    
    return self->_addBarButtonItem;
}

-(void)addFriend
{
    KIMUser * target = [[KIMUser alloc]initWithUserAccount:self.searchField.text];
    KIMClient * imClient = ((AppDelegate*)UIApplication.sharedApplication.delegate).imClient;
    KIMRosterModule * rosterModule = imClient.rosterModule;
    
    if([imClient.currentUser isEqual:target]){
        [MBProgressHUD showError:[NSString stringWithFormat:@"您不能添加自己为好友"]];
    }else if([[rosterModule retriveFriendListFromLocalCache] containsObject:target]){
        [MBProgressHUD showError:[NSString stringWithFormat:@"%@已经是您的好友了",self.searchField.text]];
        return;
    }else{
        [rosterModule sendFriendApplicationToUser:target withIntroduction:@""];
    }

}


- (void)viewDidLoad {
    [super viewDidLoad];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    if ([[[self navigationController] navigationBar] isHidden]==NO) {
        [[self view] setBounds:CGRectMake(0, -[[[self navigationController] navigationBar] bounds].size.height, [[self view] bounds].size.width, [[self view] bounds].size.height)];
    }
    
    [[self navigationItem]setTitle:@"添加联系人"];
    
    [[self navigationItem] setRightBarButtonItem:[self addBarButtonItem]];
    self.addBarButtonItem.enabled =NO;
    
    [[self view] addSubview:[self searchField]];
}

-(void)searchFieldEditingChanged:(UITextField*)searchField
{
    self.addBarButtonItem.enabled = self.searchField.text.length >= 6;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.searchField resignFirstResponder];
}
@end
