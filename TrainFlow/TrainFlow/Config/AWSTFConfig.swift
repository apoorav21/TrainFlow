import Foundation

/// AWS configuration for TrainFlow.
/// Values are populated from Config.plist after CDK deployment.
/// Until deployed, these contain placeholder values.
struct AWSTFConfig {
    static let shared = AWSTFConfig()

    let apiBaseURL: String
    let userPoolId: String
    let userPoolClientId: String
    let region: String

    private init() {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            // Fallback defaults (replace after deployment)
            apiBaseURL = "https://REPLACE_WITH_API_GATEWAY_URL.execute-api.ap-south-1.amazonaws.com/prod"
            userPoolId = "ap-south-1_REPLACE"
            userPoolClientId = "REPLACE_WITH_CLIENT_ID"
            region = "ap-south-1"
            return
        }
        apiBaseURL = dict["ApiBaseURL"] as? String
            ?? "https://REPLACE_WITH_API_GATEWAY_URL.execute-api.ap-south-1.amazonaws.com/prod"
        userPoolId = dict["UserPoolId"] as? String ?? "ap-south-1_REPLACE"
        userPoolClientId = dict["UserPoolClientId"] as? String ?? "REPLACE_WITH_CLIENT_ID"
        region = dict["Region"] as? String ?? "ap-south-1"
    }
}
