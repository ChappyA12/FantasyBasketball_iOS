//
//  AppDelegate.m
//  FantasyBasketball
//
//  Created by Chappy Asel on 1/14/15.
//  Copyright (c) 2015 CD. All rights reserved.
//

#import "AppDelegate.h"
#import "Session.h"
#import "TFHpple.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

Session *session;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    session = [Session sharedInstance];
    session.leagueID = 294156;
    session.teamID = 11;
    session.seasonID = 2015;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://games.espn.go.com/fba/clubhouse?leagueId=%d&teamId=%d&seasonId=%d&version=today",session.leagueID,session.teamID,session.seasonID]];
    NSData *html = [NSData dataWithContentsOfURL:url];
    TFHpple *parser = [TFHpple hppleWithHTMLData:html];
    NSString *XpathQueryString = @"//div[@class='playertablefiltersmenucontainer']/a";
    NSArray *nodes = [parser searchWithXPathQuery:XpathQueryString];
    NSString *string = [[nodes firstObject] objectForKey:@"onclick"];
    NSRange r = [string rangeOfString:@"scoringPeriodId="];
    int beg = (int)r.length + (int)r.location;
    int end = (int)[string rangeOfString:@"&view="].location;
    session.scoringPeriodID = [[string substringWithRange:NSMakeRange(beg, end-beg)] intValue];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
