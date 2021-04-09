import XCTest
import ButtonMerchant
import mParticle_Button

class Actual {
    static var applicationId: String?
    static var activity: TestActivity!
}

class Stub {
    static var url: URL?
    static var error: NSError?
}

extension ButtonMerchant {
    @objc public static func configure(applicationId: String) {
        Actual.applicationId = applicationId
    }
    @objc public static func handlePostInstallURL(_ completion: @escaping (URL?, Error?) -> Void) {
        completion(Stub.url, Stub.error)
    }
    static var activity: Activity {
        return Actual.activity
    }
}

class TestActivity: Activity {
    var didCallProductViewed = false
    var didCallProductAddedToCart = false
    var didCallCartViewed = false
    var actualProduct: ButtonProductCompatible?
    var actualProducts: [ButtonProductCompatible]?
    
    func productViewed(_ product: ButtonProductCompatible?) {
        didCallProductViewed = true
        actualProduct = product
    }
    
    func productAddedToCart(_ product: ButtonProductCompatible?) {
        didCallProductAddedToCart = true
        actualProduct = product
    }
    
    func cartViewed(_ products: [ButtonProductCompatible]?) {
        didCallCartViewed = true
        actualProducts = products
    }
}

class TestMParticle: MParticle {
    var actualIntegrationAttributes: [String : String]!
    var actualKitCode: NSNumber!
    override func setIntegrationAttributes(_ attributes: [String : String], forKit kitCode: NSNumber) -> MPKitExecStatus {
        actualIntegrationAttributes = attributes
        actualKitCode = kitCode
        return MPKitExecStatus()
    }
}

class TestMPKitAPI: MPKitAPI {
    var onAttributionCompleteTestHandler: ((MPAttributionResult?, NSError?) -> ())!
    open override func onAttributionComplete(with result: MPAttributionResult?, error: Error?) {
        onAttributionCompleteTestHandler(result, error as NSError?)
    }
}

class TestNotificationCenter: NotificationCenter {
    var actualObserver: MPKitButton?
    var actualSelector: Selector?
    var actualName: NSNotification.Name?
    var actualObject: Any?
    override func addObserver(_ observer: Any,
                              selector aSelector: Selector,
                              name aName: NSNotification.Name?,
                              object anObject: Any?) {
        actualObserver = observer as? MPKitButton
        actualSelector = aSelector
        actualName = aName
        actualObject = anObject
    }
}

class mParticle_ButtonTests: XCTestCase {

    var testMParticleInstance: TestMParticle!
    var buttonKit: MPKitButton!
    var buttonInstance: MPIButton!
    var applicationId: String = "app-\(arc4random_uniform(10000))"

    override func setUp() {
        super.setUp()
        // Reset all static test output & stubs.
        Actual.applicationId = nil
        Actual.activity = TestActivity()
        Stub.url = nil
        Stub.error = nil

        // Start the Button kit.
        buttonKit = MPKitButton()
        testMParticleInstance = TestMParticle()
        buttonKit.mParticleInstance = testMParticleInstance
        let configuration = ["application_id": applicationId]
        buttonKit.didFinishLaunching(withConfiguration: configuration)
        buttonInstance = buttonKit.providerKitInstance as? MPIButton
    }

    func testKitCode() {
        XCTAssertEqual(MPKitButton.kitCode(), 1022)
    }

    func testDidFinishLaunchingWithConfiguration() {
        // Arrange
        let testNotificationCenter = TestNotificationCenter()
        buttonKit.defaultCenter = testNotificationCenter
        
        // Act
        let configuration = ["application_id": applicationId]
        buttonKit.didFinishLaunching(withConfiguration: configuration)
        
        // Assert
        XCTAssertEqual(Actual.applicationId, applicationId)
        XCTAssertEqual(testNotificationCenter.actualObserver, buttonKit)
        XCTAssertEqual(testNotificationCenter.actualSelector, NSSelectorFromString("observeAttributionTokenDidChangeNotification:"))
        XCTAssertEqual(testNotificationCenter.actualName, NSNotification.Name.Button.AttributionTokenDidChange)
        XCTAssertNil(testNotificationCenter.actualObject)
    }

