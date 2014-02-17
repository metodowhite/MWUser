//
//  MWGUser.m
//  Mowgli
//
//  Created by Cristian Díaz on 02/02/14.
//  Copyright (c) 2014 metodowhite. All rights reserved.
//

#import "MWGUser.h"
#include <UICKeyChainStore/UICKeyChainStore.h>
@import Social;
@import Accounts;

@interface MWGUser ()
@property(nonatomic, strong) ACAccountStore *accountStore;
@property(nonatomic, strong) ACAccountType *accountType;
@property(nonatomic, strong) NSArray *availableTwitterAccounts;
@property(nonatomic, strong) ACAccount *userAccountInKeyChain;
@property(nonatomic, strong) NSString *uuid;
@end

@implementation MWGUser

#pragma mark - Public Methods

+ (id)sharedMWGUser {
	static dispatch_once_t predicate;
	static MWGUser *instance = nil;
	dispatch_once(&predicate, ^{instance = [[self alloc] init];});
	return instance;
}

- (void)login {
    if ([self checkIfUserExistsInKeychain]) {
        [self loginParseUser];
    } else {
        [self registerViaTwitter];
    }
}

#pragma mark - Private Methods

- (void)registerViaTwitter {
    self.accountStore = [ACAccountStore new];
    self.accountType = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [self.accountStore requestAccessToAccountsWithType:_accountType options:nil completion:^(BOOL granted, NSError *error) {
        if (granted) {
            _availableTwitterAccounts = [self.accountStore accountsWithAccountType:_accountType];
            
            if (_availableTwitterAccounts.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self throwAlertWithTitle:@"Twitter account not found"
                                      message:@"Please setup your account in settings app."];
                });
            } else if (_availableTwitterAccounts.count == 1) {
                self.userAccountInKeyChain = [_availableTwitterAccounts firstObject];
                [self saveUserInKeyChain];
            } else if (_availableTwitterAccounts.count > 1) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Select Twitter Account"
                                                                    message:nil
                                                                   delegate:[MWGUser sharedMWGUser]
                                                          cancelButtonTitle:@"Cancel"
                                                          otherButtonTitles:nil];
                    
                    for (ACAccount *twitterAccount in _availableTwitterAccounts) {
                        [alert addButtonWithTitle:twitterAccount.accountDescription];
                    }
                    [alert show];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self throwAlertWithTitle:@"Error" message:@"Access to Twitter accounts was not granted"];
            });
        }
    }];
}

#pragma mark - Keychain methods

- (BOOL)checkIfUserExistsInKeychain {
    if([[UICKeyChainStore keyChainStoreWithService:@"com.metodowhite"] stringForKey:@"uuid"] != nil) {
        self.uuid = [[UICKeyChainStore keyChainStoreWithService:@"com.metodowhite"] stringForKey:@"uuid"];
        self.userAccountInKeyChain = [NSKeyedUnarchiver unarchiveObjectWithData:[[UICKeyChainStore keyChainStoreWithService:@"com.metodowhite"] dataForKey:@"userAccount"]];
        return YES;
    } else {
        return NO;
    }
}

- (void)saveUserInKeyChain {
    UICKeyChainStore *store = [UICKeyChainStore keyChainStoreWithService:@"com.metodowhite"];
    self.uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [store setString:_uuid forKey:@"uuid"];
    
    NSData *userData = [NSKeyedArchiver archivedDataWithRootObject:_userAccountInKeyChain];
    [store setData:userData forKey:@"userAccount"];
    [store synchronize];
    
    [self registerParseUser];
}

#pragma mark - Parse Methods

- (void)loginParseUser {
    PFUser *currentUser = [PFUser currentUser];
    if (!currentUser) {
        [PFUser logInWithUsernameInBackground:_userAccountInKeyChain.username password:_uuid block:^(PFUser *user, NSError *saveUser) {
            if (user) {
                [self loginDone];
            } else {
                // The login failed. Check error to see why.
            }
        }];
    }else{
        [self loginDone];
    }
}

- (void)loginDone {
    self.loggingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
        [subscriber sendCompleted];
        return nil;
    }];
}


- (void)registerParseUser {
    PFUser *newParseUser = [PFUser user];
    newParseUser.username = _userAccountInKeyChain.username;
    newParseUser.password = _uuid;
    
    [newParseUser signUpInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        if (!error) {
            [self loginParseUser];
        } else {
            NSString *errorString = [error userInfo][@"error"];
            [self throwAlertWithTitle:@"Error" message:errorString];
			[self loginParseUser];
        }
    }];
}

#pragma mark - Alert Utils

- (void)throwAlertWithTitle:(NSString *)title message:(NSString *)msg {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:msg
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}



- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 0) {
        // User Canceled
        return;
    }
    
    NSInteger indexInAvailableTwitterAccountsArray = buttonIndex - 1;
    self.userAccountInKeyChain = [_availableTwitterAccounts objectAtIndex:indexInAvailableTwitterAccountsArray];
    [self saveUserInKeyChain];
}

//}
@end
