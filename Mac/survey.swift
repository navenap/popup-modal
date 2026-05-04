import Cocoa

// Fix for typing in borderless window
class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    var questions: [[String: Any]] = []
    var answerFields: [String: NSTextField] = [:]
    private var modalHeightConstraint: NSLayoutConstraint!

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        let modalView = NSView()
        modalView.wantsLayer = true
        modalView.layer?.backgroundColor = NSColor.white.cgColor
        modalView.layer?.cornerRadius = 16
        modalView.translatesAutoresizingMaskIntoConstraints = false
        
        blurView.addSubview(modalView)
        
        modalHeightConstraint = modalView.heightAnchor.constraint(equalToConstant: 250)
        modalHeightConstraint.isActive = true
        
        NSLayoutConstraint.activate([
            modalView.centerXAnchor.constraint(equalTo: blurView.centerXAnchor),
            modalView.centerYAnchor.constraint(equalTo: blurView.centerYAnchor),
            modalView.widthAnchor.constraint(equalToConstant: 400)
        ])
        
        // Keep Frame Based (Stable)
        let contentView = NSView(frame: NSRect(x: 20, y: 20, width: 360, height: 200))
        modalView.addSubview(contentView)
        
        /*var yPosition: CGFloat = 180
        
        for i in 1...3 {
            let label = NSTextField(labelWithString: "Question \(i)")
            label.frame = NSRect(x: 0, y: yPosition, width: 340, height: 20)
            label.textColor = .black
            
            let input = NSTextField(frame: NSRect(x: 0, y: yPosition, width: 340, height: 24))
            
            contentView.addSubview(label)
            contentView.addSubview(input)
            
            yPosition -= 70
        }*/

        //let exitButton = NSButton(title: "Exit (dev)", target: self, action: #selector(forceExit))
        /*
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        
        let stackView = NSStackView(frame: contentView.bounds)
        stackView.orientation = .vertical
        stackView.spacing = 12
       
        contentView.addSubview(stackView)
        scrollView.documentView = contentView
        modalView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: modalView.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        stackView.layoutSubtreeIfNeeded()
        contentView.frame.size.height = stackView.fittingSize.height
         
        let button = NSButton(title: "Submit", target: self, action: #selector(submit))
        button.frame = NSRect(x: 150, y: 40, width: 100, height: 40)
        button.bezelStyle = NSButton.BezelStyle.rounded
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemBlue.cgColor
        button.layer?.cornerRadius = 8
        button.layer?.masksToBounds = true
        button.contentTintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false

        modalView.addSubview(button)
        
            // Auto Layout
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: modalView.bottomAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: modalView.centerXAnchor),
            button.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20)
        ])
        */
        window.contentView = blurView
        window.makeKeyAndOrderFront(nil)
        
        loadQuestions(contentView: contentView)
    }
    
    func loadQuestions(contentView: NSView) {
        guard let url = URL(string: "https://script.google.com/macros/s/AKfycbygRIt1-Z2Ppvo8GTGFx28ktI8nhHK1eFkB99cp0LQReSV86gR8YZtnMNhn6xa3dD7d/exec") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                DispatchQueue.main.async {
                    
                    guard let randomQ = json.randomElement() else { return }
                    
                    let id = "\(randomQ["id"] ?? "")"
                    let text = "\(randomQ["question"] ?? "")"
                    
                    // clear old views ( important if reused)
                    contentView.subviews.forEach{ $0.removeFromSuperview() }
                    
                    // create label first - flexible
                    let label = NSTextField(labelWithString: text)
                    label.frame = NSRect(x: 0, y: 150, width: 340, height: 20)
                    label.textColor = .black
                    label.lineBreakMode = .byWordWrapping
                    label.maximumNumberOfLines = 0
                    label.preferredMaxLayoutWidth = 340
                    
                    // Auto Calculate height
                    let requiredHeight = label.fittingSize.height
                    label.frame.size.height = requiredHeight
                    
                    contentView.addSubview(label)
                    
                    // Input position Dynamically
                    let inputY = 150 - requiredHeight - 30
                    
                    let input = NSTextField(frame: NSRect(x: 0, y: inputY, width: 340, height: 28))
                    input.isBezeled = true
                    input.bezelStyle = .roundedBezel
                    //input.isBordered = true
                    input.drawsBackground = true
                    input.backgroundColor = .white
                    input.textColor = .black
                    //input.focusRingType = .default
                    input.isEditable = true
                    input.isSelectable = true
                    input.isEnabled = true
                    
                    contentView.addSubview(input)
                    self.answerFields[id] = input
                    
                    // Submit Button
                    let submitButton = NSButton(frame: NSRect(x: 120, y: 20, width: 120, height: 32))
                    submitButton.title = "Submit"
                    submitButton.bezelStyle = .rounded
                    submitButton.target = self
                    submitButton.action = #selector(self.submit)
                    
                    contentView.addSubview(submitButton)
                    
                    // modal size stable
                    self.modalHeightConstraint.constant =  250
                    
                    // force typing focus
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.activate(ignoringOtherApps: true)
                        self.window.makeKeyAndOrderFront(nil)
                        self.window.makeFirstResponder(input)
                    }
                }
            }
        }.resume()
    }

    @objc func submit() {
        print("clicked submit")
        
        guard let (id, field) = answerFields.first else { return }
        
        let answer = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if answer.isEmpty {
            showAlert(message: "Please answer the question before submitting.")
            return
        }
        
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
                    return
                }
                print("Response saved")
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
