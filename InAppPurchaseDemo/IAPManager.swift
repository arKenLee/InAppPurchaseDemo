//
//  IAPManager.swift
//  InAppPurchaseDemo
//
//  Created by Lee on 2017/7/17.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import StoreKit


final class IAPManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
    typealias FailureHandler = (Error)->Void
    
    typealias ProductsSuccessHandler = (Array<SKProduct>)->Void
    typealias PurchaseSuccessHandler = (SKPaymentTransaction)->Void
    typealias RestorePurchaseSuccessHandler = (Array<SKPaymentTransaction>)->Void
    
    typealias VerifyTransactionSuccessHandler = (Data?, URLResponse?)->Void
    typealias VerifyTransactionFailureHandler = (Error) -> Void
    
    private typealias ProductRequestTuple = (request: SKProductsRequest, success: ProductsSuccessHandler?, failure: FailureHandler?)
    private typealias PaymentTuple = (productIdentifier: String, success: PurchaseSuccessHandler?, failure: FailureHandler?)

    
    // MARK: Properties
    
    class var shared: IAPManager {
        return sharedInstance
    }
    
    private static let sharedInstance = IAPManager()
    
    private var productRequests = [ProductRequestTuple]()
    private var payments = [PaymentTuple]()
    private var restoreTransactions = [SKPaymentTransaction]()
    
    private var restorePurchaseSuccessHandler: RestorePurchaseSuccessHandler?
    private var restorePurchaseFailureHandler: FailureHandler?
    
    
    // MARK: Lifecycle
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    
    // MARK: Products
    
    /// 获取单个商品
    ///
    /// - Parameters:
    ///   - productId: 商品id
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func fetchProduct(for productId: String, success: IAPManager.ProductsSuccessHandler?, failure: IAPManager.FailureHandler?) {
        fetchProducts(for: [productId], success: success, failure: failure)
    }
    
    
    /// 获取多个商品
    ///
    /// - Parameters:
    ///   - productIds: 商品id集合
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func fetchProducts(for productIds: Set<String>, success: IAPManager.ProductsSuccessHandler?, failure: IAPManager.FailureHandler?) {
        let request = SKProductsRequest(productIdentifiers: productIds)
        request.delegate = self
        productRequests.append((request, success, failure))
        request.start()
    }
    
    
    private func popProductRequestTuple(for request: SKRequest) -> ProductRequestTuple? {
        var result: ProductRequestTuple? = nil
        
        for i in 0..<productRequests.count {
            let tuple = productRequests[i]
            if tuple.request == request {
                result = tuple
                productRequests.remove(at: i)
                break
            }
        }
        
        return result
    }
    
    
    // MARK: Payment
    
    /// 根据商品id购买商品
    ///
    /// - Parameters:
    ///   - productId: 商品id
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func purchaseForProductId(_ productId: String, success: IAPManager.PurchaseSuccessHandler?, failure: IAPManager.FailureHandler?) {
        
        if SKPaymentQueue.canMakePayments() {
            
            fetchProduct(for: productId, success: { [weak self] (products: Array<SKProduct>) in
                
                if products.count > 0 {
                    self?.purchase(product: products.first!, success: success, failure: failure)
                }
                else if let failure = failure {
                    let error = IAPError.productNotFound(productId: productId)
                    failure(error)
                }
                
            }, failure: failure)
        }
        else {
            invokeFailureBlockForCanNotMakePayment(failure)
        }
    }
    
    /// 购买商品
    ///
    /// - Parameters:
    ///   - product: 商品
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func purchase(product: SKProduct, success: IAPManager.PurchaseSuccessHandler?, failure: IAPManager.FailureHandler?) {
        
        if SKPaymentQueue.canMakePayments() {
            let payment = SKPayment(product: product)
            payments.append((payment.productIdentifier, success, failure))
            SKPaymentQueue.default().add(payment)
        }
        else {
            invokeFailureBlockForCanNotMakePayment(failure)
        }
    }
    
    
    /// 恢复购买
    ///
    /// - Parameters:
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func restorePurchases(success: IAPManager.RestorePurchaseSuccessHandler?, failure: IAPManager.FailureHandler?) {
        restorePurchaseSuccessHandler = success
        restorePurchaseFailureHandler = failure
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    private func invokeFailureBlockForCanNotMakePayment(_ block: IAPManager.FailureHandler?) {
        if let block = block {
            let error = IAPError.canNotMakePayments
            block(error)
        }
    }
    
    
    // MARK: Verify
    
    // In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
    // In the real environment, use https://buy.itunes.apple.com/verifyReceipt
    private let testEnvironmentVerifyURL = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
    private let realEnvironmentVerifyURL = URL(string: "https://buy.itunes.apple.com/verifyReceipt")!
    
    func verify(realEnvironment: Bool, success: IAPManager.VerifyTransactionSuccessHandler?, failure: IAPManager.VerifyTransactionFailureHandler?)
    {
        guard let recepitURL = Bundle.main.appStoreReceiptURL else {
            if let failure = failure {
                let error = IAPError.receiptDataNotFound
                failure(error)
            }
            return
        }
        
        do {
            let receiptData = try Data(contentsOf: recepitURL)
            let base64ReceiptString = receiptData.base64EncodedString()
            let requestContents = ["receipt-data": base64ReceiptString]
            
            let httpBody = try JSONSerialization.data(withJSONObject: requestContents, options: [])
            
            var request = URLRequest(url: realEnvironment ? realEnvironmentVerifyURL : testEnvironmentVerifyURL)
            request.httpMethod = "POST"
            request.httpBody = httpBody
            
            URLSession.shared.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
                
                if let error = error {
                    print("验证失败: \(error)")
                    if let failure = failure {
                        DispatchQueue.main.async {
                            failure(error)
                        }
                    }
                }
                else if let success = success {
                    DispatchQueue.main.async {
                        success(data, response)
                    }
                }
            
            }).resume()
            
        } catch let error {
            print("验证支付凭证失败: \(error)")
            failure?(error)
        }
    }
    
    
    
    // MARK: SKProductsRequestDelegate
    
    // 商品信息响应回调
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // 失效的商品id
        let invalidProductIdentifiers = response.invalidProductIdentifiers
        if invalidProductIdentifiers.count > 0 {
            print("invalidProductIdentifiers: \(invalidProductIdentifiers)")
        }
        
        if let tuple = popProductRequestTuple(for: request) {
            tuple.success?(response.products)
        }
    }
    
    
    // MARK: SKRequestDelegate
    
    // 请求完成
    func requestDidFinish(_ request: SKRequest) {
        print("商品请求完成")
    }
    
    // 请求失败
    func request(_ request: SKRequest, didFailWithError error: Error) {
        if let tuple = popProductRequestTuple(for: request) {
            tuple.failure?(error)
        }
    }
    
    
    
    // MARK: SKPaymentTransactionObserver
    
    // 事务队列有内容更新
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    {
        func popPaymentsTuple(for productIdentifier: String) -> PaymentTuple? {
            var result: PaymentTuple? = nil
            
            for i in 0..<payments.count {
                let tuple = payments[i]
                if tuple.productIdentifier == productIdentifier {
                    result = tuple
                    payments.remove(at: i)
                    break
                }
            }
            
            return result
        }
        
        restoreTransactions.removeAll()
        
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                print("正在交易: \(transaction.description)")
                
            case .purchased, .restored:
                queue.finishTransaction(transaction)
                
                if transaction.transactionState == .restored {
                    restoreTransactions.append(transaction)
                }
                
                let tuple = popPaymentsTuple(for: transaction.payment.productIdentifier)
                tuple?.success?(transaction)
                
            case .failed:
                queue.finishTransaction(transaction)
                
                let tuple = popPaymentsTuple(for: transaction.payment.productIdentifier)
                tuple?.failure?(transaction.error!)
                
            case .deferred:
                print("未知的交易: \(transaction)")
            }
        }
    }
    
    // 事务从队列中删除，调用 queue.finishTransaction(transaction) 会回调该代理方法
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        print("移除交易: \(transactions)")
    }
    
    // 恢复购买时，交易历史记录添加到队列出错
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("恢复购买失败: \(error)")
        
        if let restorePurchaseFailureHandler = restorePurchaseFailureHandler {
            restorePurchaseFailureHandler(error)
        }
        
        restoreTransactions.removeAll()
        restorePurchaseSuccessHandler = nil
        restorePurchaseFailureHandler = nil
    }
    
    // 恢复购买时，记录中的所有交易都成功添加到队列
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("恢复购买完毕")
        
        if let restorePurchaseSuccessHandler = restorePurchaseSuccessHandler {
            restorePurchaseSuccessHandler(restoreTransactions)
        }
        
        restoreTransactions.removeAll()
        restorePurchaseSuccessHandler = nil
        restorePurchaseFailureHandler = nil
    }
    
    // 下载状态发生变化
    func paymentQueue(_ queue: SKPaymentQueue, updatedDownloads downloads: [SKDownload]) {
        print("支付下载变化: \(downloads)")
    }
}



