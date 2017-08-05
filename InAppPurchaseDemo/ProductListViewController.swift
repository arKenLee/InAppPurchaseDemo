//
//  ProductListViewController.swift
//  InAppPurchaseDemo
//
//  Created by Lee on 2017/8/5.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit
import StoreKit

class ProductListViewController: UITableViewController {
    
    private(set) var products = [SKProduct]()
    private let productIds: Set<String> = ["kaDa_1000", "kaDa3000"]
    
    private var isFetchingProduct = false
    
    private lazy var loadingIndicator : UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        let screenBounds = UIScreen.main.bounds
        indicator.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY-64)
        indicator.isHidden = true
        self.view.addSubview(indicator)
        return indicator
    }()
    
    private lazy var emptyLabel : UILabel = {
        let label = UILabel()
        label.text = "没有可购买的商品"
        label.textColor = UIColor.gray
        label.textAlignment = .center
        label.isHidden = true
        label.sizeToFit()
        let screenBounds = UIScreen.main.bounds
        label.center = CGPoint(x: screenBounds.midX, y: screenBounds.midY-64)
        self.view.addSubview(label)
        return label
    }()
    
    private lazy var refetchButton : UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle("点击重新获取商品信息", for: .normal)
        button.setTitleColor(UIColor.gray, for: .normal)
        button.addTarget(self, action: #selector(refetchButtonClicked(_:)), for: .touchUpInside)
        if let navBarHeight = self.navigationController?.navigationBar.bounds.height {
            button.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height-navBarHeight)
        } else {
            button.frame = self.view.bounds
        }
        self.view.addSubview(button)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchProducts()
    }

    private func fetchProducts() {
        guard !isFetchingProduct else {
            return
        }
        
        isFetchingProduct = true
        
        loadingIndicator.startAnimating()
        
        IAPManager.shared.fetchProducts(for: productIds, success: {[weak self] (products: Array<SKProduct>) in
            guard let sSelf = self else { return }
            
            sSelf.loadingIndicator.stopAnimating()
            
            sSelf.isFetchingProduct = false
            
            if products.count > 0 {
                print("商品列表: \(products)")
                sSelf.products = products
                sSelf.tableView.reloadData()
            } else {
                sSelf.emptyLabel.isHidden = false
            }
            
        }) {[weak self] (error: Error) in
            NotificationMessageWindow.show(message: error.localizedDescription)
            
            guard let sSelf = self else { return }
            
            sSelf.loadingIndicator.stopAnimating()
            
            sSelf.isFetchingProduct = false
            
            sSelf.refetchButton.isHidden = false
        }
    }
    
    @objc private func refetchButtonClicked(_ sender: UIButton) {
        sender.isHidden = true
        fetchProducts()
    }
    
    @IBAction func restoreItemClicked(_ sender: UIBarButtonItem) {
        IAPManager.shared.restorePurchases(success: { (transactions: Array<SKPaymentTransaction>) in
            let originalTransactions = transactions.flatMap { $0.original }
            print("恢复购买: \(originalTransactions)")
        }) { (error: Error) in
            NotificationMessageWindow.show(message: error.localizedDescription)
        }
    }
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductInfoCell", for: indexPath)

        let product = products[indexPath.row]
        cell.textLabel?.text = product.localizedTitle
        cell.detailTextLabel?.text = product.localizedPrice

        return cell
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {        
        if let vc = segue.destination as? PurchaseProductViewController {
            if let indexPath = tableView.indexPathForSelectedRow {
                let product = products[indexPath.row]
                vc.product = product
            }
        }
    }
}
