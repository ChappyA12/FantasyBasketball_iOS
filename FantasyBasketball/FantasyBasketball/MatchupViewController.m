//
//  MatchupViewController.m
//  FantasyBasketball
//
//  Created by Chappy Asel on 1/17/15.
//  Copyright (c) 2015 CD. All rights reserved.
//

#import "MatchupViewController.h"
#import "FBWinProbablity.h"

@interface MatchupViewController ()

@property NSString *globalLink;

@property TFHpple *parser;
@property bool handleError;

@property (strong, nonatomic) NSMutableArray *playersTeam1;
@property int numStartersTeam1;
@property (strong, nonatomic) NSMutableArray *playersTeam2;
@property int numStartersTeam2;

@property NSArray *scoresTeam1;
@property JBBarChartView *barChartTeam1;
@property NSArray *scoresTeam2;
@property JBBarChartView *barChartTeam2;

@property NSMutableArray *cells;

@property NSMutableArray <NSString *> *pickerData;
@property NSString *selectedPickerData;
@property int scoringDay; //time of stats

@property FBWinProbablity *winProbability;

@property BOOL tableViewShowingWinProbabilityStatistics;

@property NSTimer *updateTimer;

@end

@implementation MatchupViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Matchup";
    _handleError = NO;
    self.tableViewShowingWinProbabilityStatistics = NO;
    self.cells = [[NSMutableArray alloc] init];
    [self setupTableView];
    [self setupBarCharts];
    [self loadPickerViewData];
    [self beginAsyncLoading];
}

- (void)beginAsyncLoading {
    dispatch_queue_t myQueue = dispatch_queue_create("Queue",NULL);
    dispatch_async(myQueue, ^{
        [self loadPlayersWithCompletionBlock:^(bool success, NSString *firstTeamName) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) [self showMatchupAlert];
                if (_handleError) return;
                [self loadScoresWithFirstTeamName:firstTeamName];
                [self.tableView reloadData];
            });
            if (success && !_handleError) {
                [_winProbability loadProjectionsWithUpdateBlock:^(int num, int total) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (num == total) [self updateProjectionDisplay];
                        else self.centerDisplay.text = [NSString stringWithFormat:@"%.0f%%",(float)num/(float)total*100];
                    });
                }];
            }
        }];
    });
}

- (void)refreshAsync {
    [self loadPlayersWithCompletionBlock:^(bool success, NSString *firstTeamName) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) [self showMatchupAlert];
            if (_handleError) return;
            [self loadScoresWithFirstTeamName:firstTeamName];
        });
    }];
    dispatch_queue_t myQueue = dispatch_queue_create("My Queue",NULL);
    dispatch_async(myQueue, ^{
        [_winProbability updateProjectionsWithCompletionBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateProjectionDisplay];
            });
        }];
    });
    [self.tableView reloadData];
}

- (void)showMatchupAlert {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Weekly Matchup Found"
                                                    message:@"The rest of the app is unlikely to function.\n\nThis message is to be expected in the offseason. \n\nIf you should have a game this week, check your league, team, season, and scoringID in the \"Settings\" tab."
                                                   delegate:self
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)initWithMatchupLink: (NSString *) link {
    self.globalLink = link;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(backButtonPressed:)];
}

- (IBAction)backButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)updateProjectionDisplay {
    self.team1Display3.text = [NSString stringWithFormat:@"%.0f",_winProbability.team1ProjScore];
    self.team2Display3.text = [NSString stringWithFormat:@"%.0f",_winProbability.team2ProjScore];
    if (_winProbability.team1WinPct > 50.0)
         self.centerDisplay.text = [NSString stringWithFormat:@"⇦ %.1f%%",_winProbability.team1WinPct];
    else self.centerDisplay.text = [NSString stringWithFormat:@"%.1f%% ⇨",100-_winProbability.team1WinPct];
    if (!self.tableViewShowingWinProbabilityStatistics) {
        self.tableViewShowingWinProbabilityStatistics = YES;
        self.cells = [[NSMutableArray alloc] init];
    }
    [self.tableView reloadData];
}

