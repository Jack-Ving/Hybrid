//
//  KJHybridTools.m
//  liantiao
//
//  Created by jack on 2017/8/9.
//  Copyright © 2017年 jack. All rights reserved.
//

#import "KJHybridTools.h"
#import "KJHybridModel.h"
#import "KJExtentsion.h"
#import "KJHybridViewController.h"
#import "ViewController.h"
#import "KJHybridHeader.h"

typedef enum : NSUInteger {
    Forward,
    ShowLoading,
    ShowToast,
    GET,
    POST,
    GetUserInfo,
} FunctionType;

NSString * HybridEvent = @"Hybrid.callback";

@implementation KJHybridTools

/**
 解析并执行hybrid指令

 @param urlString <#urlString description#>
 @param webView <#webView description#>
 @param appendParams 附加到指令串中topage地址的参数 一般情况下不需要
 */
- (void)analysis:(NSString *)urlString webView:(UIWebView *)webView appendParams:(NSDictionary *)appendParams {
    KJHybridModel * model;
    if (urlString) {
         model = [self contentResolver:urlString appendParams:appendParams];
    }
    [self handleEvent:model.function args:model.args callBackId:model.callbackId webView:webView];
    
}

/**
 解析hybrid指令

 @param urlStr <#urlStr description#>
 @param appendParams <#appendParams description#>
 @return 执行方法 参数 回调id
 */
- (KJHybridModel *)contentResolver:(NSString *)urlStr appendParams:(NSDictionary <NSString *,NSString *>*)appendParams {
    
    NSURL * url = [NSURL URLWithString:urlStr];
    if (!url) {
        return nil;
    }
    
    if ([url.scheme isEqualToString:@"lvka"]) {
        
        NSString * functionName = url.host;
        NSDictionary * paramDic = [url hybridURLParamsDic];
        
        NSMutableDictionary * args = [[paramDic[@"param"] hybridDecodeURLString] hybridDecodeJsonStr].mutableCopy;
        
        
        NSString * newTopageURL = [(args[@"topage"] ? args[@"topage"]: @"") hybridURLString:appendParams];
        if (newTopageURL) {
            [args setValue:newTopageURL forKey:@"topage"];
        }
        NSString * callBackId = paramDic[@"callback"] ? paramDic[@"callback"]:@"";
        

        return [KJHybridModel hybridWithFunction:functionName args:args callBackId:callBackId];
        
    }else {
        NSMutableDictionary * args = [NSMutableDictionary dictionaryWithObjectsAndKeys:urlStr,@"topage",@"h5",@"type", nil];
        NSString * newTopageURL = [urlStr hybridURLString:appendParams];
        if (newTopageURL) {
            [args setValue:newTopageURL forKey:@"topage"];
        }
        
        return [KJHybridModel hybridWithFunction:@"forward" args:args callBackId:@""];

    }
    
    return [KJHybridModel new];
}

- (void)handleEvent:(NSString *)funType args:(NSDictionary *)args callBackId:(NSString *)callbackID webView:(UIWebView *)webView {
    NSLog(@"funType = %@,args = %@,callbackID = %@",funType,args,callbackID);
    
    NSArray * indexArray = @[@"forward",@"showloading",@"showtoast",@"get",@"post",@"getinfo"];
    FunctionType functionType = [indexArray indexOfObject:funType];
    switch (functionType) {
        case Forward:{
            [self forward:args];
        }
            break;
        case ShowLoading:{
            [self showLoading:args];
        }
            break;
        case ShowToast:{
            [self showtoast:args];
        }
            break;
        case POST:{
            [self postCallBack:args web:webView callBack:callbackID];
        }
            break;
        case GET:{
            [self getCallBack:args web:webView callBack:callbackID];
        }
            break;
        case GetUserInfo: {
            [self getUserInfo:args wen:webView callback:callbackID];
        }break;
        default:
            break;
    }
    
    
    
    
}

#pragma mark - FunctionType 处理
- (void)forward:(NSDictionary *)args {
    NSString * type = args[@"type"];
    if ([type isEqualToString:@"h5"]) {
        NSString * urlStr = args[@"topage"];
        if (urlStr) {
            
            KJHybridViewController * webViewController = [KJHybridViewController load:urlStr sess:nil];
            webViewController.cookie = args[@"Cookie"] ? args[@"Cookie"] : @"";
            NSString * animate = args[@"animate"] ? args[@"animate"] : @"present";
            if ([animate isEqualToString:@"present"]) {
                UINavigationController * navi = [[UINavigationController alloc] initWithRootViewController:webViewController];
                [[self currentVC] presentViewController:navi animated:YES completion:^{
                    
                }];
            }else {
                UINavigationController * navi = [self currentNavi];
                if (navi) {
                    KJHybridViewController * vc = navi.viewControllers.lastObject;
                    if (vc) {
                        NSString * animate = args[@"animate"] ? args[@"animate"] : @"pop";
                        if ([animate isEqualToString:@"pop"]) {
                            vc.animateType =  AnimateTypePop;
                        }else {
                            vc.animateType = AnimateTypeNormal;
                        }
                    }
                    [navi pushViewController:webViewController animated:YES];
                }
            }
        }
    }else if([type isEqualToString:@"native"]) {
        
        NSString * topage = args[@"topage"] ? args[@"topage"] : @"";
        if ([topage isEqualToString:@"hahahahaahhah"]) {
            UINavigationController * navi = [self currentNavi];
            if (navi) {
                ViewController * vc = [ViewController new];
                [navi pushViewController:vc animated:YES];
            }
        }
        
        
    }
    
    
}

