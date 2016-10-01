//
//  AppDelegate.h
//  PictureEnglish
//
//  Created by 김인로 on 2016. 8. 16..
//  Copyright © 2016년 김인로. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, copy) void(^backgroundTransferCompletionHandler)();


@end

