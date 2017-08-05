//
//  IAPError.swift
//  InAppPurchaseDemo
//
//  Created by Lee on 2017/7/29.
//  Copyright © 2017年 arKen. All rights reserved.
//

import Foundation


/// 内购错误
///
/// - canNotMakePayments: 无法支付
/// - productNotFound: 找不到商品
/// - receiptDataNotFound: 找不到凭证
enum IAPError: Error {
    case canNotMakePayments
    case productNotFound(productId: String)
    case receiptDataNotFound
}

