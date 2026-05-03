import Foundation

public enum OpenAIHTTPErrorMessage {
    public static func message(statusCode: Int, body: Data, prefix: String) -> String {
        let status = "\(prefix)\(statusCode)"
        guard let detail = providerMessage(from: body), !detail.isEmpty else {
            return status
        }
        return "\(status) - \(detail)"
    }

    private static func providerMessage(from body: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = normalized(error["message"] as? String) {
                return message
            }
            if let message = normalized(json["message"] as? String) {
                return message
            }
        }
        return normalized(String(data: body, encoding: .utf8))
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
