//
//  KitButton.swift
//  mParticle-Button
//
//  Created by Osvaldo Rafael Mercado Espinel on 11/05/22.
//  Copyright © 2022 mParticle. All rights reserved.
//

import Foundation
import mParticle_Apple_SDK
import ButtonMerchant

public class MPIButton {
    
    public var attributionToken = {
        return ButtonMerchant.attributionToken
    }()
}

public let BTNMPKitVersion = "2.0.0"

public let BTNReferrerTokenDefaultsKey   = "com.usebutton.referrer"
public let BTNLinkFetchStatusDefaultsKey = "com.usebutton.link.fetched"

public let MPKitButtonAttributionResultKey = "mParticle-Button Attribution Result"
public let BTNPostInstallURLKey = "BTNPostInstallURLKey"

public let MPKitButtonErrorDomain = "com.mparticle.kits.button"
public let MPKitButtonErrorMessageKey = "mParticle-Button Error"
public let MPKitButtonIntegrationAttribution = "com.usebutton.source_token"

@objc(MPKitButton2)
public class KitButton: NSObject, MPKitProtocol {
    
    public var mParticleInstance: MParticle! = MParticle.sharedInstance()
    var button: MPIButton!
    var applicationId: String?
    public var defaultCenter: NotificationCenter! = NotificationCenter.default
    public var started: Bool = false
    var configuration: [AnyHashable : Any] = [:]
    
    public var kitApi: MPKitAPI?
    
    public var providerKitInstance: Any? {
        return started ? button : nil
    }
    
    public static func kitCode() -> NSNumber {
        return 1022
    }
    
    public override init() {
        super.init()
        let kitRegister = MPKitRegister(name: "Button", className: self.description)
        
        MParticle.registerExtension(kitRegister!)
    }
    
    func trackIncomingURL(url: URL) {
        ButtonMerchant.trackIncomingURL(url)
    }
    
    public func didFinishLaunching(withConfiguration configuration: [AnyHashable : Any]) -> MPKitExecStatus {
        var execStatus: MPKitExecStatus!
        
        self.button = MPIButton()
        self.applicationId = configuration["application_id"] as? String
        
        guard let applicationId = self.applicationId else {
            execStatus = MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .requirementsNotMet)
            return execStatus
        }
        
        ButtonMerchant.configure(applicationId: applicationId)
        
        self.defaultCenter.addObserver(self, selector: #selector(observeAttributionTokenDidChangeNotification(_:)), name: ButtonMerchant.AttributionTokenDidChangeNotification as NSNotification.Name, object: nil)
        
        self.configuration = configuration
        self.started = true
        
        DispatchQueue.main.async {
            let userInfo = [mParticleKitInstanceKey: KitButton.kitCode()]
            NotificationCenter.default.post(name: .mParticleKitDidBecomeActive, object: nil, userInfo: userInfo)
            self.checkForAttribution()
        }
        
        execStatus = MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .success)
        return execStatus
    }
    
    public func open(_ url: URL, options: [String : Any]? = nil) -> MPKitExecStatus {
        self.trackIncomingURL(url: url)
        return MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .success)
    }
    
    public func open(_ url: URL, sourceApplication: String?, annotation: Any?) -> MPKitExecStatus {
        self.trackIncomingURL(url: url)
        return MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .success)
    }
    
    public func `continue`(_ userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> MPKitExecStatus {
        guard let url = userActivity.webpageURL else { return MPKitExecStatus() }
        self.trackIncomingURL(url: url)
        return MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .success)
    }
    
    public func logBaseEvent(_ event: MPBaseEvent) -> MPKitExecStatus {
        guard let event = event as? MPCommerceEvent else {
            return MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: .unavailable)
        }
        
        var code: MPKitReturnCode = .unavailable
        let products = self.buttonProducts(from: event.products)
        
        switch (event.action) {
        case .viewDetail:
            ButtonMerchant.activity.productViewed(products.first)
            code = .success
        case .addToCart:
            ButtonMerchant.activity.productAddedToCart(products.first)
            code = .success
        case .checkout:
            ButtonMerchant.activity.cartViewed(products)
            code = .success
        default: break
        }
        
        return MPKitExecStatus(sdkCode: KitButton.kitCode(), returnCode: code)
    }
    
    private func error(with message: String) -> NSError {
        let error = NSError(domain: MPKitButtonErrorDomain, code: 0, userInfo: [MPKitButtonErrorMessageKey: message])
        return error
    }
    
    private func checkForAttribution() {
        ButtonMerchant.handlePostInstallURL { postInstallURL, error in
            if error != nil || postInstallURL == nil {
                let attributionError = self.error(with: "No attribution information available.")
                self.kitApi?.onAttributionComplete(with: nil, error: attributionError)
            }
            
            let linkInfo = [ BTNPostInstallURLKey: postInstallURL?.absoluteString ?? "" ]
            let attributionResult = MPAttributionResult()
            attributionResult.linkInfo = linkInfo
            
        }
    }
    
    @objc
    private func observeAttributionTokenDidChangeNotification(_ note: NSNotification) {
        if let attributionToken = note.userInfo?[ButtonMerchant.AttributionTokenKey] as? String {
            let integrationAttributes = [MPKitButtonIntegrationAttribution: attributionToken]
            self.mParticleInstance.setIntegrationAttributes(integrationAttributes, forKit: KitButton.kitCode())
        }
    }
    
    private func buttonProducts(from products: [MPProduct]?) -> [ButtonProduct] {
        return products?.map {
            let buttonProduct = ButtonProduct()
            buttonProduct.name = $0.name
            buttonProduct.id = $0.sku
            buttonProduct.value = Int(($0.price?.doubleValue ?? 0) * 100)
            buttonProduct.quantity = $0.quantity.intValue
            if let category = $0.category {
                buttonProduct.categories = [category]
            }
            buttonProduct.attributes = ["btn_product_count": "\(products?.count ?? 0)"]
            return buttonProduct
        } ?? []
    }
    
}
