import Foundation

enum PromptTemplateTests {
    static func defaultTemplateMatchesGrammarCorrectionContract() throws {
        let template = PromptTemplate.defaultGrammarCorrection

        try expect(template.system.contains("corrected"))
        try expect(template.system.contains("changes"))
        try expect(template.system.contains("translation_zh"))
        try expect(template.system.contains("good_to_know"))
        try expect(template.user.contains("{{text}}"))
        try expectEqual(template.renderUser(text: "I has a book."), "I has a book.")
    }

    static func validatorRejectsMissingTextPlaceholderAndEmptySystemPrompt() throws {
        try expectEqual(
            PromptTemplateValidator.validate(PromptTemplate(system: "", user: "{{text}}")),
            .invalid("System prompt cannot be empty.")
        )
        try expectEqual(
            PromptTemplateValidator.validate(PromptTemplate(system: "Fix grammar", user: "No placeholder")),
            .invalid("Prompt template must contain {{text}}.")
        )
    }

    static func validatorAcceptsTextPlaceholderInEitherPromptField() throws {
        let systemOnly = PromptTemplate(system: "Fix this text: {{text}}", user: "Return JSON.")
        let userOnly = PromptTemplate(system: "Return JSON.", user: "Fix this text: {{text}}")

        try expectEqual(PromptTemplateValidator.validate(systemOnly), .valid)
        try expectEqual(PromptTemplateValidator.validate(userOnly), .valid)
        try expectEqual(systemOnly.renderSystem(text: "I has a book."), "Fix this text: I has a book.")
    }

    static func promptStoreCreatesDefaultFileAndPreservesCustomTemplate() throws {
        let directory = try TemporaryDirectory()
        let store = PromptStore(applicationSupportDirectory: directory.url)

        let initial = try store.load()
        try expectEqual(initial, .defaultGrammarCorrection)
        try expect(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("prompts.json").path))

        let custom = PromptTemplate(system: "Return JSON.", user: "Please fix {{text}}")
        try store.save(custom)

        try expectEqual(try store.load(), custom)
    }

    static func promptStoreRejectsInvalidTemplateFilesEditedExternally() throws {
        let directory = try TemporaryDirectory()
        let store = PromptStore(applicationSupportDirectory: directory.url)
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        let invalid = PromptTemplate(system: "Fix grammar.", user: "No placeholder")
        try JSONEncoder().encode(invalid).write(to: store.fileURL)

        do {
            _ = try store.load()
            throw TestFailure(message: "Expected prompt load validation to fail", file: #file, line: #line)
        } catch let error as PromptStore.ValidationError {
            try expectEqual(error.message, "Prompt template must contain {{text}}.")
        }
    }

    static func importPolicyRejectsDecodedTemplatesThatWouldFailSaveValidation() throws {
        let invalid = PromptTemplate(system: "Fix grammar", user: "No placeholder")
        let data = try JSONEncoder().encode(invalid)

        do {
            _ = try PromptTemplateImportPolicy.decodeValidated(from: data)
            throw TestFailure(message: "Expected import validation to fail", file: #file, line: #line)
        } catch let error as PromptStore.ValidationError {
            try expectEqual(error.message, "Prompt template must contain {{text}}.")
        }
    }

    static func importPolicyAcceptsValidDecodedTemplates() throws {
        let valid = PromptTemplate(system: "Return JSON.", user: "Please fix {{text}}")
        let data = try JSONEncoder().encode(valid)

        try expectEqual(try PromptTemplateImportPolicy.decodeValidated(from: data), valid)
    }
}
