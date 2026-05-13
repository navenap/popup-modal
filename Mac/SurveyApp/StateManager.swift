//
//  StateManager.swift
//  SurveyApp
//
//  Created by Meesho on 08/05/26.
//

import Foundation

class StateManager {

    static func load() -> SurveyState {

        let defaults = UserDefaults.standard

        return SurveyState(
            lastAnsweredDate: defaults.string(forKey: "last_answered_date"),
            answeredToday: defaults.bool(forKey: "answered_today"),
            surveyCompleted: defaults.bool(forKey: "survey_completed"),
            skipCountToday: defaults.integer(forKey: "skip_count_today"),
            lastSkipDate: defaults.string(forKey: "last_skip_date")
        )
    }

    static func save(_ state: SurveyState) {

        let defaults = UserDefaults.standard

        defaults.set(state.lastAnsweredDate, forKey: "last_answered_date")
        defaults.set(state.answeredToday, forKey: "answered_today")
        defaults.set(state.surveyCompleted, forKey: "survey_completed")
        defaults.set(state.skipCountToday, forKey: "skip_count_today")
        defaults.set(state.lastSkipDate, forKey: "last_skip_date")
    }

    static func saveLastAnsweredDate(_ value: String) {

        UserDefaults.standard.set(value, forKey: "last_answered_date")
    }

    static func getLastAnsweredDate() -> String? {

        return UserDefaults.standard.string(forKey: "last_answered_date")
    }

    static func saveAnsweredToday(_ value: Bool) {

        UserDefaults.standard.set(value, forKey: "answered_today")
    }

    static func getAnsweredToday() -> Bool {

        return UserDefaults.standard.bool(forKey: "answered_today")
    }

    static func saveSurveyCompleted(_ value: Bool) {

        UserDefaults.standard.set(value, forKey: "survey_completed")
    }

    static func getSurveyCompleted() -> Bool {

        return UserDefaults.standard.bool(forKey: "survey_completed")
    }
}
