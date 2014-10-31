//
//  UAStreamAdPlacementData.h
//  MoPub
//
//  Copyright (c) 2014 MoPub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class UAAdPositioning;
@class UANativeAdData;

@interface UAStreamAdPlacementData : NSObject

- (instancetype)initWithPositioning:(UAAdPositioning *)positioning;
- (void)insertAdData:(UANativeAdData *)data atIndexPath:(NSIndexPath *)adjustedIndexPath;
- (NSArray *)adjustedAdIndexPathsInAdjustedRange:(NSRange)range inSection:(NSInteger)section;
- (void)clearAdsInAdjustedRange:(NSRange)range inSection:(NSInteger)section;
- (NSIndexPath *)nextAdInsertionIndexPathForAdjustedIndexPath:(NSIndexPath *)adjustedIndexPath;
- (NSIndexPath *)previousAdInsertionIndexPathForAdjustedIndexPath:(NSIndexPath *)adjustedIndexPath;
- (BOOL)isAdAtAdjustedIndexPath:(NSIndexPath *)adjustedIndexPath;
- (NSArray *)adjustedIndexPathsWithAdsInSection:(NSUInteger)section;
- (UANativeAdData *)adDataAtAdjustedIndexPath:(NSIndexPath *)adjustedIndexPath;
- (NSUInteger)adjustedNumberOfItems:(NSUInteger)numberOfItems inSection:(NSUInteger)section;
- (NSIndexPath *)adjustedIndexPathForOriginalIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)originalIndexPathForAdjustedIndexPath:(NSIndexPath *)indexPath;
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;
- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection;
- (void)insertItemsAtIndexPaths:(NSArray *)originalIndexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray *)originalIndexPaths;
- (void)moveItemAtIndexPath:(NSIndexPath *)originalIndexPath toIndexPath:(NSIndexPath *)newIndexPath;

@end