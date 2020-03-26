//
//  FLEXRuntime+UIKitHelpers.m
//  FLEX
//
//  Created by Tanner Bennett on 12/16/19.
//  Copyright © 2019 Flipboard. All rights reserved.
//

#import "FLEXRuntime+UIKitHelpers.h"
#import "FLEXRuntimeUtility.h"
#import "FLEXPropertyAttributes.h"
#import "FLEXArgumentInputViewFactory.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXFieldEditorViewController.h"
#import "FLEXMethodCallingViewController.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "NSArray+Functional.h"
#import "NSString+FLEX.h"

#pragma mark FLEXProperty
@implementation FLEXProperty (UIKitHelpers)

/// Decide whether to use potentialTarget or [potentialTarget class] to get or set property
- (id)appropriateTargetForPropertyType:(id)potentialTarget {
    if (!object_isClass(potentialTarget)) {
        if (self.isClassProperty) {
            return [potentialTarget class];
        } else {
            return potentialTarget;
        }
    } else {
        if (self.isClassProperty) {
            return potentialTarget;
        } else {
            // Instance property with a class object
            return nil;
        }
    }
}

- (BOOL)isEditable {
    if (self.attributes.isReadOnly) {
        return self.likelySetterExists;
    }
    
    const FLEXTypeEncoding *typeEncoding = self.attributes.typeEncoding.UTF8String;
    return [FLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
}

- (BOOL)isCallable {
    return YES;
}

- (id)currentValueWithTarget:(id)object {
    return [self getPotentiallyUnboxedValue:
        [self appropriateTargetForPropertyType:object]
    ];
}

- (id)currentValueBeforeUnboxingWithTarget:(id)object {
    return [self getValue:
        [self appropriateTargetForPropertyType:object]
    ];
}

- (NSAttributedString *)previewWithTarget:(id)object {
    if (object_isClass(object) && !self.isClassProperty) {
        return self.attributes.fullDeclaration;
    } else {
        return [FLEXRuntimeUtility summaryForObject:[self currentValueWithTarget:object]];
    }
}

- (UIViewController *)viewerWithTarget:(id)object {
    id value = [self currentValueWithTarget:object];
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object {
    id target = [self appropriateTargetForPropertyType:object];
    return [FLEXFieldEditorViewController target:target property:self];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    id targetForValueCheck = [self appropriateTargetForPropertyType:object];
    if (!targetForValueCheck) {
        // Instance property with a class object
        return UITableViewCellAccessoryNone;
    }

    // We use .tag to store the cached value of .isEditable that is
    // initialized by FLEXObjectExplorer in -reloadMetada
    if ([self getPotentiallyUnboxedValue:targetForValueCheck]) {
        if (self.tag) {
            // Editable non-nil value, both
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // Uneditable non-nil value, chevron only
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.tag) {
            // Editable nil value, just (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // Non-editable nil value, neither
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

#if FLEX_AT_LEAST_IOS13_SDK

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    Class propertyClass = self.attributes.typeEncoding.flex_typeClass;
    
    // "Explore PropertyClass" for properties with a concrete class name
    if (propertyClass) {
        NSString *title = [NSString stringWithFormat:@"Explore %@", NSStringFromClass(propertyClass)];
        return @[[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
            UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:propertyClass];
            [sender.navigationController pushViewController:explorer animated:YES];
        }]];
    }
    
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    BOOL returnsObject = self.attributes.typeEncoding.flex_typeIsObjectOrClass;
    BOOL targetNotNil = [self appropriateTargetForPropertyType:object] != nil;
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:@[
        @"Name",                      self.name ?: @"",
        @"Type",                      self.attributes.typeEncoding ?: @"",
        @"Declaration",               self.fullDescription ?: @"",
    ]];
    
    if (targetNotNil) {
        id value = [self currentValueBeforeUnboxingWithTarget:object];
        [items addObjectsFromArray:@[
            @"Value Preview",         [self previewWithTarget:object],
            @"Value Address",         returnsObject ? [FLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"Getter",                    NSStringFromSelector(self.likelyGetter) ?: @"",
        @"Setter",                    self.likelySetterExists ? NSStringFromSelector(self.likelySetter) : @"",
        @"Image Name",                self.imageName ?: @"",
        @"Attributes",                self.attributes.string ?: @"",
        @"objc_property",             [FLEXUtility pointerToString:self.objc_property],
        @"objc_property_attribute_t", [FLEXUtility pointerToString:self.attributes.list],
    ]];
    
    return items;
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    id target = [self appropriateTargetForPropertyType:object];
    if (target && self.attributes.typeEncoding.flex_typeIsObjectOrClass) {
        return [FLEXUtility addressOfObject:[self currentValueBeforeUnboxingWithTarget:target]];
    }
    
    return nil;
}

#endif

@end


#pragma mark FLEXIvar
@implementation FLEXIvar (UIKitHelpers)

- (BOOL)isEditable {
    const FLEXTypeEncoding *typeEncoding = self.typeEncoding.UTF8String;
    return [FLEXArgumentInputViewFactory canEditFieldWithTypeEncoding:typeEncoding currentValue:nil];
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    if (!object_isClass(object)) {
        return [self getPotentiallyUnboxedValue:object];
    }

    return nil;
}

- (NSAttributedString *)previewWithTarget:(id)object {
    if (object_isClass(object)) {
        return self.details.attributedString;
    }
    return [FLEXRuntimeUtility summaryForObject:[self currentValueWithTarget:object]];
}

- (UIViewController *)viewerWithTarget:(id)object {
    NSAssert(!object_isClass(object), @"Unreachable state: viewing ivar on class object");
    id value = [self currentValueWithTarget:object];
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:value];
}

- (UIViewController *)editorWithTarget:(id)object {
    NSAssert(!object_isClass(object), @"Unreachable state: editing ivar on class object");
    return [FLEXFieldEditorViewController target:object ivar:self];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (object_isClass(object)) {
        return UITableViewCellAccessoryNone;
    }

    // Could use .isEditable here, but we use .tag for speed since it is cached
    if ([self getPotentiallyUnboxedValue:object]) {
        if (self.tag) {
            // Editable non-nil value, both
            return UITableViewCellAccessoryDetailDisclosureButton;
        } else {
            // Uneditable non-nil value, chevron only
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        if (self.tag) {
            // Editable nil value, just (i)
            return UITableViewCellAccessoryDetailButton;
        } else {
            // Non-editable nil value, neither
            return UITableViewCellAccessoryNone;
        }
    }
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

#if FLEX_AT_LEAST_IOS13_SDK

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    Class ivarClass = self.typeEncoding.flex_typeClass;
    
    // "Explore PropertyClass" for properties with a concrete class name
    if (ivarClass) {
        NSString *title = [NSString stringWithFormat:@"Explore %@", NSStringFromClass(ivarClass)];
        return @[[UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction *action) {
            UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:ivarClass];
            [sender.navigationController pushViewController:explorer animated:YES];
        }]];
    }
    
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    BOOL isInstance = !object_isClass(object);
    BOOL returnsObject = self.typeEncoding.flex_typeIsObjectOrClass;
    id value = isInstance ? [self getValue:object] : nil;
    
    NSMutableArray *items = [NSMutableArray arrayWithArray:@[
        @"Name",          self.name ?: @"",
        @"Type",          self.typeEncoding ?: @"",
        @"Declaration",   self.description ?: @"",
    ]];
    
    if (isInstance) {
        [items addObjectsFromArray:@[
            @"Value Preview", isInstance ? [self previewWithTarget:object] : @"",
            @"Value Address", returnsObject ? [FLEXUtility addressOfObject:value] : @"",
        ]];
    }
    
    [items addObjectsFromArray:@[
        @"Size",          @(self.size).stringValue,
        @"Offset",        @(self.offset).stringValue,
        @"objc_ivar",     [FLEXUtility pointerToString:self.objc_ivar],
    ]];
    
    return items;
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    if (!object_isClass(object) && self.typeEncoding.flex_typeIsObjectOrClass) {
        return [FLEXUtility addressOfObject:[self getValue:object]];
    }
    
    return nil;
}

#endif

@end


#pragma mark FLEXMethod
@implementation FLEXMethodBase (UIKitHelpers)

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    // Methods can't be "edited" and have no "value"
    return nil;
}

