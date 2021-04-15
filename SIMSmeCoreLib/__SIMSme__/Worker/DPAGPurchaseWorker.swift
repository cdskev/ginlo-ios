//
//  DPAGPurchaseWorker.swift
//  SIMSmeCoreLib
//
//  Created by RBU on 10/11/2016.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import UIKit

public class DPAGPurchaseWorker: NSObject {
    public class func getPurchasedProductsWithResponse(_ responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getPurchasedProducts(withResponse: responseBlock)
    }

    public class func getProductsWithResponse(_ responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.getProducts(withResponse: responseBlock)
    }

    public class func registerPurchase(_ productId: String, andTransaction transactionId: String?, andReceipt receipt: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.registerPurchase(productId: productId, andTransaction: transactionId, andReceipt: receipt, withResponse: responseBlock)
    }

    public class func registerVoucher(_ voucher: String, withResponse responseBlock: @escaping DPAGServiceResponseBlock) {
        DPAGApplicationFacade.server.registerVoucher(voucher: voucher, withResponse: responseBlock)
    }
}
