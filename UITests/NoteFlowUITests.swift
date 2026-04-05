import XCTest

final class NoteFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset consent state for clean test runs
        app.launchArguments = ["--reset-consent", "--ui-testing"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Consent Screen Tests
    
    func testConsentScreenAppearsOnFirstLaunch() throws {
        // Consent screen should appear on fresh launch
        let consentTitle = app.staticTexts["Before you start recording"]
        XCTAssertTrue(consentTitle.waitForExistence(timeout: 5))
    }
    
    func testGetStartedDisabledWithoutCheckbox() throws {
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 5))
        XCTAssertFalse(getStartedButton.isEnabled)
    }
    
    func testGetStartedEnabledAfterCheckbox() throws {
        let checkbox = app.checkBoxes.firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5))
        checkbox.click()
        
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.isEnabled)
    }
    
    func testConsentScreenDismissedAfterAccepting() throws {
        let checkbox = app.checkBoxes.firstMatch
        checkbox.waitForExistence(timeout: 5)
        checkbox.click()
        
        app.buttons["Get Started"].click()
        
        let consentTitle = app.staticTexts["Before you start recording"]
        XCTAssertFalse(consentTitle.waitForExistence(timeout: 3))
    }
    
    func testConsentNotShownOnSecondLaunch() throws {
        // Accept consent
        let checkbox = app.checkBoxes.firstMatch
        checkbox.waitForExistence(timeout: 5)
        checkbox.click()
        app.buttons["Get Started"].click()
        
        // Relaunch without reset flag
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        
        let consentTitle = app.staticTexts["Before you start recording"]
        XCTAssertFalse(consentTitle.waitForExistence(timeout: 3))
    }
    
    // MARK: - Main Window Tests
    
    func testMainWindowLoads() throws {
        // Accept consent first
        acceptConsent()
        
        // Main window elements should be visible
        XCTAssertTrue(app.buttons["Go Live"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Listening for moments to help…"]
            .waitForExistence(timeout: 5))
    }
    
    func testGoLiveButtonExists() throws {
        acceptConsent()
        let goLiveButton = app.buttons["Go Live"]
        XCTAssertTrue(goLiveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(goLiveButton.isEnabled)
    }
    
    func testSettingsPanelOpens() throws {
        acceptConsent()
        // Trigger settings via keyboard shortcut
        app.typeKey(",", modifierFlags: .command)
        
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))
    }
    
    func testSettingsPanelHasRequiredFields() throws {
        acceptConsent()
        app.typeKey(",", modifierFlags: .command)
        
        XCTAssertTrue(app.staticTexts["GCP WebSocket URL"]
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["GCP REST Base URL"]
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Gemini API Key"]
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Knowledge Base Folder"]
            .waitForExistence(timeout: 3))
    }
    
    // MARK: - Helpers
    
    private func acceptConsent() {
        let checkbox = app.checkBoxes.firstMatch
        if checkbox.waitForExistence(timeout: 3) {
            checkbox.click()
            app.buttons["Get Started"].click()
        }
    }
}