    func testOpenURLOptionsTracks() {

        // Arrange
        let attributionToken = "testtoken-\(arc4random_uniform(10000))"
        let url = URL(string: "https://usebutton.com?btn_ref=\(attributionToken)")!

        // Act
        buttonKit.open(url, options: nil)

        // Assert
        XCTAssertEqual(ButtonMerchant.attributionToken, attributionToken)
        XCTAssertEqual(buttonInstance.attributionToken, attributionToken)
        XCTAssertEqual(testMParticleInstance.actualIntegrationAttributes, [ "com.usebutton.source_token": attributionToken ])
    }

    func testOpenURLSourceApplicationAnnotationTracks() {

        // Arrange
        let attributionToken = "testtoken-\(arc4random_uniform(10000))"
        let url = URL(string: "https://usebutton.com?btn_ref=\(attributionToken)")!

        // Act
        buttonKit.open(url, sourceApplication: "test", annotation: nil)

        // Assert
        XCTAssertEqual(ButtonMerchant.attributionToken, attributionToken)
        XCTAssertEqual(buttonInstance.attributionToken, attributionToken)
        XCTAssertEqual(testMParticleInstance.actualIntegrationAttributes, [ "com.usebutton.source_token": attributionToken ])
    }

    func testContinueUserActivityTracks() {

        // Arrange
        let attributionToken = "testtoken-\(arc4random_uniform(10000))"
        let url = URL(string: "https://usebutton.com?btn_ref=\(attributionToken)")!
        let userActivity = NSUserActivity(activityType: "web")
        userActivity.webpageURL = url

        // Act
        buttonKit.continue(userActivity) { handler in }

        // Assert
        XCTAssertEqual(ButtonMerchant.attributionToken, attributionToken)
        XCTAssertEqual(buttonInstance.attributionToken, attributionToken)
        XCTAssertEqual(testMParticleInstance.actualIntegrationAttributes, [ "com.usebutton.source_token": attributionToken ])
    }

    func testPostInstallCheckOnAttribution() {

        // Arrange
        buttonKit = MPKitButton()
        let expectation = self.expectation(description: "post-install-url-check")
        let configuration = ["application_id": applicationId]
        let attributionToken = "testtoken-\(arc4random_uniform(10000))"
        let url = URL(string: "https://usebutton.com?btn_ref=\(attributionToken)")!
        let testKitApi = TestMPKitAPI()
        buttonKit.kitApi = testKitApi
        Stub.url = url

        // Act
        buttonKit.didFinishLaunching(withConfiguration: configuration)

        // Assert
        testKitApi.onAttributionCompleteTestHandler = { result, error in
            let actualURL = result?.linkInfo[BTNPostInstallURLKey] as? String
            XCTAssertEqual(actualURL, url.absoluteString)
            XCTAssertNotNil(url)
            XCTAssertNil(error)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 1.0)
    }

    func testPostInstallCheckOnNoAttribution() {

        // Arrange
        buttonKit = MPKitButton()
        let expectation = self.expectation(description: "post-install-url-check")
        let configuration = ["application_id": applicationId]
        let testKitApi = TestMPKitAPI()
        buttonKit.kitApi = testKitApi
        Stub.error = NSError(domain: "test", code: -1, userInfo: nil)

        // Act
        buttonKit.didFinishLaunching(withConfiguration: configuration)

        // Assert
        testKitApi.onAttributionCompleteTestHandler = { result, error in
            let message = error?.userInfo[MPKitButtonErrorMessageKey] as? String
            XCTAssertEqual(message, "No attribution information available.")
            XCTAssertNotNil(error)
            XCTAssertNil(result)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 1.0)
    }

    func testPostInstallCheckOnError() {

        // Arrange
        buttonKit = MPKitButton()
        let expectation = self.expectation(description: "post-install-url-check")
        let configuration = ["application_id": applicationId]
        let testKitApi = TestMPKitAPI()
        buttonKit.kitApi = testKitApi
        Stub.url = nil

        // Act
        buttonKit.didFinishLaunching(withConfiguration: configuration)

        // Assert
        testKitApi.onAttributionCompleteTestHandler = { result, error in
            let message = error?.userInfo[MPKitButtonErrorMessageKey] as? String
            XCTAssertEqual(message, "No attribution information available.")
            XCTAssertNotNil(error)
            XCTAssertNil(result)
            expectation.fulfill()
        }

        self.wait(for: [expectation], timeout: 1.0)
    }
    
