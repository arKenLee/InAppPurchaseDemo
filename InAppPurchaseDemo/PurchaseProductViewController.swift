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
        
        IAPManager.shared.purchase(product: product!, success: {(transaction: SKPaymentTransaction) in
            
            IAPManager.shared.verify(realEnvironment: false, success: {[weak self] (data: Data?, response: URLResponse?) in
                
                sender.isEnabled = true
                self?.loadingIndicator.stopAnimating()
                NotificationMessageWindow.show(message: "购买【\(productName)】成功！")
                
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                    print("\(json)")
                }
                
            }) {[weak self] (error: Error) in
                sender.isEnabled = true
                self?.loadingIndicator.stopAnimating()
                NotificationMessageWindow.show(message: "购买【\(productName)】失败：\(error.localizedDescription)")
            }
            
        }) {[weak self] (error: Error) in
            sender.isEnabled = true
            self?.loadingIndicator.stopAnimating()
            NotificationMessageWindow.show(message: "购买【\(productName)】失败：\(error.localizedDescription)")
        }
    }
}
