//
//  StateManager.swift
//  SurveyApp
//

import Foundation

class StateManager {

    static func load() -> SurveyState {

        let defaults = UserDefaults.standard

        return SurveyState(
            installDate: defaults.string(forKey: "install_date"),
            lastAnsweredDate: defaults.string(forKey: "last_answered_date"),
            answeredToday: defaults.bool(forKey: "answered_today"),
            surveyCompleted: defaults.bool(forKey: "survey_completed")
        )
    }

    static func save(_ state: SurveyState) {

        let defaults = UserDefaults.standard

        defaults.set(state.installDate, forKey: "install_date")
        defaults.set(state.lastAnsweredDate, forKey: "last_answered_date")
        defaults.set(state.answeredToday, forKey: "answered_today")
        defaults.set(state.surveyCompleted, forKey: "survey_completed")
    }

    static func saveInstallDate(_ value: String) {

        UserDefaults.standard.set(value, forKey: "install_date")
    }

    static func getInstallDate() -> String? {

        return UserDefaults.standard.string(forKey: "install_date")
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