    func testAttributionDidChangeNotificationSetsIntegrationAttributes() {
        // Arrange
        let attributionToken = "faketok-from-notification"
        
        // Act
        NotificationCenter.default.post(name: Notification.Name.Button.AttributionTokenDidChange,
                                        object: nil,
                                        userInfo: [Notification.Key.NewToken: attributionToken])
        // Assert
        XCTAssertEqual(testMParticleInstance.actualIntegrationAttributes, [ "com.usebutton.source_token": attributionToken ])
    }
    
    func testLogProductViewedEventInvokesButtonActivity() {
        // Arrange
        buttonKit = MPKitButton()
        let product = MPProduct(name: "some name", sku: "some sku", quantity: NSNumber(integerLiteral: 2), price: NSNumber(floatLiteral: 1.99))
        product.category = "some category"
        let event = MPCommerceEvent(action: .viewDetail, product: product)
        event.addProduct(MPProduct())
        
        // Act
        buttonKit.logBaseEvent(event)
        
        // Assert
        XCTAssertTrue(Actual.activity.didCallProductViewed)
        XCTAssertNotNil(Actual.activity.actualProduct)
        XCTAssertEqual(Actual.activity.actualProduct?.name, "some name")
        XCTAssertEqual(Actual.activity.actualProduct?.id, "some sku")
        XCTAssertEqual(Actual.activity.actualProduct?.categories, ["some category"])
        XCTAssertEqual(Actual.activity.actualProduct?.quantity, 2)
        XCTAssertEqual(Actual.activity.actualProduct?.value, 199)
        XCTAssertEqual(Actual.activity.actualProduct?.attributes, ["btn_product_count" : "2"])
    }
    
    func testLogProductAddedToCartEventInvokesButtonActivity() {
        // Arrange
        buttonKit = MPKitButton()
        let product = MPProduct(name: "some name", sku: "some sku", quantity: NSNumber(integerLiteral: 2), price: NSNumber(floatLiteral: 1.99))
        product.category = "some category"
        let event = MPCommerceEvent(action: .addToCart, product: product)
        event.addProduct(MPProduct())
        
        // Act
        buttonKit.logBaseEvent(event)
        
        // Assert
        XCTAssertTrue(Actual.activity.didCallProductAddedToCart)
        XCTAssertNotNil(Actual.activity.actualProduct)
        XCTAssertEqual(Actual.activity.actualProduct?.name, "some name")
        XCTAssertEqual(Actual.activity.actualProduct?.id, "some sku")
        XCTAssertEqual(Actual.activity.actualProduct?.categories, ["some category"])
        XCTAssertEqual(Actual.activity.actualProduct?.quantity, 2)
        XCTAssertEqual(Actual.activity.actualProduct?.value, 199)
        XCTAssertEqual(Actual.activity.actualProduct?.attributes, ["btn_product_count" : "2"])
    }
    
    func testLogCheckoutEventInvokesButtonActivity() {
        // Arrange
        buttonKit = MPKitButton()
        let product = MPProduct(name: "some name", sku: "some sku", quantity: NSNumber(integerLiteral: 2), price: NSNumber(floatLiteral: 1.99))
        product.category = "some category"
        let event = MPCommerceEvent(action: .checkout, product: product)
        event.addProduct(MPProduct())

        // Act
        buttonKit.logBaseEvent(event)

        // Assert
        XCTAssertTrue(Actual.activity.didCallCartViewed)
        XCTAssertNotNil(Actual.activity.actualProducts)
        XCTAssertEqual(Actual.activity.actualProducts?.first?.name, "some name")
        XCTAssertEqual(Actual.activity.actualProducts?.first?.id, "some sku")
        XCTAssertEqual(Actual.activity.actualProducts?.first?.categories, ["some category"])
        XCTAssertEqual(Actual.activity.actualProducts?.first?.quantity, 2)
        XCTAssertEqual(Actual.activity.actualProducts?.first?.value, 199)
        XCTAssertNotNil(Actual.activity.actualProducts?[1])
    }
}
