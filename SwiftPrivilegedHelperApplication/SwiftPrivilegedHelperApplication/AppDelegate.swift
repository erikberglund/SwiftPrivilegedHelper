//
//  AppDelegate.swift
//  SwiftPrivilegedHelperApplication
//
//  Created by Erik Berglund on 2018-10-01.
//  Copyright © 2018 Erik Berglund. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: -
    // MARK: IBOutlets

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var buttonInstallHelper: NSButton!
    @IBOutlet weak var buttonDestroyCachedAuthorization: NSButton!
    @IBOutlet weak var buttonRunCommand: NSButton!

    @IBOutlet weak var textFieldHelperInstalled: NSTextField!
    @IBOutlet weak var textFieldAuthorizationCached: NSTextField!
    @IBOutlet weak var textFieldInput: NSTextField!

    @IBOutlet var textViewOutput: NSTextView!

    @IBOutlet weak var checkboxRequireAuthentication: NSButton!
    @IBOutlet weak var checkboxCacheAuthentication: NSButton!

    // MARK: -
    // MARK: Variables

    @objc dynamic private var currentHelperAuthData: NSData?
    private let currentHelperAuthDataKeyPath: String

    @objc dynamic private var helperIsInstalled = false
    {
        didSet
        {
            self.buttonInstallHelper?.title = helperIsInstalled
                ? "Uninstall Helper"
                : "Install Helper"
        }
    }
    private let helperIsInstalledKeyPath: String
    
    @objc dynamic var installButtonTitle: String {
        helperIsInstalled ? "Uninstall Helper" : "Install Helper"
    }
    private let installButtonTitleKeyPath: String


    // MARK: -
    // MARK: Computed Variables

    var inputPath: String? {
        if self.textFieldInput.stringValue.isEmpty {
            self.textViewOutput.appendText("You need to enter a path to a directory!")
            return nil
        }

        let inputURL = URL(fileURLWithPath: self.textFieldInput.stringValue)
        do {
            guard try inputURL.checkResourceIsReachable() else { return nil }
        } catch {
            self.textViewOutput.appendText("\(self.textFieldInput.stringValue) is not a valid path!")
            return nil
        }
        return inputURL.path
    }

    // MARK: -
    // MARK: NSApplicationDelegate Methods

    override init() {
        self.currentHelperAuthDataKeyPath = NSStringFromSelector(#selector(getter: self.currentHelperAuthData))
        self.helperIsInstalledKeyPath = NSStringFromSelector(#selector(getter: self.helperIsInstalled))
        self.installButtonTitleKeyPath = NSStringFromSelector(#selector(getter: self.installButtonTitle))
        super.init()
    }

    override func awakeFromNib() {
        self.configureBindings()
    }

    var helperToolController: HelperToolController! = nil
    
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        resetHelperToolController()

        // Check if the current embedded helper tool is installed on the machine.
        updateHelperStatus()
    }
    
    private func resetHelperToolController()
    {
        do {
            helperToolController = try HelperToolController(
                toolName: HelperConstants.machServiceName
            )
            helperToolController.logStdOut = {
                self.textViewOutput.appendText($0)
            }
            helperToolController.logStdErr = {
                self.textViewOutput.appendText($0)
            }
        }
        catch {
            self.textViewOutput.appendText(error.localizedDescription)
        }
    }
    
    private func updateHelperStatus()
    {
        self.helperToolController.helperStatus
        { installed in
            DispatchQueue.main.async
            {
                self.textFieldHelperInstalled.stringValue = (installed)
                    ? "Yes"
                    : "No"
                self.setValue(installed, forKey: self.helperIsInstalledKeyPath)
            }
        }
    }

    // MARK: -
    // MARK: Initialization
    
    func configureBindings() {

        // Button: Install Helper
        self.buttonInstallHelper.isEnabled = true
        self.buttonInstallHelper.bind(
            .title,
            to: self,
            withKeyPath: self.installButtonTitleKeyPath,
            options: [.continuouslyUpdatesValue: true]
        )

        // Button: Run Command
        self.buttonRunCommand.bind(
            .enabled,
            to: self,
            withKeyPath: self.helperIsInstalledKeyPath,
            options: [.continuouslyUpdatesValue: true]
        )

    }

    // MARK: -
    // MARK: IBActions

    @IBAction func buttonInstallHelper(_ sender: Any) {
        do {
            if helperIsInstalled {
                try uninstallHelper()
                return
            }
            else if try installHelper()  { return }
        }
        catch
        {
            DispatchQueue.main.async
            {
                self.textViewOutput.appendText(
                    "Failed to install helper with error: \(error)"
                )
            }
        }
        DispatchQueue.main.async
        {
            self.textFieldHelperInstalled.stringValue = "No"
            self.setValue(false, forKey: self.helperIsInstalledKeyPath)
        }
    }
    
    private func installHelper() throws -> Bool
    {
        if try self.helperToolController.install()
        {
            DispatchQueue.main.async
            {
                self.textViewOutput.appendText(
                    "Helper installed successfully."
                )
                self.textFieldHelperInstalled.stringValue = "Yes"
                self.setValue(true, forKey: self.helperIsInstalledKeyPath)
            }
            return true
        }

        DispatchQueue.main.async
        {
            self.textFieldHelperInstalled.stringValue = "No"
            self.textViewOutput.appendText(
                "Failed install helper with unknown error."
            )
        }
        return false
    }
    
    private func uninstallHelper() throws
    {
        try helperToolController.withAuthorizedHelper(
            cachedAuthentication: nil)
        { helper, authData in
            helper.runCommandUninstall(authData: authData)
            { exitCode in
                DispatchQueue.main.async
                {
                    guard exitCode != kAuthorizationFailedExitCode else {
                        self.textViewOutput.appendText("Authentication Failed")
                        return
                    }
                    
                    if exitCode == 0
                    {
                        self.currentHelperAuthData = nil
                        self.textFieldAuthorizationCached.stringValue = "No"
                        self.buttonDestroyCachedAuthorization.isEnabled = false
                        self.helperIsInstalled = false
                    }
                    self.textViewOutput.appendText("Uninstall exit code: \(exitCode)")
                }
            }
        }
    }
    
    private func runAuthorizedCommand(inputPath: String) throws
    {
        try helperToolController.withAuthorizedHelper(
            cachedAuthentication: self.currentHelperAuthData)
        { helper, authData in
            helper.runCommandLs(withPath: inputPath, authData: authData)
            { (exitCode) in
                DispatchQueue.main.async
                {
                    // Verify that authentication was successful
                    guard exitCode != kAuthorizationFailedExitCode else {
                        self.textViewOutput.appendText("Authentication Failed")
                        return
                    }

                    self.textViewOutput.appendText("Command exit code: \(exitCode)")
                    if self.checkboxCacheAuthentication.state == .on, self.currentHelperAuthData == nil
                    {
                        self.currentHelperAuthData = authData
                        self.textFieldAuthorizationCached.stringValue = "Yes"
                        self.buttonDestroyCachedAuthorization.isEnabled = true
                    }
                }
            }
        }
    }

    @IBAction func buttonDestroyCachedAuthorization(_ sender: Any) {
        self.currentHelperAuthData = nil
        self.textFieldAuthorizationCached.stringValue = "No"
        self.buttonDestroyCachedAuthorization.isEnabled = false
    }

    @IBAction func buttonRunCommand(_ sender: Any) {
        guard
            let inputPath = self.inputPath,
            let helper = self.helperToolController.helper(nil)
        else { return }

        if self.checkboxRequireAuthentication.state == .on
        {
            do { try runAuthorizedCommand(inputPath: inputPath) }
            catch {
                self.textViewOutput.appendText(
                    "Command failed with error: \(error)"
                )
            }
        } else {
            helper.runCommandLs(withPath: inputPath) { (exitCode) in
                self.textViewOutput.appendText("Command exit code: \(exitCode)")
            }
        }
    }
}

