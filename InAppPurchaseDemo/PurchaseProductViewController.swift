//
//  PurchaseProductViewController.swift
//  InAppPurchaseDemo
//
//  Created by Lee on 2017/8/5.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import StoreKit

class PurchaseProductViewController: UITableViewController {
    
    var product: SKProduct?

    @IBOutlet weak var nameCell: UITableViewCell!
    
    @IBOutlet weak var priceCell: UITableViewCell!
    
    @IBOutlet weak var descriptionCell: UITableViewCell!
    
    @IBOutlet weak var purchaseButton: UIButton!
    
    private lazy var loadingIndicator : UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        let screenBounds = UIScreen.main.bounds
        indicator.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY-64)
        indicator.isHidden = true
        self.view.addSubview(indicator)
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let product = product {
            nameCell.detailTextLabel?.text = product.localizedTitle
            priceCell.detailTextLabel?.text = product.localizedPrice
            descriptionCell.detailTextLabel?.text = product.localizedDescription
        } else {
            let alertController = UIAlertController(title: "找不到该商品", message: nil, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "知道了", style: .cancel) {[unowned self] (_) in
                self.navigationController?.popViewController(animated: true)
            }
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

    @IBAction func purchaseButtonClicked(_ sender: UIButton) {
        
        sender.isEnabled = false
        
        loadingIndicator.startAnimating()
        
        let productName = product!.localizedTitle
        
        IAPManager.shared.purchase(product: product!, success: {[weak self] (transaction: SKPaymentTransaction) in
        
            self?.verifyReceipt(realEnvironment: true, productName: productName)
            
        }) {[weak self] (error: Error) in
            sender.isEnabled = true
            self?.loadingIndicator.stopAnimating()
            NotificationMessageWindow.show(message: "购买【\(productName)】失败：\(error.localizedDescription)")
        }
    }
    
    func verifyReceipt(realEnvironment: Bool, productName: String) {
        IAPManager.shared.verify(realEnvironment: realEnvironment, success: {[weak self] (json: [String : Any], response: URLResponse?) in
            
            self?.purchaseButton.isEnabled = true
            self?.loadingIndicator.stopAnimating()
            NotificationMessageWindow.show(message: "购买【\(productName)】成功！")
            print("\(json)")
            
        }) {[weak self] (error: Error) in
            
            if let iapError = error as? IAPError,
                case let .verifyReceiptFailre(jsonResponse) = iapError,
                let status = jsonResponse["status"] as? Int,
                status == 21007, realEnvironment
            {
                // status 为 21007 表示收据来自沙盒环境，但发送至生产环境验证，应将其发送至沙盒环境再次验证。
                print("误将沙盒环境的收据发送至生产环境")
                self?.verifyReceipt(realEnvironment: false, productName: productName)
                
            } else {
                self?.purchaseButton.isEnabled = true
                self?.loadingIndicator.stopAnimating()
                NotificationMessageWindow.show(message: "购买【\(productName)】失败：\(error.localizedDescription)")
                print(error)
            }
        }
    }
}
