//
//  UILabel+Extension.h
//  QRBox
//
//  Created by 蒙俊竹 on 2025/8/13.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UILabel (Extension)

+ (instancetype)labelWithText:(NSString * _Nullable)text fontSize:(NSUInteger)size bold:(BOOL)isBold textColor:(UIColor * _Nullable)textColor;

- (instancetype)initWithText:(NSString * _Nullable)text fontSize:(NSUInteger)size bold:(BOOL)isBold textColor:(UIColor * _Nullable)textColor;


@end

NS_ASSUME_NONNULL_END