- (NSString *)matchupString {
    NSString *link = self.globalLink;
    if (link == nil) link = [NSString stringWithFormat:@"http://games.espn.com/fba/boxscorefull?leagueId=%@&teamId=%@&seasonId=%@",self.session.leagueID,self.session.teamID,self.session.seasonID];
    else link = [link substringToIndex:[link rangeOfString:@"&scoringPeriodId"].location];
    return [NSString stringWithFormat:@"%@&scoringPeriodId=%d&view=scoringperiod&version=full",link,_scoringDay];
}

- (void)loadPlayersWithCompletionBlock:(void (^)(bool success, NSString *firstTeamName)) completed {
    _numStartersTeam1 = 0, _numStartersTeam2 = 0;
    NSString *mS = [self matchupString];
    if(!_winProbability) {
        _winProbability = [[FBWinProbablity alloc] init];
        _winProbability.matchupLink = mS;
    }
    
    NSURL *url = [NSURL URLWithString:mS];
    NSError *error;
    NSData *html = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:&error];
    if (error) NSLog(@"Matchup error: %@",error);
    self.parser = [TFHpple hppleWithHTMLData:html];
    //table[@class='playerTableTable tableBody']/tr
    NSArray *nodes = [self.parser searchWithXPathQuery:@"//table[@class='playerTableTable tableBody']/tr"];
    self.playersTeam1 = [[NSMutableArray alloc] init];
    self.playersTeam2 = [[NSMutableArray alloc] init];
    if (nodes.count == 0) {
        NSLog(@"Error");
        completed(false, nil);
        _handleError = YES;
        return;
    }
    //team search
    TFHppleElement *name = [self.parser searchWithXPathQuery:@"//table[@id='playertable_0']/tr[@class='playerTableBgRowHead tableHead playertableTableHeader']/td"].firstObject;
    NSString *firstTeamName = [name.content stringByReplacingOccurrencesOfString:@" Box Score" withString:@""];
    _handleError = NO;
    int switchPoint = 0;
    bool switchValid = YES;
    for (int i = 0; i < nodes.count; i++) {
        TFHppleElement *element = nodes[i];
        if ([element objectForKey:@"id"]) {
            if (switchValid) switchPoint ++;
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            NSArray <TFHppleElement *> *children = element.children;
            [dict setObject:children[0].content forKey:@"isStarting"];
            [dict setObject:[children[1].children[0] content] forKey:@"firstName+lastName"];
            [dict setObject:[children[1].children[1] content] forKey:@"team+position"];
            if (children[1].children.count > 2 && ![((TFHppleElement *)children[1].children[2]).tagName isEqualToString:@"a"])
                [dict setObject:[children[1].children[2] content] forKey:@"injury"];
            [dict setObject:children[2].content forKey:@"isHome+opponent"];
            [dict setObject:children[3].content forKey:@"isPlaying+gameState+score+status"];
            if (![dict[@"isPlaying+gameState+score+status"] isEqualToString:@""]) [dict setObject: [[[children[3] childrenWithTagName:@"a"] firstObject] objectForKey:@"href"] forKey:@"gameLink"];
            [dict setObject:children[5].content forKey:@"gp"];
            [dict setObject:children[6].content forKey:@"min"];
            [dict setObject:children[7].content forKey:@"fgm"];
            [dict setObject:children[8].content forKey:@"fga"];
            [dict setObject:children[9].content forKey:@"ftm"];
            [dict setObject:children[10].content forKey:@"fta"];
            [dict setObject:children[11].content forKey:@"rebounds"];
            [dict setObject:children[12].content forKey:@"assists"];
            [dict setObject:children[13].content forKey:@"steals"];
            [dict setObject:children[14].content forKey:@"blocks"];
            [dict setObject:children[15].content forKey:@"turnovers"];
            [dict setObject:children[16].content forKey:@"points"];
            [dict setObject:children[18].content forKey:@"fantasyPoints"];
            //[dict setObject:[[element objectForKey:@"id"] substringFromIndex:4] forKey:@"playerID"];
            [self.playersTeam1 addObject:[[FBPlayer alloc] initWithDictionary:dict]];
        }
        else if (switchPoint != 0) switchValid = NO;
    }
    int len = (int)self.playersTeam1.count-switchPoint;
    for (int i = 0; i < len; i++) {
        [self.playersTeam2 addObject:[self.playersTeam1 objectAtIndex:switchPoint]];
        [self.playersTeam1 removeObjectAtIndex:switchPoint];
    }
    for (FBPlayer *player in self.playersTeam1) if(player.isStarting) _numStartersTeam1 ++;
    for (FBPlayer *player in self.playersTeam2) if(player.isStarting) _numStartersTeam2 ++;
    completed(true, firstTeamName);
}