- (void)showLoading:(NSDictionary *)args {

    BOOL display = [args[@"display"] boolValue];
    if (display) {
        [MBProgressHUD showHUDAddedTo:[self windowView] animated:YES];
    }else {
        [MBProgressHUD hideHUDForView:[self windowView] animated:YES];
    }
}

- (void)showtoast:(NSDictionary *)args {
    
    NSString * title = args[@"title"];
    MBProgressHUD * hub = [MBProgressHUD showHUDAddedTo:[self windowView] animated:YES];
    hub.mode = MBProgressHUDModeText;
    hub.label.text = title;
    
    hub.offset = CGPointMake(0.f, MBProgressMaxOffset);

    [hub hideAnimated:YES afterDelay:2.f];
    
}

- (void)postCallBack:(NSDictionary *)args web:(UIWebView *)web callBack:(NSString *)callbackID {
    
    
    NSString * urlStr = args[@"url"];
    if (urlStr.length == 0) {
        return;
    }
    NSDictionary * body = args[@"param"];
    [[KJNetworkManage sharedManager] requestDataWithURLString:urlStr parameters:body Method:NetworkMethodPOST finished:^(id result, NSError *error) {
        NSInteger errCode = 0;
        NSString * msg = @"成功";
        if (error) {
            errCode = 1;
            msg = @"失败";
        }
        NSString * str = [self callBack:result errCode:errCode msg:msg callBack:callbackID webWeb:web];
        NSLog(@"POST = %@",str);

    }];
    
    
}

- (void)getCallBack:(NSDictionary *)args web:(UIWebView *)web callBack:(NSString *)callbackID {
    NSString * urlStr = args[@"url"];
    if (urlStr.length == 0) {
        return;
    }
    NSDictionary * body = args[@"param"];
    [[KJNetworkManage sharedManager] requestDataWithURLString:urlStr parameters:body Method:NetworkMethodGET finished:^(id result, NSError *error) {
        NSInteger errCode = 0;
        NSString * msg = @"成功";
        if (error) {
            errCode = 1;
            msg = @"失败";
        }
        NSString * str = [self callBack:result errCode:errCode msg:msg callBack:callbackID webWeb:web];
        NSLog(@"GET  = %@",str);
        
    }];
}

- (void)getUserInfo:(NSDictionary *)args wen:(UIWebView *)web callback:(NSString *)callbackID {
    
//    NSDictionary * userInf = [KJNetworkManage sharedManager].userInfo;
    NSDictionary * userInf = @{@"lvka":@"zhuda"};
    NSString * returnStr = [self callBack:userInf errCode:0 msg:@"userInfo" callBack:callbackID webWeb:web];
    NSLog(@"getUserInfo returnStr = %@",returnStr);
}

#pragma mark - 回调
- (id)callBack:(id)data errCode:(NSInteger)errCode msg:(NSString *)msg callBack:(NSString *)callback webWeb:(UIWebView *)webView {
    
    NSNumber *errC = [NSNumber numberWithInteger:errCode];
    NSDictionary * dataDic = [NSDictionary dictionaryWithObjectsAndKeys:
                              callback,@"callback",
                              errC,@"errno",
                              msg,@"msg",
                              data,@"data",
                              nil];
                              
    NSString * dataString = [dataDic hybridJSONString];
    
    return [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@(%@);",HybridEvent,dataString]];
}

#pragma mark - 视图控制器
- (UINavigationController *)currentNavi{
    UIViewController * vc = [self currentVC];
    if (vc) {
        if ([vc isKindOfClass:[UINavigationController class]]) {
            return (UINavigationController *)vc;
        }else if ([vc isKindOfClass:[UITabBarController class]]) {
            UITabBarController * currentVC = (UITabBarController *)vc;
            UIViewController * tabVC = currentVC.viewControllers[currentVC.selectedIndex];
            if ([tabVC isKindOfClass:[UINavigationController class]]) {
                return (UINavigationController *)tabVC;
            }else {
                return tabVC.navigationController ? tabVC.navigationController : nil;
            }
        }
        return vc.navigationController;
    }
    return nil;
}

- (UIViewController *)currentVC {
    UIViewController * vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController * currentVC = (UITabBarController *)vc;
        UIViewController * tabVC = currentVC.viewControllers[currentVC.selectedIndex];
        if ([tabVC isKindOfClass:[UINavigationController class]]) {
            UINavigationController * naviVC = (UINavigationController *)tabVC;
            return naviVC.viewControllers.lastObject;
        }
        return tabVC;
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController * naviVC = (UINavigationController *)vc;
        return naviVC.viewControllers.lastObject;
    } else {
        return vc;
    }
    return nil;
}

- (UIViewController *)viewControllerOf:(UIView *)view {
    UIResponder* nextResponder = view.nextResponder;
    while (!([nextResponder isKindOfClass:[UIViewController class]])) {
        nextResponder = nextResponder.nextResponder;
    }
    
    return (UIViewController *)nextResponder;
}
- (UIView *)windowView {
    return [UIApplication sharedApplication].keyWindow;

}
@end



