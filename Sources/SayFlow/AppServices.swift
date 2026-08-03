import AppKit
import ApplicationServices
import Carbon
import Foundation
import SayFlowCore
import Network

enum ApplicationPaths {
    private static let currentSupportDirectoryName = "SayFlow"

    static var supportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(currentSupportDirectoryName, isDirectory: true)
    }

    static var legacySupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(LegacyProductIdentity.applicationSupportDirectoryName, isDirectory: true)
    }
}

enum CurrentApp {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.3"
    }
}

final class LocalEnvironmentSecretStore {
    private let fileURL: URL

    init(applicationSupportDirectory: URL) {
        fileURL = applicationSupportDirectory.appendingPathComponent("provider.env", isDirectory: false)
    }

    func read(reference: String) -> String? {
        guard let variableName = ProviderSecretReference.environmentVariableName(from: reference) else {
            return nil
        }
        if let processValue = ProcessInfo.processInfo.environment[variableName]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !processValue.isEmpty {
            return processValue
        }
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        let value = LocalEnvironmentFile.parse(raw)[variableName]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    func save(_ value: String, reference: String) throws {
        guard let variableName = ProviderSecretReference.environmentVariableName(from: reference) else {
            throw NSError(domain: "SayFlow", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid local environment reference."])
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let raw = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let rendered = LocalEnvironmentFile.render(updating: raw, variableName: variableName, value: value)
        try rendered.write(to: fileURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

final class AccessibilityTextService {
    func isTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func selectedText() -> String? {
        guard let focused = focusedElement() else {
            return nil
        }
        var selected: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selected)
        if result == .success,
           let text = (selected as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        return selectedTextFromTextMarkerRange(focused)
    }

    func replaceSelection(with text: String) -> Bool {
        guard let focused = focusedElement() else {
            return false
        }
        let result = AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    func pasteClipboardIntoFocusedSelection() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_V),
                keyDown: false
              ) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    func copyFocusedSelectionToClipboard() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
              ) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success else {
            return nil
        }
        guard let focused,
              AccessibilityElementValidator.isAccessibilityElement(focused) else {
            return nil
        }
        return (focused as! AXUIElement)
    }

    private func selectedTextFromTextMarkerRange(_ element: AXUIElement) -> String? {
        var markerRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &markerRange)
        guard rangeResult == .success, let markerRange else {
            return nil
        }

        var markerText: CFTypeRef?
        let textResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXStringForTextMarkerRange" as CFString,
            markerRange,
            &markerText
        )
        guard textResult == .success,
              let text = (markerText as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }
}

final class ClipboardService {
    var changeCount: Int {
        NSPasteboard.general.changeCount
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func currentString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

final class SpeechService {
    private let synthesizer = NSSpeechSynthesizer()

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking()
        }
        synthesizer.startSpeaking(trimmed)
    }
}

final class NetworkStatusMonitor {
    private let queue = DispatchQueue(label: "SayFlow.NetworkStatusMonitor")
    private var monitor: Any?
    private(set) var isOnline = true
    var onStatusChange: ((Bool) -> Void)?

    func start() {
        guard #available(macOS 10.14, *) else {
            isOnline = true
            onStatusChange?(true)
            return
        }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self else { return }
                self.isOnline = online
                self.onStatusChange?(online)
            }
        }
        monitor.start(queue: queue)
        self.monitor = monitor
    }

    deinit {
        if #available(macOS 10.14, *), let monitor = monitor as? NWPathMonitor {
            monitor.cancel()
        }
    }
}

final class UpdateCheckService {
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/ZhiPengH/sayflow-release/releases/latest")!

    func checkLatestRelease(currentVersion: String, completion: @escaping (UpdateAvailability) -> Void) {
        var request = URLRequest(url: latestReleaseURL)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SayFlow/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            let availability: UpdateAvailability
            if let data,
               let evaluated = try? GitHubReleaseUpdateEvaluator.evaluate(latestReleaseJSON: data, currentVersion: currentVersion) {
                availability = evaluated
            } else {
                availability = .upToDate
            }
            DispatchQueue.main.async {
                completion(availability)
            }
        }.resume()
    }
}

final class ProviderConnectionTestClient {
    struct TestError: Error {
        let message: String
    }

    private var activeTask: URLSessionDataTask?

    func test(request: URLRequest, completion: @escaping (Result<Int, TestError>) -> Void) {
        activeTask?.cancel()
        activeTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(TestError(message: error.localizedDescription)))
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(statusCode) else {
                let body = data ?? Data()
                let message = OpenAIHTTPErrorMessage.message(
                    statusCode: statusCode,
                    body: body,
                    prefix: L10n.tr(.apiRequestFailedPrefix)
                )
                DispatchQueue.main.async {
                    completion(.failure(TestError(message: message)))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.success(statusCode))
            }
        }
        activeTask?.resume()
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }
}

