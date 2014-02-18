//
//  MWGUser.m
//
//  Created by Cristian Díaz on 18/02/14.
//  Copyright (c) 2014 metodowhite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface MWUserManager: NSObject<UIAlertViewDelegate>

@property (strong, nonatomic)RACSignal *loggingSignal;

-(void)loginRegisterViaTwitter;
-(void)loginRegisterViafacebook;

+ (instancetype)shared;


@end
