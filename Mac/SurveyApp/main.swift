//
//  main.swift
//  SurveyApp
//
//  Created by Meesho on 08/05/26.
//

import Cocoa

let app = NSApplication.shared

let delegate = AppDelegate()

app.delegate = delegate

app.setActivationPolicy(.regular)

app.activate(ignoringOtherApps: true)

app.run()

