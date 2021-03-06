//
//  FBWinProbablityPlayer.m
//  FantasyBasketball
//
//  Created by Chappy Asel on 12/19/16.
//  Copyright © 2016 CD. All rights reserved.
//

#import "FBWinProbablityPlayer.h"
#import "FBPlayer.h"
#import "TFHpple.h"

@interface FBWinProbablityPlayer()

@property NSLock *gamesLock;

@end

@implementation FBWinProbablityPlayer

@synthesize games = _games;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.games = @[[NSNull null], [NSNull null], [NSNull null], [NSNull null],
                       [NSNull null], [NSNull null], [NSNull null]].mutableCopy;
        self.gamesLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)addGame:(FBWinProbabilityGame *)game atIndex:(int)index {
    [self.gamesLock lock];
    _games[index] = game;
    [self.gamesLock unlock];
}

- (void)setGames:(NSMutableArray *)games {
    [self.gamesLock lock];
    _games = games;
    [self.gamesLock unlock];
}

- (NSMutableArray *)games {
    [self.gamesLock lock];
    NSMutableArray *arr = _games.mutableCopy;
    [self.gamesLock unlock];
    return arr;
}

- (void)loadPlayerWithName:(NSString *)name completionBlock: (void (^)(void))completion {
    NSDictionary *playerName = [FBPlayer separateFirstAndLastNameForString:name];
    NSString *url = [NSString stringWithFormat:@"http://espn.go.com/nba/players/_/search/%@",[playerName[@"last"]stringByReplacingOccurrencesOfString:@" " withString:@"_"]];
    NSData *html = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    TFHpple *parser = [TFHpple hppleWithHTMLData:html];
    bool playerFound = NO;
    if ([[[[parser searchWithXPathQuery:@"//h1[@class='h2']"] firstObject] content] containsString:@"NBA Player Search -"]) { //couldnt find player first try
        for (TFHppleElement *p in [parser searchWithXPathQuery:@"//table[@class='tablehead']/tr"]) {
            if (![[p objectForKey:@"class"] isEqual:@"stathead"] && ![[p objectForKey:@"class"] isEqual:@"colhead"]) {
                NSArray <NSString *> *name = [p.firstChild.firstChild.content componentsSeparatedByString:@", "];
                bool localNFound = [name.lastObject rangeOfString:playerName[@"first"] options:NSCaseInsensitiveSearch].location == NSNotFound;
                if (!localNFound) { //player found
                    parser = [TFHpple hppleWithHTMLData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[p.firstChild.firstChild objectForKey:@"href"]]]];
                    playerFound = YES;
                    break;
                }
            }
        }
    }
    else playerFound = YES;
    if (playerFound) {
        self.firstName = playerName[@"first"];
        self.lastName = playerName[@"last"];
        NSMutableArray *fpts = [self fptsArrayWithParser:parser];
        //PARSE FPTS HERE INTO STATS
        float sum = 0;
        for (NSNumber *num in fpts) {
            sum += [num intValue];
        }
        self.average = sum/fpts.count;
        self.variance = [self varianceForArray:fpts withAverage:self.average];
        self.standardDeviation = sqrtf(self.variance);
    }
    else NSLog(@"PLAYER NOT FOUND IN TEAM COMPARISON");
    completion();
}

- (NSMutableArray<NSNumber *> *)fptsArrayWithParser: (TFHpple *) parser {
    NSArray *results = [parser searchWithXPathQuery:@"//div[@class='mod-content']/p[@class='footer']/a"];
    NSString *link = @"";
    for (TFHppleElement *e in results) if ([e.content containsString:@"Game Log"]) link = [e objectForKey:@"href"];
    NSString *url = [NSString stringWithFormat:@"http://espn.go.com%@",link];
    NSData *html = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    parser = [TFHpple hppleWithHTMLData:html];
    NSArray *tables = [parser searchWithXPathQuery:@"//div/table[@class='tablehead']"];
    TFHppleElement *table = nil;
    for (TFHppleElement *tble in tables) {
        if([[tble content] containsString:@"OPPSCOREMIN"]) { table = tble; break; } }
    NSMutableArray *rawGames = [[NSMutableArray alloc] init];
    if (table) { //error checking
        for (TFHppleElement *gameT in table.children) {
            if (![[gameT objectForKey:@"class"] isEqual:@"colhead"] &&
                ![[gameT objectForKey:@"class"] isEqual:@"total"] &&
                ![[gameT objectForKey:@"class"] isEqual:@"stathead"]) {
                NSMutableArray *game = [[NSMutableArray alloc] init];
                for (TFHppleElement *stat in gameT.children) [game addObject:stat.content];
                [rawGames addObject:game];
            }
            else if ([[gameT objectForKey:@"class"] isEqual:@"colhead"])
                if ([[gameT.children.firstObject content] containsString:@"REGULAR SEASON STATS"]) break; //end of reg season
        }
    }
    NSMutableArray *games = [[NSMutableArray alloc] init];
    for (NSMutableArray *rawGame in rawGames) {
        if (rawGame.count > 16) {
            NSArray *fg = [rawGame[4] componentsSeparatedByString:@"-"];
            NSArray *ft = [rawGame[8] componentsSeparatedByString:@"-"];
            NSNumber *fpts = [NSNumber numberWithInt:[fg[0] intValue]-[fg[1] intValue]+[ft[0] intValue]-[ft[1] intValue]-
                              [rawGame[15] intValue]+[rawGame[16] intValue]+[rawGame[13] intValue]+[rawGame[12] intValue]+[rawGame[11] intValue]+[rawGame[10] intValue]];
            if ([rawGame[3] intValue] != 0 || !([rawGame[2] containsString:@"W"] || [rawGame[2] containsString:@"L"]))
                [games addObject:fpts];
        }
    }
    return games;
}

- (float)varianceForArray:(NSMutableArray *)arr withAverage:(float)avg {
    float sumOfDiffs = 0;
    for (NSNumber *score in arr) sumOfDiffs += pow(([score intValue] - avg), 2);
    return sumOfDiffs / arr.count;
}

- (NSString *)description {
    return [NSString stringWithFormat: @"%@: %.1f %.1f scores: %@ injury: %d", self.lastName, self.average, self.variance, self.games, self.injuryStatus];
}

@end
