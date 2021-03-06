//
//  FBViewController.m
//  FantasyBasketball
//
//  Created by Chappy Asel on 7/31/15.
//  Copyright © 2015 CD. All rights reserved.
//

#import "FBViewController.h"

@interface FBViewController ()

@end

@implementation FBViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Menu"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(presentLeftMenuViewController:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                           target:self
                                                                                           action:@selector(fadeIn:)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.session = [FBSession fetchCurrentSession];
    self.watchList = [FBWatchList fetchWatchList];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.backgroundColor = [UIColor FBMediumOrangeColor];
    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - tableView dataSource

- (NSInteger) tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *) tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    return nil;
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration {
    [self.tableView reloadData];
}

#pragma mark - PlayerCell delegate

- (void)linkWithPlayer:(FBPlayer *)player {
    PlayerViewController *modalVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"p"];
    modalVC.modalPresentationStyle = UIModalPresentationCustom;
    modalVC.playerFirstName = player.firstName;
    modalVC.playerLastName = player.lastName;
    self.animator = [[ZFModalTransitionAnimator alloc] initWithModalViewController:modalVC];
    self.animator.dragable = YES;
    self.animator.bounces = YES;
    self.animator.behindViewAlpha = 0.8;
    self.animator.behindViewScale = 0.9;
    self.animator.transitionDuration = 0.3;
    self.animator.direction = ZFModalTransitonDirectionBottom;
    [self.animator setContentScrollView:modalVC.bottomScrollView];
    modalVC.transitioningDelegate = self.animator;
    [self presentViewController:modalVC animated:YES completion:nil];
}

- (void)linkWithGameLink:(FBPlayer *)player {
    SFSafariViewController *svc = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:player.gameLink]];
    svc.delegate = self;
    svc.preferredBarTintColor = [UIColor whiteColor];
    svc.preferredControlTintColor = [UIColor FBDarkOrangeColor];
    [self presentViewController:svc animated:YES completion:nil];
}

- (void)togglePlayer:(FBPlayer *)player WLStatusToState:(BOOL)isOnWL {
    if (isOnWL) {
        NSMutableArray *arr = [[NSMutableArray alloc] initWithArray:self.watchList.playerArray];
        [arr addObject:player.fullName];
        self.watchList.playerArray = arr;
    }
    else {
        NSMutableArray *arr = [[NSMutableArray alloc] initWithArray:self.watchList.playerArray];
        [arr removeObject:player.fullName];
        self.watchList.playerArray = arr;
    }
    NSManagedObjectContext *context = [(AppDelegate *)[[UIApplication sharedApplication] delegate] managedObjectContext];
    NSError *error;
    if (![context save:&error]) NSLog(@"failed to save in AppDelegate: %@", [error localizedDescription]);
}

#pragma mark - FBPickerView delegate

-(void) fadeIn:(UIButton *)sender {
    
}

-(void)fadeOutWithPickerView: (FBPickerView *) pickerView {
    [UIView animateWithDuration:0.2 animations:^{
        [pickerView setAlpha:0.0];
    } completion:^(BOOL finished) {
        [pickerView removeFromSuperview];
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }];
}

- (void)doneButtonPressedInPickerView:(FBPickerView *)pickerView {
    
}

- (void)cancelButtonPressedInPickerView:(FBPickerView *)pickerView {
    
}

#pragma mark - SFSafariView delegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    [self dismissViewControllerAnimated:true completion:nil];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
// Get the new view controller using [segue destinationViewController].
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
}

@end
