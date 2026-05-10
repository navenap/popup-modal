//
//  SurveyState.swift
//  SurveyApp
//

import Foundation

struct SurveyState: Codable, CustomStringConvertible {
    var installDate: String?
    var lastAnsweredDate: String?
    var answeredToday: Bool = false
    var surveyCompleted: Bool = false
    
    var description: String {
        return """
        installDate: \(installDate ?? "nil"),
        lastAnsweredDate: \(lastAnsweredDate ?? "nil"),
        answeredToday: \(answeredToday),
        surveyCompleted: \(surveyCompleted)
        """
    }
}