- (NSAttributedString *)previewWithTarget:(id)object {
    return [self.selectorString stringByAppendingFormat:@"  —  %@", self.typeEncoding].attributedString;
}

- (UIViewController *)viewerWithTarget:(id)object {
    // We disallow calling of FLEXMethodBase methods
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UIViewController *)editorWithTarget:(id)object {
    // Methods cannot be edited
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    // We shouldn't be using any FLEXMethodBase objects for this
    @throw NSInternalInconsistencyException;
    return UITableViewCellAccessoryNone;
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

#if FLEX_AT_LEAST_IOS13_SDK

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"Selector",      self.name ?: @"",
        @"Type Encoding", self.typeEncoding ?: @"",
        @"Declaration",   self.description ?: @"",
    ];
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

#endif

@end

@implementation FLEXMethod (UIKitHelpers)

- (BOOL)isCallable {
    return self.signature != nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    object = self.isInstanceMethod ? object : (object_isClass(object) ? object : [object class]);
    return [FLEXMethodCallingViewController target:object method:self];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    if (self.isInstanceMethod) {
        if (object_isClass(object)) {
            // Instance method from class, can't call
            return UITableViewCellAccessoryNone;
        } else {
            // Instance method from instance, can call
            return UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        return UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return [[super copiableMetadataWithTarget:object] arrayByAddingObjectsFromArray:@[
        @"NSMethodSignature *", [FLEXUtility addressOfObject:self.signature].string,
        @"Signature String",    self.signatureString ?: @"",
        @"Number of Arguments", @(self.numberOfArguments).stringValue,
        @"Return Type",         @(self.returnType ?: ""),
        @"Return Size",         @(self.returnSize).stringValue,
        @"objc_method",       [FLEXUtility pointerToString:self.objc_method].string,
    ]];
}

@end


#pragma mark FLEXProtocol
@implementation FLEXProtocol (UIKitHelpers)

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    return nil;
}

- (NSAttributedString *)previewWithTarget:(id)object {
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:self];
}