final class HotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    var onTrigger: (() -> Void)?

    func register(_ configuration: HotKeyConfiguration) -> HotKeyRegistrationResult {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else {
                return noErr
            }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onTrigger?()
            }
            return noErr
        }, 1, &eventType, selfPointer, &eventHandler)
        guard handlerStatus == noErr else {
            eventHandler = nil
            return HotKeyRegistrationPolicy.evaluate(handlerStatus: Int32(handlerStatus), shortcutStatus: 0)
        }

        let identifier = EventHotKeyID(signature: OSType(0x53464C57), id: 1)
        let shortcutStatus = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifierFlags,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        let result = HotKeyRegistrationPolicy.evaluate(
            handlerStatus: Int32(handlerStatus),
            shortcutStatus: Int32(shortcutStatus)
        )
        if case .failed = result {
            unregister()
        }
        return result
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}

final class OpenAIStreamingClient: NSObject {
    private var activeSession: URLSession?
    private var activeDelegate: StreamingDelegate?

    func stream(
        request: URLRequest,
        onSnapshot: @escaping (CorrectionSnapshot) -> Void,
        onError: @escaping (String, String?) -> Void,
        onComplete: @escaping (CorrectionSnapshot) -> Void
    ) {
        let delegate = StreamingDelegate(onSnapshot: onSnapshot, onError: onError, onComplete: onComplete)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        activeDelegate = delegate
        activeSession = session
        session.dataTask(with: request).resume()
    }

    func cancel() {
        activeSession?.invalidateAndCancel()
        activeSession = nil
        activeDelegate = nil
    }

    private final class StreamingDelegate: NSObject, URLSessionDataDelegate {
        private var parser = OpenAIStreamParser()
        private var accumulator = StreamingCorrectionAccumulator()
        private var responseBody = Data()
        private var httpStatus: Int?
        private var receivedStreamContent = false
        private var completedFromStream = false
        private let onSnapshot: (CorrectionSnapshot) -> Void
        private let onError: (String, String?) -> Void
        private let onComplete: (CorrectionSnapshot) -> Void

        init(
            onSnapshot: @escaping (CorrectionSnapshot) -> Void,
            onError: @escaping (String, String?) -> Void,
            onComplete: @escaping (CorrectionSnapshot) -> Void
        ) {
            self.onSnapshot = onSnapshot
            self.onError = onError
            self.onComplete = onComplete
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            httpStatus = (response as? HTTPURLResponse)?.statusCode
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            responseBody.append(data)
            if let httpStatus, !(200..<300).contains(httpStatus) {
                return
            }
            do {
                let events = try parser.append(data)
                for event in events {
                    switch event {
                    case .content(let content):
                        receivedStreamContent = true
                        let snapshot = accumulator.append(content)
                        DispatchQueue.main.async { self.onSnapshot(snapshot) }
                    case .done:
                        completedFromStream = true
                        let snapshot = accumulator.finish()
                        deliverCompletion(snapshot)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError("\(L10n.tr(.streamParseFailedPrefix))\(error)", String(data: data, encoding: .utf8))
                }
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            defer { session.invalidateAndCancel() }
            if let error {
                DispatchQueue.main.async {
                    self.onError("\(L10n.tr(.networkRequestFailedPrefix))\(error.localizedDescription)", nil)
                }
                return
            }
            if let httpStatus, !(200..<300).contains(httpStatus) {
                let body = String(data: responseBody, encoding: .utf8)
                let message = OpenAIHTTPErrorMessage.message(
                    statusCode: httpStatus,
                    body: responseBody,
                    prefix: L10n.tr(.apiRequestFailedPrefix)
                )
                DispatchQueue.main.async {
                    self.onError(message, body)
                }
                return
            }
            if completedFromStream {
                return
            }
            let responseOverride = OpenAICompletionFallback.responseOverride(
                from: responseBody,
                hasReceivedStreamContent: receivedStreamContent
            )
            let snapshot = accumulator.finish(with: responseOverride)
            deliverCompletion(snapshot)
        }

        private func deliverCompletion(_ snapshot: CorrectionSnapshot) {
            switch CorrectionCompletionPolicy.action(for: snapshot) {
            case .complete(let snapshot):
                DispatchQueue.main.async {
                    self.onComplete(snapshot)
                }
            case .malformedJSON(let raw):
                DispatchQueue.main.async {
                    self.onError(L10n.tr(.malformedAIJSONRetry), raw)
                }
            }
        }
    }
}