- (void)loadScoresWithFirstTeamName: (NSString *)firstName {
    if (_handleError) return;
    
    /*
    NSMutableArray *images = [[NSMutableArray alloc] init];
    NSArray <TFHppleElement *> *nodes = [self.parser searchWithXPathQuery:@"//div[@id='teamInfos']/div/div/div/a/img"];
    
    for (TFHppleElement *node in nodes) {
        NSURL *url = [NSURL URLWithString:[node.attributes valueForKey:@"src"]];
        SVGKImage *image = [SVGKImage imageWithContentsOfURL:url];
        [images addObject:image];
    }
     */
    
    NSArray <TFHppleElement *> *nodes = [self.parser searchWithXPathQuery:@"//tr[@class='tableBody']"];
    bool te2 = (nodes.count > 1);
    NSString *team1Name = nodes[0].firstChild.content;
    NSString *team2Name = te2 ? nodes[1].firstChild.content : @"";
    int t1;
    int t2;
    if ([team1Name containsString:firstName]) {
        self.team1Display2.text = team1Name;
        self.team2Display2.text = team2Name;
        t1 = 0;
        t2 = 1;
    }
    else {
        self.team1Display2.text = team2Name;
        self.team2Display2.text = team1Name;
        t1 = 1;
        t2 = 0;
    }
    if (!te2) { //error detection (no opponent)
        t1 = 0;
        t2 = 0;
    }
    self.team1Display1.text = ((TFHppleElement *)nodes[t1].children.lastObject).content;
    self.team2Display1.text = ((TFHppleElement *)nodes[t2].children.lastObject).content;
    self.scoresTeam1 = @[    @"200", //acts as setter for height
                             ((TFHppleElement *)nodes[t1].children[2]).content,
                             ((TFHppleElement *)nodes[t1].children[3]).content,
                             ((TFHppleElement *)nodes[t1].children[4]).content,
                             ((TFHppleElement *)nodes[t1].children[5]).content,
                             ((TFHppleElement *)nodes[t1].children[6]).content,
                             ((TFHppleElement *)nodes[t1].children[7]).content,
                             ((TFHppleElement *)nodes[t1].children[8]).content];
    self.scoresTeam2 = @[    ((TFHppleElement *)nodes[t2].children[8]).content,
                             ((TFHppleElement *)nodes[t2].children[7]).content,
                             ((TFHppleElement *)nodes[t2].children[6]).content,
                             ((TFHppleElement *)nodes[t2].children[5]).content,
                             ((TFHppleElement *)nodes[t2].children[4]).content,
                             ((TFHppleElement *)nodes[t2].children[3]).content,
                             ((TFHppleElement *)nodes[t2].children[2]).content,
                             @"200"];
    [self.barChartTeam1 reloadData];
    [self.barChartTeam2 reloadData];
}

