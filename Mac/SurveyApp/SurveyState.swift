//
//  SurveyState.swift
//  SurveyApp
//
//  Created by Meesho on 08/05/26.
//

import Foundation

struct SurveyState: Codable, CustomStringConvertible {
    var lastAnsweredDate: String?
    var answeredToday: Bool = false
    var surveyCompleted: Bool = false
    var skipCountToday: Int = 0
    var lastSkipDate: String?

    
    var description: String {
        return """
        lastAnsweredDate: \(lastAnsweredDate ?? "nil"),
        answeredToday: \(answeredToday),
        surveyCompleted: \(surveyCompleted),
        skipCountToday: \(skipCountToday),
        lastSkipDate: \(lastSkipDate ?? "nil")
        """
    }
}
