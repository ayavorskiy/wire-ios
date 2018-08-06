// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 

@import PureLayout;
@import WireExtensionComponents;
@import OnePasswordExtension;

#import "EmailSignInViewController.h"

#import "RegistrationTextField.h"
#import "NSURL+WireLocale.h"
#import "Wire-Swift.h"

static NSString* ZMLogTag ZM_UNUSED = @"UI";

@interface EmailSignInViewController () <RegistrationTextFieldDelegate>

@property (nonatomic) RegistrationTextField *emailField;
@property (nonatomic) RegistrationTextField *passwordField;
@property (nonatomic) ButtonWithLargerHitArea *forgotPasswordButton;
@property (nonatomic) ButtonWithLargerHitArea *companyLoginButton;

/// After a login try we set this property to @c YES to reset both field accessories after a field change on any of those
@property (nonatomic) BOOL needsToResetBothFieldAccessories;

@property (nonatomic, readonly) BOOL canStartCompanyLoginFlow;

@end


@interface EmailSignInViewController (AuthenticationObserver) <PreLoginAuthenticationObserver, PostLoginAuthenticationObserver>

@end


@implementation EmailSignInViewController

@synthesize authenticationCoordinator;

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    [self createEmailField];
    [self createPasswordField];
    [self createForgotPasswordButton];

    if (self.canStartCompanyLoginFlow) {
        [self createCompanyLoginButton];
    }

    [self createConstraints];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (AutomationHelper.sharedHelper.automationEmailCredentials != nil) {
        ZMEmailCredentials *emailCredentials = AutomationHelper.sharedHelper.automationEmailCredentials;
        self.emailField.text = emailCredentials.email;
        self.passwordField.text = emailCredentials.password;
        [self.passwordField.confirmButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    }

    [self takeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.emailField resignFirstResponder];
    [self.passwordField resignFirstResponder];
}

#pragma mark - Interface Configuration

- (void)createEmailField
{
    self.emailField = [[RegistrationTextField alloc] initForAutoLayout];

    if (@available(iOS 11, *)) {
        self.emailField.textContentType = UITextContentTypeUsername;
    }

    self.emailField.placeholder = NSLocalizedString(@"email.placeholder", nil);
    self.emailField.accessibilityLabel = NSLocalizedString(@"email.placeholder", nil);
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.returnKeyType = UIReturnKeyNext;
    self.emailField.keyboardAppearance = UIKeyboardAppearanceDark;
    self.emailField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailField.minimumFontSize = 15.0f;
    self.emailField.accessibilityIdentifier = @"EmailField";
    self.emailField.delegate = self;
    
    if (self.loginCredentials.emailAddress != nil) {
        // User was previously signed in so we prefill the credentials
        self.emailField.text = self.loginCredentials.emailAddress;
    }

    if (!self.canStartCompanyLoginFlow) {
        self.emailField.enabled = NO;
        self.emailField.alpha = 0.75;
    }

    [self.emailField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.emailField];
}

