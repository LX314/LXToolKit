//
//  Macro.swift
//  Vaffle_demo
//
//  Created by DamonJow on 2018/10/26.
//  Copyright © 2018 DamonJow. All rights reserved.
//

import UIKit

// 是否是iPhone X系列
public let XL_IS_iPhoneX: Bool = (
    (UIScreen.instancesRespond(to: #selector(getter: UIScreen.main.currentMode))
        ? __CGSizeEqualToSize(CGSize(width: 375, height:812), UIScreen.main.bounds.size)
        : false)
        || (UIScreen.instancesRespond(to: #selector(getter: UIScreen.main.currentMode))
            ? __CGSizeEqualToSize(CGSize(width: 812, height:375), UIScreen.main.bounds.size)
            : false)
        || (UIScreen.instancesRespond(to: #selector(getter: UIScreen.main.currentMode))
            ? __CGSizeEqualToSize(CGSize(width: 414, height:896), UIScreen.main.bounds.size)
            : false)
        || (UIScreen.instancesRespond(to: #selector(getter: UIScreen.main.currentMode))
            ? __CGSizeEqualToSize(CGSize(width: 896, height:414), UIScreen.main.bounds.size)
            : false))

// 导航栏+状态栏高度
public let XL_NavBar_Height: CGFloat = XL_IS_iPhoneX ? 88.0 : 64.0

public let LX_Base_URL = "http://172.100.13.250:3003"
public let LX_Response_Logger_Max_Count = 200
public let LX_Request_Queue_label = Bundle.main.bundleIdentifier ?? "com.hg.lx"
