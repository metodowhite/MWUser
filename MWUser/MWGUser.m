//
//  MWGUser.m
//
//  Created by Cristian Díaz on 18/02/14.
//  Copyright (c) 2014 metodowhite. All rights reserved.
//

#import "MWGUser.h"
#include <UICKeyChainStore/UICKeyChainStore.h>
#include <Parse.h>

@import Social;
@import Accounts;

@interface MWGUser ()
@property(strong, nonatomic) ACAccountStore *accountStore;
@property(strong, nonatomic) ACAccountType *accountType;
@property(strong, nonatomic) NSArray *availableTwitterAccounts;
@property(strong, nonatomic) ACAccount *userAccountInKeyChain;
@property(strong, nonatomic) NSString *uuid;
@property(strong, nonatomic) NSString *keychainServiceName;
@end

@implementation MWGUser

#pragma mark - Public Methods

+ (id)sharedMWGUser {
	static dispatch_once_t predicate;
	static MWGUser *instance = nil;
	dispatch_once(&predicate, ^{instance = [[self alloc] init];});
	return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
		#warning Set Service for Store, normally Reverse domain naming.
		self.keychainServiceName = @"com.yoursite";
    }
    return self;
}

- (void)loginRegisterViaTwitter {
    if ([self checkIfUserExistsInKeychain]) {
        [self loginParseUser];
    } else {
        [self registerViaTwitter];
    }
}

- (void)loginRegisterViafacebook {
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

- (void)registerViaFacebook {
    self.accountStore = [ACAccountStore new];
    self.accountType = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    
	#warning Required ACFacebookAppIdKey if special permissions asked.
	NSDictionary *options = @{ACFacebookAppIdKey:@"APP_ID_KEY",
                              ACFacebookPermissionsKey: @[@"email"]};
	
    [self.accountStore requestAccessToAccountsWithType:_accountType options:options completion:^(BOOL granted, NSError *error) {
		if (granted) {
			NSArray *accountsArr = [_accountStore accountsWithAccountType:_accountType];
			
			if ([accountsArr count]) {
				self.userAccountInKeyChain = [accountsArr lastObject];
				[self saveUserInKeyChain];
			}
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				NSLog(@"%@",error.description);
				if([error code]== ACErrorAccountNotFound) {
					[self throwAlertWithTitle:@"Facebook account not found." message:@"Please setup your account in settings app."];
				} else {
					[self throwAlertWithTitle:@"Error" message:@"Access to Facebook account was not granted."];
				}
			});
		}
	}];
}

#pragma mark - Keychain methods

- (BOOL)checkIfUserExistsInKeychain {
    if([[UICKeyChainStore keyChainStoreWithService:_keychainServiceName] stringForKey:@"uuid"] != nil) {
        self.uuid = [[UICKeyChainStore keyChainStoreWithService:_keychainServiceName] stringForKey:@"uuid"];
        self.userAccountInKeyChain = [NSKeyedUnarchiver unarchiveObjectWithData:[[UICKeyChainStore keyChainStoreWithService:_keychainServiceName] dataForKey:@"userAccount"]];
        return YES;
    } else {
        return NO;
    }
}

- (void)saveUserInKeyChain {
    UICKeyChainStore *store = [UICKeyChainStore keyChainStoreWithService:_keychainServiceName];
    self.uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [store setString:_uuid forKey:@"uuid"];
    
    NSData *userData = [NSKeyedArchiver archivedDataWithRootObject:_userAccountInKeyChain];
    [store setData:userData forKey:@"userAccount"];
    [store synchronize];
    
    [self registerParseUser];
}

#pragma mark - Parse Methods
#warning Parse must be configured in AppDelegate.m

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

@end
