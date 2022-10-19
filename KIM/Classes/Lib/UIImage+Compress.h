//
//  UIImage+Compress.h
//  HUTLife
//
//  Created by Lingyu on 16/4/18.
//  Copyright © 2016年 Lingyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Compress)
/**
 *压缩到指定大小
 */
-(UIImage*)compressToSpecialSize:(CGSize)targetSize;
@end