import Foundation

nonisolated enum Sensitivity: String, Codable, Sendable {
    /// Nothing to hide.
    case none
    /// Documents, medical or banking screens: blurred until the person taps Show.
    case personal
    /// Passwords, codes, card numbers, seed phrases: blurred, with a warning.
    case secret
    /// Flagged by the system's sensitive content analysis.
    case explicit
}

/// Text rules for spotting screenshots that should not be shown by surprise.
/// Heuristics: both misses and false alarms are expected, hence "Not sensitive" in the UI.
nonisolated enum SensitivityRules {
    static func classify(_ text: String) -> Sensitivity {
        let lowered = text.lowercased()
        if secretMarkers.contains(where: lowered.contains) || containsCardNumber(text) {
            return .secret
        }
        if personalMarkers.contains(where: lowered.contains)
            || containsIBAN(text) || containsMachineReadableZone(text) {
            return .personal
        }
        return .none
    }

    /// Screenshots are as often in Russian as in English, so the markers cover both.
    private static let secretMarkers = [
        "password", "passcode", "recovery code", "backup code", "one-time code", "verification code",
        "secret key", "private key", "seed phrase", "recovery phrase", "secret phrase", "mnemonic",
        "cvv", "cvc",
        "пароль", "код восстановления", "резервный код", "одноразовый код", "код подтверждения",
        "секретный ключ", "приватный ключ", "сид-фраза", "секретная фраза",
    ]

    private static let personalMarkers = [
        "passport", "driver's license", "driving licence", "social security", "date of birth",
        "diagnosis", "prescription", "medical record", "blood test", "account balance", "bank statement",
        "паспорт", "водительское удостоверение", "снилс", "дата рождения",
        "диагноз", "медицинская карта", "анализ крови", "выписка по счёту", "остаток на счёте",
    ]

    /// 13 to 19 digits, possibly grouped, that pass the Luhn check.
    static func containsCardNumber(_ text: String) -> Bool {
        text.matches(of: /(?:\d[ \-]?){13,19}/).contains { match in
            let digits = match.output.compactMap(\.wholeNumberValue)
            return (13...19).contains(digits.count) && Set(digits).count > 1 && passesLuhn(digits)
        }
    }

    static func passesLuhn(_ digits: [Int]) -> Bool {
        let sum = digits.reversed().enumerated().reduce(0) { sum, pair in
            let doubled = pair.offset.isMultiple(of: 2) ? pair.element : pair.element * 2
            return sum + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }

    /// Country code, check digits and account, validated with the mod 97 checksum.
    static func containsIBAN(_ text: String) -> Bool {
        text.matches(of: /\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]){11,30}\b/).contains { match in
            let compact = match.output.filter { !$0.isWhitespace }
            guard (15...34).contains(compact.count) else { return false }
            let rearranged = compact.dropFirst(4) + compact.prefix(4)
            var remainder = 0
            for character in rearranged {
                guard let value = character.hexDigitValue ?? character.asciiValue.map({ Int($0) - 55 }),
                      (0...35).contains(value)
                else { return false }
                remainder = (remainder * (value > 9 ? 100 : 10) + value) % 97
            }
            return remainder == 1
        }
    }

    /// The machine-readable lines at the bottom of passports and ID cards.
    static func containsMachineReadableZone(_ text: String) -> Bool {
        text.matches(of: /[A-Z0-9<]{30,44}/).contains { $0.output.contains("<<") }
    }
}
