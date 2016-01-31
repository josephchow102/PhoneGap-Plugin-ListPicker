#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface ListPicker : CDVPlugin <UIActionSheetDelegate, UIPopoverControllerDelegate, UIPickerViewDelegate> {
}

#pragma mark - Properties

@property (nonatomic, copy) NSString* callbackId;
@property (nonatomic, strong) UIPickerView *pickerView;
@property (nonatomic, strong) UIPopoverController *popoverController;
@property (nonatomic, strong) UIView *modalView;
@property (nonatomic, strong) NSDictionary *options;

// Multiple column storage properties
@property (nonatomic, assign) NSInteger numberOfColumns;
@property (nonatomic, strong) NSMutableArray *selectedRows;

#pragma mark - Instance methods

- (void)showPicker:(CDVInvokedUrlCommand*)command;

@end