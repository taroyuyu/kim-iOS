//
//  UIImage+Compress.m
//  HUTLife
//
//  Created by Lingyu on 16/4/18.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import "UIImage+Compress.h"

@implementation UIImage (Compress)
-(UIImage*)compressToSpecialSize:(CGSize)targetSize
{
    // 创建一个bitmap的context
    // 并把它设置成为当前正在使用的context
    UIGraphicsBeginImageContext(targetSize);
    // 绘制改变大小的图片
    [self drawInRect:CGRectMake(0,0, targetSize.width, targetSize.height)];
    // 从当前context中创建一个改变大小后的图片
    UIImage* scaledImage =UIGraphicsGetImageFromCurrentImageContext();
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    //返回新的改变大小后的图片
    return scaledImage;
}
@end