- (void)setupBarCharts {
    float width = self.scoreView.frame.size.width/2-15;
    self.barChartTeam1 = [[JBBarChartView alloc] init];
    self.barChartTeam1.frame = CGRectMake(-width/8, 0, width, 90);
    self.barChartTeam1.dataSource = self;
    self.barChartTeam1.delegate = self;
    self.barChartTeam1.inverted = YES;
    self.barChartTeam1.alpha = 0.5;
    self.barChartTeam1.userInteractionEnabled = NO;
    [self.scoreView addSubview:self.barChartTeam1];
    [self.scoreView sendSubviewToBack:self.barChartTeam1];
    
    self.barChartTeam2 = [[JBBarChartView alloc] init];
    self.barChartTeam2.frame = CGRectMake(width+2*15+width/8, 0, width, 90);
    self.barChartTeam2.dataSource = self;
    self.barChartTeam2.delegate = self;
    self.barChartTeam2.inverted = YES;
    self.barChartTeam2.alpha = 0.5;
    self.barChartTeam2.userInteractionEnabled = NO;
    [self.scoreView addSubview:self.barChartTeam2];
    [self.scoreView sendSubviewToBack:self.barChartTeam2];
}

- (void)setupTableView {
    self.tableView.contentOffset = CGPointMake(0, 0);
    [self setupTableHeaderView];
}

- (void)setupTableHeaderView {
    self.headerView = [[NSBundle mainBundle] loadNibNamed:@"MatchupHeaderView" owner:self options:nil].firstObject;
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.headerView.autorefreshSwitch addTarget:self action:@selector(autorefreshStateChanged:) forControlEvents:UIControlEventValueChanged];
    [self.headerView.expandStatsSwitch addTarget:self action:@selector(expandStateChanged:) forControlEvents:UIControlEventValueChanged];
    self.tableView.tableHeaderView = self.headerView;
    [self.tableView setContentOffset:CGPointMake(0,40)];
    self.updateTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:5 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
}

- (void)autorefreshStateChanged:(UISwitch *)sender{
    if (_handleError) return;
    if (sender.isOn) {
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
        [self timerFired:nil];
    }
    else {
        [self.updateTimer invalidate];
        self.updateTimer = nil;
    }
}

- (void)expandStateChanged:(UISwitch *)sender{
    if (_handleError) return;
    self.cells = [[NSMutableArray alloc] init];
    [self.tableView reloadData];
}

- (void)timerFired:(NSTimer *)timer {
    [self refreshButtonPressed:nil];
}

- (IBAction)refreshButtonPressed:(UIButton *)sender {
    [self refreshAsync];
    [self.tableView reloadData];
}

#pragma mark - bar charts delegate

- (NSUInteger)numberOfBarsInBarChartView:(JBBarChartView *)barChartView {
    return 8;
}

- (CGFloat)barChartView:(JBBarChartView *)barChartView heightForBarViewAtIndex:(NSUInteger)index {
    if (barChartView == self.barChartTeam1) return MAX(0, [self.scoresTeam1[index] floatValue]);
    return MAX(0, [self.scoresTeam2[index] floatValue]);
}

