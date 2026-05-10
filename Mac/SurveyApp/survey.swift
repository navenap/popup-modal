//
//  survey.swift
//  SurveyApp
//

import Cocoa
import os

let logger = Logger(subsystem: "com.meesho.SurveyApp", category: "Survey")

func getMacSerialNumber() -> String {

    let task = Process()
    let pipe = Pipe()

    task.launchPath = "/usr/sbin/ioreg"
    task.arguments = ["-l"]

    task.standardOutput = pipe

    do {
        try task.run()
    } catch {
        return "UNKNOWN_MAC"
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()

    let output = String(data: data, encoding: .utf8) ?? ""

    for line in output.components(separatedBy: "\n") {

        if line.contains("IOPlatformSerialNumber") {

            let parts = line.components(separatedBy: "\"")

            if let serial = parts.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
               serial != "IOPlatformSerialNumber" {

                return serial
            }
        }
    }

    return "UNKNOWN_MAC"
}

// Fix for typing in borderless window
class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class HoverButton: NSButton {
    override func mouseEntered(with event: NSEvent) {
        // apply hover ONLY if not selected
        if self.state == .off {
            self.layer?.borderColor = NSColor.systemBlue.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        // reset ONLY if not selected
        if self.state == .off {
            self.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
        
    var window: NSWindow!
    var questions: [[String: Any]] = []
    var answerFields: [String: [NSButton]] = [:]
    var submitButton: NSButton?
    var isSubmitting = false
    var modalView: NSView!
    var keyMonitor: Any?
    private var modalHeightConstraint: NSLayoutConstraint!
    
    var session: URLSession! = {

        let config = URLSessionConfiguration.default

        config.timeoutIntervalForRequest = 15

        config.timeoutIntervalForResource = 30

        config.waitsForConnectivity = false

        return URLSession(configuration: config)
    }()
    
    @objc func systemDidWake() {

        logger.info("SYSTEM WAKE")

        self.session.invalidateAndCancel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {

            let config = URLSessionConfiguration.default

            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = false

            self.session = URLSession(configuration: config)

            logger.info("SESSION RECREATED")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        logger.info("APP STARTED")
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
            // ❌ Block CMD + Q
            if event.modifierFlags.contains(.command) && event.characters == "q" {
                return nil
            }
            
            // ❌ Block ESC
            if event.keyCode == 53 {
                return nil
            }
            
            // ✅ ADMIN shortcut (CTRL + SHIFT + A)
            if event.modifierFlags.contains([.control, .shift]) && event.characters == "a" {
                self.showAdminDialog()
                return nil
            }
            
            return event
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Wait a bit for UI session to be ready (Important)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            self.checkPendingSurvey()
        }
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        //registerLoginItem()
        print(Bundle.main.bundleIdentifier ?? "NO_BUNDLE")
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func registerLoginItem() {

        let appPath = Bundle.main.bundlePath

        let script = """
        tell application "System Events"
            if login item "SurveyAgent" exists then
                delete login item "SurveyAgent"
            end if

            make login item at end with properties {path:"\(appPath)", hidden:false}
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }

        if let error = error {
            print(error)
        }
    }
    
    func showWindow() {
        
        if window != nil {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        logger.info("SHOW WINDOW")
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        
        // Use KeyWindow
        window = KeyWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
            
        window.level = .screenSaver
        //window.acceptMouseMovedEvents = true
        window.appearance = nil // follow system automatically
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false

        // Blur Background
        let blurView = NSVisualEffectView(frame: frame)
        blurView.material = .hudWindow
        //blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.autoresizingMask = [.width, .height]

        // Modal
        modalView = NSView()
        modalView.wantsLayer = true
        modalView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        modalView.layer?.cornerRadius = 16
        modalView.translatesAutoresizingMaskIntoConstraints = false
        
        blurView.addSubview(modalView)
        
        NSLayoutConstraint.activate([
            modalView.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            modalView.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            modalView.widthAnchor.constraint(lessThanOrEqualToConstant: 700),
            modalView.widthAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.distribution = .gravityAreas
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        modalView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: modalView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: modalView.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            stack.topAnchor.constraint(equalTo: modalView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: modalView.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -20)
        ])
        
        window.contentView = blurView
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)

        window.orderFrontRegardless()
        
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.startAnimation(nil)

        // center nicely
        spinner.setContentHuggingPriority(.required, for: .vertical)
        spinner.setContentCompressionResistancePriority(.required, for: .vertical)

        stack.addArrangedSubview(spinner)
        
        let loadingText = NSTextField(labelWithString: "Loading...")
        loadingText.textColor = .secondaryLabelColor
        loadingText.alignment = .center

        stack.addArrangedSubview(loadingText)
        
        self.window.layoutIfNeeded()
        self.window.displayIfNeeded()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadQuestions(stack: stack)
        }
    }
    
    func showAdminDialog() {
        let alert = NSAlert()
        alert.messageText = "Admin Access"
        alert.informativeText = "Enter password to exit"
        alert.alertStyle = .warning
        
        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = passwordField
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // ✅ Attach to your main window
        alert.beginSheetModal(for: self.window) { response in
            if response == .alertFirstButtonReturn {
                if passwordField.stringValue == "_+inTERnal" {
                    self.actuallyCloseApp()
                } else {
                    self.showAlert(message: "Invalid password")
                }
            }
        }
    }
    
    func loadQuestions(stack: NSStackView) {
        logger.info("LOAD QUESTIONS")
        let deviceSerial = getMacSerialNumber()
        logger.info("SERIAL: \(deviceSerial)")
        
        let urlString = "https://script.google.com/macros/s/AKfycbygRIt1-Z2Ppvo8GTGFx28ktI8nhHK1eFkB99cp0LQReSV86gR8YZtnMNhn6xa3dD7d/exec?device_serial=\(deviceSerial)"

        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let today = formatter.string(from: Date())

        if StateManager.getLastAnsweredDate() == today &&
           StateManager.getAnsweredToday() {

            logger.info("ALREADY ANSWERED TODAY")
            self.actuallyCloseApp()
            return
        }

        session.dataTask(with: url) { data, _, _ in
            logger.info("API CALLED")
            if let data = data {
                logger.info("API RESPONSE: \(String(data: data, encoding: .utf8) ?? "")")
            }
            guard let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                self.questions = json
                
                DispatchQueue.main.async {
                    
                    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                    
                    if json.isEmpty {
                        // ✅ No questions left → close app
                        self.actuallyCloseApp()
                        return
                    }
                    
                    let installDate = UserDefaults.standard.string(forKey: "install_date")

                    if installDate == nil {

                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"

                        let today = formatter.string(from: Date())

                        UserDefaults.standard.set(today, forKey: "install_date")
                    }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    
                    guard let question = json.first else {

                        logger.info("SURVEY COMPLETED")

                        StateManager.saveSurveyCompleted(true)

                        self.actuallyCloseApp()

                        return
                    }
                    
                    let id = "\(question["id"] ?? "")"
                    let text = "\(question["question"] ?? "")"
                    
                    // create Question label first - flexible
                    let label = NSTextField(labelWithString: text)
                    label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
                    label.textColor = NSColor.labelColor
                    label.drawsBackground = false
                    label.lineBreakMode = .byWordWrapping
                    label.maximumNumberOfLines = 0
                    label.alignment = .center
                    
                    label.setContentHuggingPriority(.required, for: .vertical)
                    
                    stack.addArrangedSubview(label)
                    
                    // Options
                    let options = [
                        "Strongly Disagree",
                        "Disagree",
                        "Moderate",
                        "Agree",
                        "Strongly Agree"
                    ]
                    
                    let buttonStack = NSStackView()
                    buttonStack.orientation = .horizontal
                    buttonStack.spacing = 10
                    buttonStack.alignment = .centerY
                    buttonStack.distribution = .fillProportionally
                    buttonStack.translatesAutoresizingMaskIntoConstraints = false
                    
                    buttonStack.setContentHuggingPriority(.required, for: .vertical)
                    buttonStack.setContentCompressionResistancePriority(.required, for: .vertical)
                    
                    var buttons: [NSButton] = []
                    
                    for option in options {

                        let btn = HoverButton(title: option, target: self, action: #selector(self.radioSelected(_:)))
                        
                        btn.setButtonType(.toggle)
                        btn.bezelStyle = .regularSquare
                        btn.translatesAutoresizingMaskIntoConstraints = false
                        
                        btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
                        
                        btn.setContentHuggingPriority(.required, for: .horizontal)
                        
                        // Style like card
                        btn.wantsLayer = true
                        btn.layer?.cornerRadius = 8
                        btn.layer?.borderWidth = 1
                        btn.layer?.borderColor = NSColor.separatorColor.cgColor
                        btn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                        btn.contentTintColor = NSColor.labelColor
                        btn.addCursorRect(btn.bounds, cursor: .pointingHand)
                        
                        buttonStack.addArrangedSubview(btn)
                        buttons.append(btn)
                        
                        btn.addTrackingArea(NSTrackingArea(
                            rect: btn.bounds,
                            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                            owner: btn,
                            userInfo: nil
                        ))
                    }
                    
                    let container = NSView()
                    container.translatesAutoresizingMaskIntoConstraints = false
                    
                    container.addSubview(buttonStack)
                    
                    NSLayoutConstraint.activate([
                        buttonStack.topAnchor.constraint(equalTo: container.topAnchor),
                        buttonStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        buttonStack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                        buttonStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                    ])
                    
                    stack.addArrangedSubview(container)
                    
                    // Store buttons instead of textfield
                    self.answerFields[id] = buttons
                    
                    // Submit Button
                    let submitButton = NSButton(title: "Submit", target: self, action: #selector(self.submit))
                    submitButton.translatesAutoresizingMaskIntoConstraints = false
                    submitButton.bezelStyle = .rounded
                    submitButton.contentTintColor = NSColor.controlTextColor
                    submitButton.wantsLayer = true
                    submitButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
                    submitButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
                    
                    stack.addArrangedSubview(submitButton)
                    self.submitButton = submitButton
                    
                    self.modalView.alphaValue = 0
                    
                    // Fade in after everything is ready
                    NSAnimationContext.runAnimationGroup({ ctx in
                        ctx.duration = 0.3
                        self.modalView.alphaValue = 1
                    }, completionHandler: nil)
                    
                    // force typing focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.activate(ignoringOtherApps: true)
                        self.window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }.resume()
    }
    
    @objc func radioSelected(_ sender: NSButton) {
        guard let (_, buttons) = answerFields.first else { return }
        
        for btn in buttons {
            // reset all buttons
            btn.state = .off
            btn.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            btn.contentTintColor = NSColor.labelColor
            btn.layer?.borderColor = NSColor.separatorColor.cgColor
        }
        
        // apply only to selected
        sender.state = .on
        sender.layer?.backgroundColor = NSColor.systemBlue.cgColor
        sender.layer?.borderColor = NSColor.systemBlue.cgColor
        sender.contentTintColor = .white
    }

    @objc func submit() {
        if isSubmitting { return } // prevent multiple clicks
        
        guard let (id, buttons) = answerFields.first else { return }
        
        let selected = buttons.first { $0.state == NSControl.StateValue.on }
        
        guard let selectedBtn = selected else {
            showAlert(message: "Please select an option before submitting")
            return
        }
        
        isSubmitting = true
        
        submitButton?.isEnabled = false
        submitButton?.title = "Submitting..."
        
        let answer = selectedBtn.title
        
        let payload: [String: Any] = [
            "device_serial": getMacSerialNumber(),
            "username": NSUserName(),
            "answers": [
                [
                    "question_id": id,
                    "answer": answer
                ]
            ]
        ]
        
        guard let url = URL(string: "https://script.google.com/macros/s/AKfycbygRIt1-Z2Ppvo8GTGFx28ktI8nhHK1eFkB99cp0LQReSV86gR8YZtnMNhn6xa3dD7d/exec") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {

                    logger.error("SUBMIT ERROR: \(error.localizedDescription)")

                    self.showAlert(message: "Failed to submit")

                    self.isSubmitting = false

                    self.submitButton?.isEnabled = true

                    self.submitButton?.title = "Submit"

                    return
                }

                guard let http = response as? HTTPURLResponse else {

                    self.showAlert(message: "Invalid server response")

                    return
                }

                guard http.statusCode == 200 else {

                    logger.error("HTTP STATUS: \(http.statusCode)")

                    self.showAlert(message: "Server error")

                    return
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"

                let today = formatter.string(from: Date())

                StateManager.saveAnsweredToday(true)
                StateManager.saveLastAnsweredDate(today)
                
                self.submitButton?.title = "Submitted"

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.actuallyCloseApp()
                }
            }
        }
        task.resume()
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.window.level = .screenSaver
        // Attach to your window
        alert.beginSheetModal(for: self.window, completionHandler: nil)
    }

    func actuallyCloseApp() {
        window?.orderOut(nil)
        window = nil
        NSApp.hide(nil)
    }
    
    @objc func screenUnlocked() {

        logger.info("Screen unlocked")

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {

            self.hasInternetConnection { connected in

                DispatchQueue.main.async {

                    if !connected {

                        print("NO INTERNET AFTER UNLOCK")

                        return
                    }

                    NSApp.activate(ignoringOtherApps: true)

                    self.checkPendingSurvey()
                }
            }
        }
    }
    
    func hasInternetConnection(completion: @escaping (Bool) -> Void) {

        guard let url = URL(string: "https://www.google.com") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)

        request.timeoutInterval = 5

        session.dataTask(with: request) { _, response, error in

            if error != nil {
                completion(false)
                return
            }

            completion(true)

        }.resume()
    }
    
    func checkPendingSurvey() {

        let state = StateManager.load()
        logger.info("state: \( "\(state)" )")
        let today = currentDate()
        
        if state.lastAnsweredDate != today {

            StateManager.saveAnsweredToday(false)
            UserDefaults.standard.synchronize()
        }

        if state.lastAnsweredDate == today &&
           state.answeredToday {
            return
        }

        hasInternetConnection { connected in

            DispatchQueue.main.async {

                if !connected {

                    print("NO INTERNET")

                    return
                }

                if self.window == nil {

                    self.showWindow()

                } else {

                    self.window.makeKeyAndOrderFront(nil)

                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
    
    func currentDate() -> String {

        let formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.string(from: Date())
    }
}

