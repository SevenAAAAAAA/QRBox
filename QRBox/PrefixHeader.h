//
//  PrefixHeader.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/13.
//

/***屏幕缩放比例（相比于iphoneX)*/
#define ZOOMFACTORW (kScreenWidth) * 1.0 / 375
#define ZOOMW(x) (x) * ZOOMFACTORW
#define ZOOMFACTOR (kScreenHeight) * 1.0 / 812
#define ZOOM(x) (x) * ZOOMFACTOR

#define RGBA(R, G, B, A) [UIColor colorWithRed:R / 255.0 green:G / 255.0 blue:B / 255.0 alpha:A]
#define PingFangFont(isBold, size) \
    [UIFont fontWithName:(isBold ? @"PingFangSC-Medium" : @"PingFang SC") size:size]

//字符串是否为空
#define kStringIsEmpty(str) ([str isKindOfClass:[NSNull class]] || str == nil || [str length] < 1 ? YES : NO )

#import "YYKit.h"
#import "SVProgressHUD.h"
#import "UILabel+Extension.h"