- (UIColor *)barChartView:(JBBarChartView *)barChartView colorForBarViewAtIndex:(NSUInteger)index {
    return [UIColor FBMediumOrangeColor];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.playersTeam1) return MAX(self.numStartersTeam1, self.numStartersTeam2);
    return 0;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 40;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.headerView.expandStatsSwitch.isOn) {
        if (self.tableViewShowingWinProbabilityStatistics) return 85; //dont forget to change at cellForRowAtIndexPath
        return 53;
    }
    return 41.846;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    float width = self.tableView.frame.size.width;
    UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40)];
    cell.backgroundColor = [UIColor FBMediumOrangeColor];
    //STATS LABELS
    float tot1 = 0;
    float tot2 = 0;
    if (section == 0) {
        for (int i = 0; i < self.numStartersTeam1; i++) {
            FBPlayer *player = self.playersTeam1[i];
            if (player.isPlaying) tot1 += player.fantasyPoints;
        }
        for (int i = 0; i < self.numStartersTeam2; i++) {
            FBPlayer *player = self.playersTeam2[i];
            if (player.isPlaying) tot2 += player.fantasyPoints;
        }
    }
    [_winProbability setTodayProjectionsToDayWithLink:[self matchupString]];
    UILabel *leftStats = [[UILabel alloc] initWithFrame:CGRectMake(width/2-50, 0, 50, 40)];
    leftStats.text = [NSString stringWithFormat:@"%.0f",tot1];
    leftStats.textAlignment = NSTextAlignmentCenter;
    leftStats.font = [UIFont boldSystemFontOfSize:20];
    leftStats.textColor = [UIColor whiteColor];
    [cell addSubview:leftStats];
    UILabel *leftStats2 = [[UILabel alloc] initWithFrame:CGRectMake(width/2-100, 0, 50, 40)];
    if (_winProbability.team1ProjScoreToday == 0) leftStats2.text = @"";
    else leftStats2.text = [NSString stringWithFormat:@"%.0f",_winProbability.team1ProjScoreToday];
    leftStats2.textAlignment = NSTextAlignmentCenter;
    leftStats2.font = [UIFont boldSystemFontOfSize:15];
    leftStats2.textColor = [UIColor colorWithWhite:1 alpha:.7];
    [cell addSubview:leftStats2];
    UILabel *rightStats = [[UILabel alloc] initWithFrame:CGRectMake(width/2, 0, 50, 40)];
    rightStats.text = [NSString stringWithFormat:@"%.0f",tot2];
    rightStats.textAlignment = NSTextAlignmentCenter;
    rightStats.font = [UIFont boldSystemFontOfSize:20];
    rightStats.textColor = [UIColor whiteColor];
    [cell addSubview:rightStats];
    UILabel *rightStats2 = [[UILabel alloc] initWithFrame:CGRectMake(width/2+50, 0, 50, 40)];
    if (_winProbability.team2ProjScoreToday == 0) rightStats2.text = @"";
    else rightStats2.text = [NSString stringWithFormat:@"%.0f",_winProbability.team2ProjScoreToday];
    rightStats2.textAlignment = NSTextAlignmentCenter;
    rightStats2.font = [UIFont boldSystemFontOfSize:15];
    rightStats2.textColor = [UIColor colorWithWhite:1 alpha:.7];
    [cell addSubview:rightStats2];
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FBPlayer *rightPlayer;
    FBPlayer *leftPlayer;
    if (self.playersTeam1.count!=0 && self.playersTeam1.count-1 >= indexPath.row+indexPath.section*_numStartersTeam1)
        leftPlayer = self.playersTeam1[indexPath.row+indexPath.section*_numStartersTeam1];
    if (self.playersTeam2.count!=0 && self.playersTeam2.count-1 >= indexPath.row+indexPath.section*_numStartersTeam2)
        rightPlayer = self.playersTeam2[indexPath.row+indexPath.section*_numStartersTeam2];
    if (self.cells.count >= indexPath.row+indexPath.section*_numStartersTeam1+1) {
        MatchupPlayerCell *cell = self.cells[indexPath.row+indexPath.section*_numStartersTeam1];
        if (!cell) {
            cell = [[NSBundle mainBundle] loadNibNamed:@"MatchupPlayerCell" owner:self options:nil].firstObject;
            [cell loadWithRightPlayer:rightPlayer leftPlayer:leftPlayer expanded:self.headerView.expandStatsSwitch.isOn];
            cell.delegate = self;
            cell.index = (int)indexPath.row;
            [self.cells addObject:cell];
        }
        else [cell updateWithRightPlayer:rightPlayer leftPlayer:leftPlayer];
        if (self.tableViewShowingWinProbabilityStatistics) {
            FBWinProbablityPlayer *rP = self.winProbability.team2Players[cell.rightPlayer.fullName];
            FBWinProbablityPlayer *lP = self.winProbability.team1Players[cell.leftPlayer.fullName];
            [cell loadWinProbabilityRightPlayer:rP leftPlayer:lP];
        }
        return cell;
    }
    MatchupPlayerCell *cell = [[NSBundle mainBundle] loadNibNamed:@"MatchupPlayerCell" owner:self options:nil].firstObject;
    [cell loadWithRightPlayer:rightPlayer leftPlayer:leftPlayer expanded:self.headerView.expandStatsSwitch.isOn];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.delegate = self;
    cell.index = (int)indexPath.row;
    [self.cells addObject:cell];
    if (self.tableViewShowingWinProbabilityStatistics) {
        FBWinProbablityPlayer *rP = self.winProbability.team2Players[cell.rightPlayer.fullName];
        FBWinProbablityPlayer *lP = self.winProbability.team1Players[cell.leftPlayer.fullName];
        [cell loadWinProbabilityRightPlayer:rP leftPlayer:lP];
    }
    return cell;
}

