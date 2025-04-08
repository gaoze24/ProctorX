//
//  AppDelegate.swift
//  ProctorX
//
//  Created by Eddie Gao on 6/4/25.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var screenshotManager: ScreenshotManager?
    var telegramManager: TelegramManager?
    // Second instance for fetching and displaying messages
    var textTelegramManager: TelegramManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create telegramManager for screenshot sending.
        telegramManager = TelegramManager(botToken: "", chatID: "")
        screenshotManager = ScreenshotManager(telegramManager: telegramManager!)
        
        // Create a second instance for message checking.
        textTelegramManager = TelegramManager(botToken: "", chatID: "")
        
        // Setup status bar item.
        setupStatusItem()

        // Start taking screenshots every 10 seconds.
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.screenshotManager?.takeScreenshot()
        }
        
        // Start fetching messages every 10 seconds.
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.fetchAndDisplayLatestMessage()
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "ProctorX"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Take Screenshot",
                                 action: #selector(takeScreenshot),
                                 keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Show Latest Message",
                                 action: #selector(showMessage),
                                 keyEquivalent: "m"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit",
                                 action: #selector(quitApp),
                                 keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func takeScreenshot() {
        screenshotManager?.takeScreenshot()
    }
    
    @objc func statusBarButtonClicked() {
        // Optional: add behavior for direct clicks on the status button.
    }
    
    @objc func showMessage() {
        fetchAndDisplayLatestMessage()
    }
    
    func fetchAndDisplayLatestMessage() {
        textTelegramManager?.fetchLatestMessage { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    print("Fetched message: \(message)")
                    if !message.isEmpty, let button = self.statusItem?.button {
                        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.labelColor]
                        button.attributedTitle = NSAttributedString(string: message, attributes: attributes)
                    }
                case .failure(let error):
                    print("Error fetching message: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
