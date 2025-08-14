//
//  UILabel+Extension.m
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/13.
//

#import "UILabel+Extension.h"

@implementation UILabel (Extension)


+ (instancetype)labelWithText:(NSString * _Nullable)text fontSize:(NSUInteger)size bold:(BOOL)isBold textColor:(UIColor * _Nullable)textColor {
    return [[self alloc] initWithText:text fontSize:size bold:isBold textColor:textColor];
}

- (instancetype)initWithText:(NSString * _Nullable)text fontSize:(NSUInteger)size bold:(BOOL)isBold textColor:(UIColor * _Nullable)textColor {
    if (self = [super init]) {
        self.text = text;
        self.font = isBold ? [UIFont fontWithName:@"PingFangSC-Medium" size: size] : [UIFont fontWithName:@"PingFang SC" size: size];
        self.textColor = textColor == nil ? RGBA(0, 0, 0, 1) : textColor;
        self.textAlignment = NSTextAlignmentCenter;
    }
    return self;
}

@end