- (void)createPasswordField
{
    self.passwordField = [[RegistrationTextField alloc] initForAutoLayout];

    if (@available(iOS 11, *)) {
        self.passwordField.textContentType = UITextContentTypePassword;
    }

    self.passwordField.placeholder = NSLocalizedString(@"password.placeholder", nil);
    self.passwordField.accessibilityLabel = NSLocalizedString(@"password.placeholder", nil);
    self.passwordField.secureTextEntry = YES;
    self.passwordField.keyboardAppearance = UIKeyboardAppearanceDark;
    self.passwordField.accessibilityIdentifier = @"PasswordField";
    self.passwordField.returnKeyType = UIReturnKeyDone;
    self.passwordField.delegate = self;
    
    [self.passwordField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.passwordField.confirmButton addTarget:self action:@selector(signIn:) forControlEvents:UIControlEventTouchUpInside];
    self.passwordField.confirmButton.accessibilityLabel = NSLocalizedString(@"signin.confirm", @"");
    
    if (self.loginCredentials.password != nil) {
        // User was previously signed in so we prefill the credentials
        self.passwordField.text = self.loginCredentials.password;
        [self checkPasswordFieldAccessoryView];
    }
    
    if ([[OnePasswordExtension sharedExtension] isAppExtensionAvailable]) {
        UIButton *onePasswordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        NSBundle *frameworkBundle = [NSBundle bundleForClass:[OnePasswordExtension class]];
        UIImage *image = [UIImage imageNamed:@"onepassword-button" inBundle:frameworkBundle compatibleWithTraitCollection:nil];
        UIImage *onePasswordImage = [image imageWithColor:[UIColor lightGrayColor]];
        onePasswordButton.contentEdgeInsets = UIEdgeInsetsMake(0, 7, 0, 7);
        [onePasswordButton setImage:onePasswordImage forState:UIControlStateNormal];
        [onePasswordButton addTarget:self action:@selector(open1PasswordExtension:) forControlEvents:UIControlEventTouchUpInside];
        onePasswordButton.accessibilityLabel = NSLocalizedString(@"signin.use_one_password.label", @"");
        onePasswordButton.accessibilityHint = NSLocalizedString(@"signin.use_one_password.hint", @"");

        self.passwordField.customRightView = onePasswordButton;
        self.passwordField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewCustom;
    }
    
    [self.view addSubview:self.passwordField];
}

- (void)createForgotPasswordButton
{
    self.forgotPasswordButton = [ButtonWithLargerHitArea buttonWithType:UIButtonTypeCustom];
    self.forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.forgotPasswordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.forgotPasswordButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.4] forState:UIControlStateHighlighted];
    [self.forgotPasswordButton setTitle:[NSLocalizedString(@"signin.forgot_password", nil) uppercasedWithCurrentLocale] forState:UIControlStateNormal];
    self.forgotPasswordButton.titleLabel.font = UIFont.smallLightFont;
    [self.forgotPasswordButton addTarget:self action:@selector(resetPassword:) forControlEvents:UIControlEventTouchUpInside];

    self.forgotPasswordButton.accessibilityTraits |= UIAccessibilityTraitLink;
    [self.view addSubview:self.forgotPasswordButton];
}

- (void)createCompanyLoginButton
{
    self.companyLoginButton = [ButtonWithLargerHitArea buttonWithType:UIButtonTypeCustom];
    self.companyLoginButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.companyLoginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.companyLoginButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.4] forState:UIControlStateHighlighted];
    self.companyLoginButton.accessibilityIdentifier = @"companyLoginButton";
    [self.companyLoginButton setTitle:[NSLocalizedString(@"signin.company_idp.button.title", nil) uppercasedWithCurrentLocale] forState:UIControlStateNormal];
    self.companyLoginButton.titleLabel.font = UIFont.smallLightFont;
    [self.companyLoginButton addTarget:self action:@selector(companyLoginButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    self.companyLoginButton.accessibilityTraits |= UIAccessibilityTraitLink;
    [self.view addSubview:self.companyLoginButton];
}

- (void)createConstraints
{
    [self.emailField autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.emailField autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:28];
    [self.emailField autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:28];
    [self.emailField autoSetDimension:ALDimensionHeight toSize:40];
    
    [self.passwordField autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.emailField withOffset:8];
    [self.passwordField autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:28];
    [self.passwordField autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:28];
    [self.passwordField autoSetDimension:ALDimensionHeight toSize:40];
    
    if (self.canStartCompanyLoginFlow) {
        [self.forgotPasswordButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.passwordField withOffset:13];
        [self.forgotPasswordButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:13];
        [self.forgotPasswordButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view withOffset:28];
        [self.companyLoginButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.passwordField withOffset:13];
        [self.companyLoginButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:13];
        [self.companyLoginButton autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view withOffset:-28];
    } else {
        [self.forgotPasswordButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.passwordField withOffset:13];
        [self.forgotPasswordButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:13];
        [self.forgotPasswordButton autoAlignAxisToSuperviewAxis:ALAxisVertical];
    }
}

#pragma mark - Properties

- (ZMEmailCredentials *)credentials
{
    return [ZMEmailCredentials credentialsWithEmail:self.emailField.text
                                           password:self.passwordField.text];
}

- (BOOL)canStartCompanyLoginFlow
{
    return (CompanyLoginController.companyLoginEnabled == YES) && (self.loginCredentials.usesCompanyLogin == NO) && (self.loginCredentials.emailAddress == nil);
}

- (void)takeFirstResponder
{
    if (UIAccessibilityIsVoiceOverRunning()) {
        return;
    }
    if (@available(iOS 11, *)) {
        // A workaround for iOS11 not autofilling the password textfield (https://wearezeta.atlassian.net/browse/ZIOS-9080).
        // We need to put focus on the textfield as it seems to force iOS to "see" this texfield
        [self.passwordField becomeFirstResponder];
    }

    if (self.emailField.isEnabled) {
        [self.emailField becomeFirstResponder];
    } else {
        [self.passwordField becomeFirstResponder];
    }
}

#pragma mark - Actions

- (IBAction)signIn:(id)sender
{
    self.needsToResetBothFieldAccessories = YES;
    [self.authenticationCoordinator requestEmailLoginWithCredentials:self.credentials];
}

- (IBAction)resetPassword:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL.wr_passwordResetURL wr_URLByAppendingLocaleParameter]];
}

