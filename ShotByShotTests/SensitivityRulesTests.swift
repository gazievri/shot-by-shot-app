import Testing
@testable import ShotByShot

struct SensitivityRulesTests {
    @Test func passwordsAndCodesAreSecrets() {
        #expect(SensitivityRules.classify("Your password is hunter2") == .secret)
        #expect(SensitivityRules.classify("Recovery code: 4F7K-22PQ") == .secret)
        #expect(SensitivityRules.classify("Ваш пароль: qwerty123") == .secret)
        #expect(SensitivityRules.classify("Код восстановления 123 456") == .secret)
        #expect(SensitivityRules.classify("Write down your seed phrase") == .secret)
    }

    @Test func cardNumbersNeedAValidChecksum() {
        #expect(SensitivityRules.classify("Card 4111 1111 1111 1111 exp 12/29") == .secret)
        #expect(SensitivityRules.classify("5555-5555-5555-4444") == .secret)
        // Sixteen digits that fail the Luhn check: an order number, not a card.
        #expect(SensitivityRules.classify("Order 1234 5678 9012 3456") == .none)
        #expect(SensitivityRules.classify("0000 0000 0000 0000") == .none)
        #expect(SensitivityRules.classify("Call +1 415 555 0132") == .none)
    }

    @Test func luhnCheck() {
        #expect(SensitivityRules.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]))
        #expect(!SensitivityRules.passesLuhn([4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]))
    }

    @Test func documentsAndBankingArePersonal() {
        #expect(SensitivityRules.classify("Passport No. X1234567") == .personal)
        #expect(SensitivityRules.classify("Диагноз: ОРВИ") == .personal)
        #expect(SensitivityRules.classify("IBAN GB82 WEST 1234 5698 7654 32") == .personal)
        #expect(SensitivityRules.classify("P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<") == .personal)
    }

    @Test func ibanNeedsAValidChecksum() {
        #expect(SensitivityRules.containsIBAN("DE89 3704 0044 0532 0130 00"))
        #expect(!SensitivityRules.containsIBAN("GB82 WEST 1234 5698 7654 33"))
        #expect(!SensitivityRules.containsIBAN("AB12 is not an account"))
    }

    @Test func secretWinsOverPersonal() {
        #expect(SensitivityRules.classify("Passport scan. Password: abc") == .secret)
    }

    @Test func ordinaryScreenshotsAreNotSensitive() {
        #expect(SensitivityRules.classify("Standing desk, oak, 140 cm. $499") == .none)
        #expect(SensitivityRules.classify("") == .none)
        #expect(SensitivityRules.classify("Рецепт борща на 6 порций") == .none)
    }
}
