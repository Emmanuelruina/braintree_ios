#import <UIKit/UIKit.h>
#if __has_include("BraintreeUIKit.h")
#import "BraintreeUIKit.h"
#else
#import <BraintreeUIKit.h>
#endif

@interface BTEnrollmentVerificationViewController : UIViewController <UITextFieldDelegate, BTKFormFieldDelegate>
typedef void (^BTEnrollmentHandler)(NSString* authCode);

- (instancetype)initWithPhone:(NSString *)mobilePhoneNumber
            mobileCountryCode:(NSString *)mobileCountryCode
                      handler:(BTEnrollmentHandler)handler;
@end