- (void)companyLoginButtonTapped:(ButtonWithLargerHitArea *)button
{
    if (self.canStartCompanyLoginFlow) {
        [self.authenticationCoordinator startCompanyLoginFlowIfPossible];
    }
}

- (IBAction)open1PasswordExtension:(id)sender
{
    @weakify(self);
    
    [[OnePasswordExtension sharedExtension] findLoginForURLString:NSURL.wr_websiteURL.absoluteString
                                                forViewController:self
                                                           sender:self.passwordField
                                                       completion:^(NSDictionary *loginDict, NSError *error)
     {
         @strongify(self);
         
         if (loginDict) {
             self.emailField.text = loginDict[AppExtensionUsernameKey];
             self.passwordField.text = loginDict[AppExtensionPasswordKey];
             [self checkPasswordFieldAccessoryView];
         }
     }];
}

#pragma mark - TextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.emailField) {
        [self.passwordField becomeFirstResponder];
        return NO;
    }
    else if (textField == self.passwordField && self.passwordField.rightAccessoryView == RegistrationTextFieldRightAccessoryViewConfirmButton) {
        [self.passwordField.confirmButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    if (textField == self.emailField) {
        return self.canStartCompanyLoginFlow;
    } else {
        return YES;
    }
}

#pragma mark - Field Validation

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.emailField && !self.canStartCompanyLoginFlow) {
        return NO;
    } else {
        return YES;
    }
}

- (void)textFieldDidChange:(UITextField *)textField
{
    // Special case: After a sign in try and text change we need to reset both accessory views
    if (self.needsToResetBothFieldAccessories && (textField == self.emailField || textField == self.passwordField)) {
        self.needsToResetBothFieldAccessories = NO;
        
        self.emailField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewNone;
        [self checkPasswordFieldAccessoryView];
    }
    else if (textField == self.emailField) {
        self.emailField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewNone;
    }
    else if (textField == self.passwordField) {
        [self checkPasswordFieldAccessoryView];
    }
}

- (void)checkPasswordFieldAccessoryView
{
    if (self.passwordField.text.length > 0) {
        self.passwordField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewConfirmButton;
    }
    else if ([[OnePasswordExtension sharedExtension] isAppExtensionAvailable]) {
        self.passwordField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewCustom;
    }
    else {
        self.passwordField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewNone;
    }
}

- (void)executeErrorFeedbackAction:(AuthenticationErrorFeedbackAction)feedbackAction
{
    if (feedbackAction == AuthenticationErrorFeedbackActionShowGuidanceDot) {
        self.emailField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewGuidanceDot;
        self.passwordField.rightAccessoryView = RegistrationTextFieldRightAccessoryViewGuidanceDot;
    }
}

@end
