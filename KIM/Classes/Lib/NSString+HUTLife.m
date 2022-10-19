//
//  NSString+HUTLife.m
//  HUTLife
//
//  Created by Lingyu on 16/4/17.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "NSString+HUTLife.h"

@implementation NSString (HUTLife)
//当NSString指针为nil时，即hasContent不能响应时，返回NO，表示没有内容
-(BOOL)hasContent
{
    NSString *trimmedString = [self stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([trimmedString isEqualToString:@""]) {
        //没有内容
        return NO;
    }else{
        //有内容
        return YES;
    }
}
-(NSInteger)toIntegetValue
{
     return [[[self componentsSeparatedByCharactersInSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]] componentsJoinedByString:@""] integerValue];
}
@end
