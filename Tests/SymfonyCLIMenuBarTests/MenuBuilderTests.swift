import AppKit
import XCTest
@testable import SymfonyCLIMenuBar

@MainActor
final class MenuBuilderTests: XCTestCase {
    func testSupportItemIsTheOptionAlternateForAbout() {
        let target = MenuTarget()
        let items = MenuBuilder.makeAboutMenuItems(
            target: target,
            aboutAction: #selector(MenuTarget.about),
            supportAction: #selector(MenuTarget.support)
        )
        let menu = NSMenu()
        menu.addItem(items.about)
        menu.addItem(items.support)

        XCTAssertEqual(menu.items.count, 2)
        XCTAssertEqual(menu.items[0].title, "About Symfony CLI MenuBar")
        XCTAssertFalse(menu.items[0].isAlternate)
        XCTAssertEqual(menu.items[1].title, "Support Symfony CLI MenuBar")
        XCTAssertTrue(menu.items[1].isAlternate)
        XCTAssertEqual(menu.items[1].keyEquivalentModifierMask, [.option])
    }

    func testAppURLsUseThePublicSiteAndSupportDestination() {
        XCTAssertEqual(AppInfo.websiteURL, "https://smnand.re/sfmenubar")
        XCTAssertEqual(AppInfo.supportURL, "https://smnandre.dev")
    }
}

private final class MenuTarget: NSObject {
    @objc func about() {}

    @objc func support() {}
}