extension SKProduct {
    open override var description: String {
        let prefix = String(format: "<%@: %p> ", NSStringFromClass(type(of: self)), self)

        let productId   = self.productIdentifier
        let title       = self.localizedTitle
        let description = self.localizedDescription
        let price       = self.localizedPrice
        
        let downloadable           = self.isDownloadable
        let downloadContentLengths = self.downloadContentLengths
        let downloadContentVersion = self.downloadContentVersion
        
        return "\(prefix){\n\tproductId = \(productId);\n\ttitle = \(title);\n\tdescription = \(description);\n\tprice = \(price);\n\tdownloadable = \(downloadable);\n\tdownloadContentLengths = \(downloadContentLengths);\n\tdownloadContentVersion = \(downloadContentVersion);\n}"
    }
    
    var localizedPrice: String {
        if let symbol = self.priceLocale.currencySymbol {
            return (symbol + self.price.description(withLocale: self.priceLocale))
        }
        else {
            return self.price.description(withLocale: self.priceLocale)
        }
    }
    
    func printDescription() {
        print(self)
    }
}

extension SKPayment {
    open override var description: String {
        let prefix = String(format: "<%@: %p> ", NSStringFromClass(type(of: self)), self)
        
        let productId = self.productIdentifier
        let date      = self.requestData?.description
        let quantity  = self.quantity
        let username  = self.applicationUsername
        let inSandbox = self.simulatesAskToBuyInSandbox
        
        return "\(prefix){\n\tproductId = \(productId)'\n\tdate = \(String(describing: date));\n\tquantity = \(quantity);\n\tusername = \(String(describing: username));\n\tinSandbox = \(inSandbox);\n}"
    }
}

