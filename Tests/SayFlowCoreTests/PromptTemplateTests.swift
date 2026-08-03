import Foundation

enum PromptTemplateTests {
    static func defaultTemplateMatchesGrammarCorrectionContract() throws {
        let template = PromptTemplate.defaultGrammarCorrection

        try expectEqual(template.activeSystemPromptID, "PromptA")
        try expectEqual(template.systemPrompts.map(\.id), ["PromptA", "PromptB", "PromptC", "PromptD", "PromptE"])
        try expectEqual(template.systemPrompts[0].title, "PromptA")
        try expectEqual(template.systemPrompts.map(\.sceneName), ["PromptA", "PromptB", "PromptC", "PromptD", "PromptE"])
        try expect(template.systemPrompts[1].system.contains("专门辅导中国程序员"))
        try expect(template.systemPrompts[1].system.contains("程序员英语实用贴士"))
        try expect(template.system.contains("corrected"))
        try expect(template.system.contains("changes"))
        try expect(template.system.contains("translation_zh"))
        try expect(template.system.contains("good_to_know"))
        try expectEqual(template.user, "{{text}}")
        try expectEqual(template.renderUser(text: "I has a book."), "I has a book.")
    }

    static func validatorRejectsEmptyActiveSystemPrompt() throws {
        try expectEqual(
            PromptTemplateValidator.validate(PromptTemplate(system: "", user: "{{text}}")),
            .invalid("Active system prompt cannot be empty.")
        )
    }

    static func validatorUsesFixedUserPromptAndDoesNotRequireVisiblePlaceholderEditing() throws {
        let systemOnly = PromptTemplate(system: "Fix this text: {{text}}", user: "Return JSON.")
        let fixedUser = PromptTemplate(system: "Return JSON.", user: "Legacy user prompt without placeholder")

        try expectEqual(PromptTemplateValidator.validate(systemOnly), .valid)
        try expectEqual(PromptTemplateValidator.validate(fixedUser), .valid)
        try expectEqual(systemOnly.renderSystem(text: "I has a book."), "Fix this text: I has a book.")
        try expectEqual(fixedUser.renderUser(text: "I has a book."), "I has a book.")
    }

    static func promptStoreCreatesDefaultFileAndPreservesCustomTemplate() throws {
        let directory = try TemporaryDirectory()
        let store = PromptStore(applicationSupportDirectory: directory.url)

        let initial = try store.load()
        try expectEqual(initial, .defaultGrammarCorrection)
        try expect(FileManager.default.fileExists(atPath: directory.url.appendingPathComponent("prompts.json").path))

        var custom = PromptTemplate.defaultGrammarCorrection
        custom.activeSystemPromptID = "PromptB"
        custom.setSystem("Return programmer JSON.", for: "PromptB")
        custom.setSceneName("邮件润色", for: "PromptB")
        try store.save(custom)

        try expectEqual(try store.load(), custom)
    }

    static func promptStoreRestrictsExistingFilePermissionsToOwner() throws {
        let directory = try TemporaryDirectory()
        let store = PromptStore(applicationSupportDirectory: directory.url)
        let template = PromptTemplate.defaultGrammarCorrection
        try store.save(template)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: store.fileURL.path)

        _ = try store.load()

        let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
        let permissions = try unwrap(attributes[.posixPermissions] as? NSNumber).intValue & 0o777
        try expectEqual(permissions, 0o600)
    }

    static func promptStoreRejectsInvalidActiveSystemPromptFilesEditedExternally() throws {
        let directory = try TemporaryDirectory()
        let store = PromptStore(applicationSupportDirectory: directory.url)
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        var invalid = PromptTemplate.defaultGrammarCorrection
        invalid.activeSystemPromptID = "PromptC"
        try JSONEncoder().encode(invalid).write(to: store.fileURL)

        do {
            _ = try store.load()
            throw TestFailure(message: "Expected prompt load validation to fail", file: #file, line: #line)
        } catch let error as PromptStore.ValidationError {
            try expectEqual(error.message, "Active system prompt cannot be empty.")
        }
    }

    static func importPolicyRejectsDecodedTemplatesThatWouldFailSaveValidation() throws {
        var invalid = PromptTemplate.defaultGrammarCorrection
        invalid.activeSystemPromptID = "PromptD"
        let data = try JSONEncoder().encode(invalid)

        do {
            _ = try PromptTemplateImportPolicy.decodeValidated(from: data)
            throw TestFailure(message: "Expected import validation to fail", file: #file, line: #line)
        } catch let error as PromptStore.ValidationError {
            try expectEqual(error.message, "Active system prompt cannot be empty.")
        }
    }

    static func importPolicyAcceptsLegacyUserPromptTemplates() throws {
        let valid = PromptTemplate(system: "Return JSON.", user: "Legacy visible user prompt")
        let data = try JSONEncoder().encode(valid)

        try expectEqual(try PromptTemplateImportPolicy.decodeValidated(from: data), valid)
    }

    static func promptTemplateDecodesLegacyUserPromptKeyAndExportsCompatibilityKeys() throws {
        let legacy = """
        {
          "systemPrompt": "Legacy system prompt.",
          "userPrompt": "Legacy user prompt without text token"
        }
        """
        let decoded = try JSONDecoder().decode(PromptTemplate.self, from: Data(legacy.utf8))

        try expectEqual(decoded.activeSystemPromptID, "PromptA")
        try expectEqual(decoded.system, "Legacy system prompt.")
        try expectEqual(decoded.user, "{{text}}")
        try expectEqual(decoded.renderUser(text: "I has a book."), "I has a book.")

        let exported = try String(data: JSONEncoder().encode(decoded), encoding: .utf8) ?? ""
        try expect(exported.contains("\"userPrompt\""))
        try expect(exported.contains("\"{{text}}\""))
    }

    static func promptSceneNamesActAsFixedSlotAliasesForMenuSwitching() throws {
        var template = PromptTemplate.defaultGrammarCorrection
        template.activeSystemPromptID = "PromptC"
        template.setSceneName("日常语法", for: "PromptA")
        template.setSceneName("邮件润色", for: "PromptB")
        template.setSceneName("  ", for: "PromptC")
        template.systemPrompts.append(PromptSystemPrompt(id: "PromptF", title: "PromptF", sceneName: "Extra", system: "Never show"))

        try expectEqual(
            PromptSceneMenuPresentation.items(for: template),
            [
                PromptSceneMenuItem(id: "PromptA", title: "日常语法", isActive: false),
                PromptSceneMenuItem(id: "PromptB", title: "邮件润色", isActive: false),
                PromptSceneMenuItem(id: "PromptC", title: "PromptC", isActive: true),
                PromptSceneMenuItem(id: "PromptD", title: "PromptD", isActive: false),
                PromptSceneMenuItem(id: "PromptE", title: "PromptE", isActive: false)
            ]
        )
    }
}
