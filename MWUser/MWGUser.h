//
//  MWGUser.h
//  Mowgli
//
//  Created by Cristian Díaz on 02/02/14.
//  Copyright (c) 2014 metodowhite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Parse/Parse.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface MWGUser: NSObject<UIAlertViewDelegate>

@property (strong, nonatomic)RACSignal *loggingSignal;
+(id)sharedMWGUser;
-(void)login;


@end