#pragma mark - FBPickerView

-(void)loadPickerViewData {
    _scoringDay = self.session.scoringPeriodID.intValue;
    self.selectedPickerData = @"Today";
    self.pickerData = [[NSMutableArray alloc] initWithArray: @[@"-", @"-", @"-", @"-", @"-", @"Yesterday", @"Today", @"Tomorrow", @"-", @"-", @"-", @"-", @"-"]];
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"E, MMM d"];
    for (int i = 1; i < 6; i++) { //days before
        date = [NSDate dateWithTimeIntervalSinceNow:-86400*i];
        self.pickerData[5-i] = [formatter stringFromDate:date];
    }
    for (int i = 2; i < 7; i++) { //days after
        date = [NSDate dateWithTimeIntervalSinceNow:86400*i];
        self.pickerData[6+i] = [formatter stringFromDate:date];
    }
}

-(void)fadeIn:(UIButton *)sender {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    FBPickerView *picker = [FBPickerView loadViewFromNib];
    picker.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    picker.delegate = self;
    [picker resetData];
    [picker setData:self.pickerData ForColumn:0];
    [picker selectString:self.selectedPickerData inColumn:0];
    [picker setAlpha:0.0];
    [self.view addSubview:picker];
    [UIView animateWithDuration:0.25 animations:^{
        [picker setAlpha:1.0];
    } completion: nil];
}

#pragma mark - FBPickerView delegate methods

- (void)doneButtonPressedInPickerView:(FBPickerView *)pickerView {
    int data1 = [pickerView selectedIndexForColumn:0];
    if (data1 != 6) {
        [self.headerView.autorefreshSwitch setOn: NO];
        self.headerView.autorefreshSwitch.enabled = NO;
    }
    else self.headerView.autorefreshSwitch.enabled = YES;
    self.selectedPickerData = [pickerView selectedStringForColumn:0];
    _scoringDay = self.session.scoringPeriodID.intValue-6+data1;
    if (_scoringDay != self.session.scoringPeriodID.intValue) {
        [self.headerView.autorefreshSwitch setOn:NO];
        [self autorefreshStateChanged:self.headerView.autorefreshSwitch];
    }
    self.cells = [[NSMutableArray alloc] init];
    [self refreshAsync];
    [self fadeOutWithPickerView:pickerView];
}

- (void)cancelButtonPressedInPickerView:(FBPickerView *)pickerView {
    [self fadeOutWithPickerView:pickerView];
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration {
    self.cells = [[NSMutableArray alloc] init];
    [self.tableView reloadData];
    [self.barChartTeam1 removeFromSuperview];
    [self.barChartTeam2 removeFromSuperview];
    [self performSelector:@selector(setupBarCharts) withObject:nil afterDelay:.2];
}

@end
