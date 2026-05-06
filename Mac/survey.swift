import Cocoa

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
    private var modalHeightConstraint: NSLayoutConstraint!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
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
        // Wait a bit for UI session to be ready (Important)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.activate(ignoringOtherApps: true)
            self.showWindow()
        }
    }
    
    func showWindow() {
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
        
        /*let loadingLabel = NSTextField(labelWithString: "Loading...")
        loadingLabel.font = NSFont.systemFont(ofSize: 20, weight: .medium)
        loadingLabel.textColor = NSColor.labelColor
        loadingLabel.alignment = .center
        
        loadingLabel.setContentHuggingPriority(.required, for: .vertical)
        loadingLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        stack.addArrangedSubview(loadingLabel)*/
        
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
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            
            if event.modifierFlags.contains([.command, .shift]) && event.characters == "a" {
                self.showAdminDialog()
                return nil
            }
            return event
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
        
        guard let url = URL(string: "https://script.google.com/macros/s/AKfycbygRIt1-Z2Ppvo8GTGFx28ktI8nhHK1eFkB99cp0LQReSV86gR8YZtnMNhn6xa3dD7d/exec") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                DispatchQueue.main.async {
                    
                    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                    
                    guard let randomQ = json.randomElement() else { return }
                    
                    let id = "\(randomQ["id"] ?? "")"
                    let text = "\(randomQ["question"] ?? "")"
                    
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
            "device_serial": Host.current().localizedName ?? "mac",
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
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.showAlert(message: "Failed to submit. Try agian.")
                    self.isSubmitting = false
                    self.submitButton?.isEnabled = true
                    self.submitButton?.title = "Submit"
                    return
                }
                
                self.submitButton?.title = "Submitted"
                self.actuallyCloseApp()
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
        window?.close()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)
app.run()
