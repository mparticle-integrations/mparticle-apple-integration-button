import XCTest
import ButtonMerchant
import mParticle_Button

class Actual {
    static var applicationId: String?
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
}