extension SKPaymentTransactionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .purchasing:
            return "SKPaymentTransactionStatePurchasing"
        case .purchased:
            return "SKPaymentTransactionStatePurchased"
        case .failed:
            return "SKPaymentTransactionStateFailed"
        case .restored:
            return "SKPaymentTransactionStateRestored"
        case .deferred:
            return "SKPaymentTransactionStateDeferred"
        }
    }
}

extension SKPaymentTransaction {
    open override var description: String {
        let prefix = String(format: "<%@: %p> ", NSStringFromClass(type(of: self)), self)
        
        let identifier = self.transactionIdentifier ?? "nil"
        let state      = self.transactionState
        let date       = self.transactionDate?.description ?? "nil"
        
        var original: String? = nil
        if let org = self.original {
            original = "{\n\t\tidentifier = \(org.transactionIdentifier ?? "nil");\n\t\tstate = \(org.transactionState);\n\t\tdate = \(org.transactionDate?.description ?? "nil");\n\t\tpayment = \(org.payment);\n\t}"
        }
        
        func paymentDescriptionByTransaction(_ payment: SKPayment) -> String {
            let prefix = String(format: "<%@: %p> ", NSStringFromClass(type(of: self)), self)
            let productId = payment.productIdentifier
            let date      = payment.requestData?.description ?? "nil"
            let quantity  = payment.quantity
            let username  = payment.applicationUsername ?? "nil"
            let inSandbox = payment.simulatesAskToBuyInSandbox
            
            return "\(prefix){\n\t\tproductId = \(productId)'\n\t\tdate = \(date);\n\t\tquantity = \(quantity);\n\t\tusername = \(username);\n\t\tinSandbox = \(inSandbox);\n\t}"
        }
        
        let paymenDescription = paymentDescriptionByTransaction(self.payment)
        
        return "\(prefix){\n\tidentifier = \(identifier);\n\tstate = \(state);\n\tdate = \(date);\n\tpayment = \(paymenDescription);\n\toriginal = \(original ?? "nil")\n\terror = \(String(describing: self.error));\n}"
    }
    
    func printDescription() {
        print(self)
    }
}
