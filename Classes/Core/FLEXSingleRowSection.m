//
//  FLEXSingleRowSection.m
//  FLEX
//
//  Created by Tanner Bennett on 9/25/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import "FLEXSingleRowSection.h"
#import "FLEXTableView.h"

@interface FLEXSingleRowSection ()
@property (nonatomic, readonly) NSString *reuseIdentifier;
@property (nonatomic, readonly) void (^cellConfiguration)(__kindof UITableViewCell *cell);

@property (nonatomic) NSAttributedString *lastTitle;
@property (nonatomic) NSAttributedString *lastSubtitle;
@end

@implementation FLEXSingleRowSection

#pragma mark - Public

+ (instancetype)title:(NSString *)title
                reuse:(NSString *)reuse
                 cell:(void (^)(__kindof UITableViewCell *))config {
    return [[self alloc] initWithTitle:title reuse:reuse cell:config];
}

- (id)initWithTitle:(NSString *)sectionTitle
              reuse:(NSString *)reuseIdentifier
               cell:(void (^)(__kindof UITableViewCell *))cellConfiguration {
    self = [super init];
    if (self) {
        _title = sectionTitle;
        _reuseIdentifier = reuseIdentifier ?: kFLEXDefaultCell;
        _cellConfiguration = cellConfiguration;
    }

    return self;
}

#pragma mark - Overrides

- (NSInteger)numberOfRows {
    if (self.filterMatcher && self.filterText.length) {
        return self.filterMatcher(self.filterText) ? 1 : 0;
    }
    
    return 1;
}

- (BOOL)canSelectRow:(NSInteger)row {
    return self.pushOnSelection || self.selectionAction;
}

- (void (^)(__kindof UIViewController *))didSelectRowAction:(NSInteger)row {
    return self.selectionAction;
}

- (UIViewController *)viewControllerToPushForRow:(NSInteger)row {
    return self.pushOnSelection;
}

- (NSString *)reuseIdentifierForRow:(NSInteger)row {
    return self.reuseIdentifier;
}

- (void)configureCell:(__kindof UITableViewCell *)cell forRow:(NSInteger)row {
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    self.cellConfiguration(cell);
    self.lastTitle = cell.textLabel.attributedText;
    self.lastSubtitle = cell.detailTextLabel.attributedText;
}

- (NSAttributedString *)titleForRow:(NSInteger)row {
    return self.lastTitle;
}

- (NSAttributedString *)subtitleForRow:(NSInteger)row {
    return self.lastSubtitle;
}

@end
