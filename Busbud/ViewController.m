//
//  ViewController.m
//  Busbud
//
//  Created by Romain Pouclet on 2014-11-27.
//  Copyright (c) 2014 Romain Pouclet. All rights reserved.
//

#import "ViewController.h"
#import "BBClient.h"
#import "BBCity.h"
#import "Busbud-Swift.h"

#import <FXKeychain/FXKeychain.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
@import CoreLocation;

@interface ViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) BBClient *client;
@property (nonatomic, strong) CLLocationManager *manager;
@property (nonatomic, strong) BBCity *origin;
@property (nonatomic, strong) BBCity *destination;

@property (nonatomic, copy) NSArray *destinations;

@end

@implementation ViewController

- (void)viewDidLoad {
    self.client = [[BBClient alloc] initWithEndpoint: [NSURL URLWithString: @"https://busbud-napi-prod.global.ssl.fastly.net"]
                                              locale: NSLocale.currentLocale
                                            keychain: [FXKeychain defaultKeychain]];
    RAC(self.originCityField, text) = [[RACObserve(self, origin) deliverOn: RACScheduler.mainThreadScheduler] map:^id(BBCity *city) {
        return city.fullname;
    }];

    self.manager = [[CLLocationManager alloc] init];
    [self.manager requestWhenInUseAuthorization];
    self.manager.delegate = self;
    [self.manager startUpdatingLocation];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *scheduleUrl = [NSString stringWithFormat: @"https://www.busbud.com/%@/bus-schedules/%@/%@", [NSLocale.currentLocale objectForKey: NSLocaleLanguageCode], self.origin.url, self.destination.url];
    
    BrowserViewController *controller = (BrowserViewController *)segue.destinationViewController;
    controller.url = [NSURL URLWithString: scheduleUrl];
}

#pragma mark CLLocationManager
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Failed with error %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    [manager stopUpdatingLocation];
    NSLog(@"Locations = %@", locations);
    
    RACSignal *searchSignal = [[self.client search: nil around: locations.firstObject origin: nil] collect];
    [[[[[searchSignal map:^id(NSArray *results) {
        return results.firstObject;
    }] doNext: ^(BBCity *originCity) {
        self.origin = originCity;
    }] flattenMap:^RACStream *(BBCity *originCity) {
        return [[self.client search: nil around: nil origin: originCity] collect];
    }] deliverOn: RACScheduler.mainThreadScheduler] subscribeNext:^(NSArray *destinations) {
        NSLog(@"Destinations = %@", destinations);
        self.destinations = destinations;
    } completed:^{
        NSLog(@"Reload!");
        [self.tableView reloadData];
    }];
}

#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    NSString *title = @"😰😱😨"; // Not using localized strings because emojis are universal
    NSString *message = NSLocalizedString(@"SEARCH_ORIGIN_CITY_NOT_SUPPORTED", @"Warning message displayed on tap on origin city field");
    UIAlertController *controller = [UIAlertController alertControllerWithTitle: title
                                                                        message: message
                                                                 preferredStyle: UIAlertControllerStyleAlert];
    [controller addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"ALERT_DISMISS", @"Dismiss button label full of love")
                                                    style: UIAlertActionStyleDefault
                                                  handler: nil]];
    
    [self presentViewController: controller animated: YES completion: nil];

    return NO;
}

#pragma mark UITableViewDelegate / UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BBCity *city = self.destinations[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"CityCell" forIndexPath: indexPath];
    cell.textLabel.text = city.fullname;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.destination = self.destinations[indexPath.row];

    [self performSegueWithIdentifier: @"ToSchedules" sender: self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.destinations.count;
}

@end