- (UIViewController *)editorWithTarget:(id)object {
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryDisclosureIndicator;
}

- (NSString *)reuseIdentifierWithTarget:(id)object { return nil; }

#if FLEX_AT_LEAST_IOS13_SDK

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    NSArray<NSString *> *conformanceNames = [self.protocols valueForKeyPath:@"name"];
    NSString *conformances = [conformanceNames componentsJoinedByString:@"\n"];
    return @[
        @"Name",         self.name ?: @"",
        @"Conformances", conformances,
    ];
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

#endif

@end


#pragma mark FLEXStaticMetadata
@interface FLEXStaticMetadata () {
    @protected
    NSAttributedString *_name;
}
@property (nonatomic) FLEXTableViewCellReuseIdentifier reuse;
@property (nonatomic) NSAttributedString *subtitle;
@property (nonatomic) id metadata;
@end

@interface FLEXStaticMetadata_Class : FLEXStaticMetadata
+ (instancetype)withClass:(Class)cls;
@end

@implementation FLEXStaticMetadata
@synthesize name = _name;
@synthesize tag = _tag;

+ (NSArray<FLEXStaticMetadata *> *)classHierarchy:(NSArray<Class> *)classes {
    return [classes flex_mapped:^id(Class cls, NSUInteger idx) {
        return [FLEXStaticMetadata_Class withClass:cls];
    }];
}

+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title string:(NSString *)string {
    return [[self alloc] initWithStyle:style title:title subtitle:string];
}

+ (instancetype)style:(FLEXStaticMetadataRowStyle)style title:(NSString *)title number:(NSNumber *)number {
    return [[self alloc] initWithStyle:style title:title subtitle:number.stringValue];
}

- (id)initWithStyle:(FLEXStaticMetadataRowStyle)style title:(NSString *)title subtitle:(NSString *)subtitle  {
    self = [super init];
    if (self) {
        if (style == FLEXStaticMetadataRowStyleKeyValue) {
            _reuse = kFLEXKeyValueCell;
        } else {
            _reuse = kFLEXMultilineDetailCell;
        }

        _name = title.attributedString;
        _subtitle = subtitle.attributedString;
    }

    return self;
}

- (NSString *)description {
    return self.name.string;
}

- (NSAttributedString *)attributedDescription {
    return self.name;
}

- (NSString *)reuseIdentifierWithTarget:(id)object {
    return self.reuse;
}

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isCallable {
    return NO;
}

- (id)currentValueWithTarget:(id)object {
    return nil;
}

- (NSAttributedString *)previewWithTarget:(id)object {
    return self.subtitle;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return nil;
}

- (UIViewController *)editorWithTarget:(id)object {
    return nil;
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryNone;
}

#if FLEX_AT_LEAST_IOS13_SDK

- (NSArray<UIAction *> *)additionalActionsWithTarget:(id)object sender:(UIViewController *)sender __IOS_AVAILABLE(13.0) {
    return nil;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[self.name.string, self.subtitle.string];
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    return nil;
}

#endif

@end


#pragma mark FLEXStaticMetadata_Class
@implementation FLEXStaticMetadata_Class

+ (instancetype)withClass:(Class)cls {
    NSParameterAssert(cls);
    
    FLEXStaticMetadata_Class *metadata = [self new];
    metadata.metadata = cls;
    metadata->_name = NSStringFromClass(cls).attributedString;
    metadata.reuse = kFLEXDefaultCell;
    return metadata;
}

- (id)initWithStyle:(FLEXStaticMetadataRowStyle)style title:(NSString *)title subtitle:(NSString *)subtitle {
    @throw NSInternalInconsistencyException;
    return nil;
}

- (UIViewController *)viewerWithTarget:(id)object {
    return [FLEXObjectExplorerFactory explorerViewControllerForObject:self.metadata];
}

- (UITableViewCellAccessoryType)suggestedAccessoryTypeWithTarget:(id)object {
    return UITableViewCellAccessoryDisclosureIndicator;
}

- (NSArray<NSString *> *)copiableMetadataWithTarget:(id)object {
    return @[
        @"Class Name", self.name.string,
        @"Class", [FLEXUtility addressOfObject:self.metadata].string
    ];
}

- (NSAttributedString *)contextualSubtitleWithTarget:(id)object {
    return [FLEXUtility addressOfObject:self.metadata];
}

@end
