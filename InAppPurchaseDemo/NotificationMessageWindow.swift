//
//  NotificationMessageWindow.swift
//
//
//  Created by Lee on 2017/4/29.
//  Copyright © 2017年 arKen. All rights reserved.
//

import UIKit

fileprivate var NotificationMessageWindowManager = [UIWindow]()

extension NotificationMessageWindow {
    class func show(message: String) {
        let view = NotificationMessageWindow(message: message)
        view.show()
    }
}

/// 通知消息窗口
class NotificationMessageWindow: UIWindow {
    
    private let label: UILabel
    
    init(message: String, dismissOnTap: Bool = true) {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 64)
        
        self.label = UILabel(frame: frame)
        self.label.text = message
        self.label.font = UIFont.systemFont(ofSize: 14)
        self.label.textColor = UIColor(red: 0.93, green: 0.85, blue: 0.88, alpha: 1.0)
        self.label.numberOfLines = 0
        
        super.init(frame: frame)
        
        self.backgroundColor = UIColor(red: 0.86, green: 0.35, blue: 0.38, alpha: 1.0)
        self.windowLevel = UIWindowLevelStatusBar - 100
        
        self.rootViewController = UIViewController()
        self.rootViewController?.view.addSubview(self.label)
        
        if dismissOnTap {
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismiss)))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        NotificationMessageWindowManager.append(self)
        
        updateFrame()
        frame.origin.y -= frame.size.height
        
        makeKeyAndVisible()
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseOut], animations: { [unowned self] in
            self.frame.origin.y = 0
        }) { [unowned self] _ in
            self.dismissDelay(delay: self.displayDuration())
        }
    }
    
    func dismiss() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveEaseOut], animations: { [unowned self] in
            self.frame.origin.y -= self.frame.size.height
        }) { [weak self] _ in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.window?.makeKeyAndVisible()
            }
            
            if let sSelf = self {
                if let index = NotificationMessageWindowManager.index(of: sSelf) {
                    NotificationMessageWindowManager.remove(at: index)
                }
            }
        }
    }
    
    func dismissDelay(delay: TimeInterval) {
        perform(#selector(dismiss), with: nil, afterDelay: delay)
    }
    
    func displayDuration() -> TimeInterval {
        let textLength = TimeInterval(self.label.text?.characters.count ?? 0)
        return TimeInterval(max(textLength * 0.1, 3.0))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrame()
    }
    
    fileprivate func updateFrame() {
        let topMargin: CGFloat = 24
        let bottomMargin: CGFloat = 8
        let horizontalMargin: CGFloat = 15
        
        let message = self.label.text ?? ""
        let font = self.label.font!
        let textAttribute = [NSFontAttributeName: font]
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading, .usesDeviceMetrics]
        
        let screenSize = UIScreen.main.bounds.size
        let boundingize = CGSize(width: screenSize.width - horizontalMargin*2, height: screenSize.height)
        
        let textSize = (message as NSString).boundingRect(with: boundingize, options: options, attributes: textAttribute, context: nil)
        
        let labelHeight = max(textSize.height + 4, 32)
        self.label.frame = CGRect(x: horizontalMargin, y: topMargin, width: boundingize.width, height: labelHeight)
        
        self.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: self.label.frame.maxY + bottomMargin)
    }
}
