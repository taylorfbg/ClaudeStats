import Foundation
import SwiftUI
import WebKit
import Combine
import ServiceManagement

class StatsViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var sessionPercent: Double = 0
    @Published var sessionResetsIn: String = "--"
    @Published var weeklyPercent: Double = 0
    @Published var weeklyResetsAt: String = "--"
    @Published var errorMessage: String?
    @Published var lastRefresh: Date?
    @Published var isLoading: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var needsLogin: Bool = true
    @Published var initialLoadComplete: Bool = false
    @Published var hasAutoOpenedLoginWindow: Bool = false

    // MARK: - User Settings
    @AppStorage("showPercentInMenuBar") var showPercentInMenuBar: Bool = false

    // MARK: - WebView
    let webView: WKWebView

    // MARK: - Private
    private var timer: Timer?
    private var hasAttemptedLoad = false

    override init() {
        // Use a persistent data store so login session is remembered
        let config = WKWebViewConfiguration()
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore
        webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        webView.navigationDelegate = self
        loadUsagePage()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods
    func refresh() {
        loadUsagePage()
    }

    func loadUsagePage() {
        guard let url = URL(string: "https://claude.ai/settings/usage") else { return }
        isLoading = true
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    func logout() {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let claudeRecords = records.filter { $0.displayName.contains("claude") }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: claudeRecords) {
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                    self.needsLogin = true
                    self.sessionPercent = 0
                    self.weeklyPercent = 0
                    self.sessionResetsIn = "--"
                    self.weeklyResetsAt = "--"
                    self.lastRefresh = nil
                    self.hasAutoOpenedLoginWindow = false
                }
            }
        }
    }

    // MARK: - Launch at Login
    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        objectWillChange.send()
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
    }

    // MARK: - Private Methods
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isLoggedIn else { return }
            self.loadUsagePage()
        }
    }

    func extractUsageData() {
        let js = """
        (function() {
            var result = {session: null, weekly: null};
            var allText = document.body.innerText;

            // Split the page text into lines for sequential parsing
            var lines = allText.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; });
            var fullText = lines.join(' | ');

            // Find all "X% used" occurrences with their positions in the full text
            var sessionIdx = allText.indexOf('Current session');
            var weeklyIdx = allText.indexOf('Weekly limits');
            var allModelsIdx = allText.indexOf('All models');

            // Get all percentage matches with positions
            var re = /(\\d+)%\\s*used/g;
            var match;
            var percentages = [];
            while ((match = re.exec(allText)) !== null) {
                percentages.push({percent: parseInt(match[1]), pos: match.index});
            }

            // Get all reset time matches with positions
            var resetRe = /Resets?\\s+(?:in\\s+)?([\\d]+\\s*h(?:r|our)?s?\\s*[\\d]*\\s*m(?:in)?|[A-Za-z]+\\s+[\\d]+[:\\.][\\d]+\\s*[AP]M)/gi;
            var resetMatch;
            var resets = [];
            while ((resetMatch = resetRe.exec(allText)) !== null) {
                resets.push({text: resetMatch[1], pos: resetMatch.index});
            }

            // Session: first "X% used" after "Current session"
            if (sessionIdx >= 0) {
                for (var i = 0; i < percentages.length; i++) {
                    if (percentages[i].pos > sessionIdx) {
                        result.session = {percent: percentages[i].percent};
                        break;
                    }
                }
                // Session reset: first reset after "Current session"
                for (var i = 0; i < resets.length; i++) {
                    if (resets[i].pos > sessionIdx && result.session) {
                        result.session.resets = resets[i].text;
                        break;
                    }
                }
            }

            // Weekly: find "X% used" after "All models" (which is under "Weekly limits")
            var weeklySearchFrom = allModelsIdx >= 0 ? allModelsIdx : weeklyIdx;
            if (weeklySearchFrom >= 0) {
                for (var i = 0; i < percentages.length; i++) {
                    if (percentages[i].pos > weeklySearchFrom) {
                        result.weekly = {percent: percentages[i].percent};
                        break;
                    }
                }
                // Weekly reset: first reset after "All models" or "Weekly limits"
                for (var i = 0; i < resets.length; i++) {
                    if (resets[i].pos > weeklySearchFrom && result.weekly) {
                        result.weekly.resets = resets[i].text;
                        break;
                    }
                }
            }

            // Fallback: if we didn't find session/weekly by position, use order
            if (!result.session && percentages.length >= 1) {
                result.session = {percent: percentages[0].percent};
            }
            if (!result.weekly && percentages.length >= 2) {
                result.weekly = {percent: percentages[percentages.length - 1].percent};
            }

            // Check if we're on a login page
            result.isLoginPage = (allText.includes('Log in') || allText.includes('Sign in')) &&
                                  !allText.includes('usage') && !allText.includes('% used');

            result.debug = {
                totalPercentages: percentages.length,
                sessionIdx: sessionIdx,
                weeklyIdx: weeklyIdx,
                allModelsIdx: allModelsIdx
            };

            return JSON.stringify(result);
        })()
        """

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Parse error: \(error.localizedDescription)"
                    return
                }

                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.errorMessage = "Could not parse page data"
                    return
                }

                // Check if login page
                if let isLogin = json["isLoginPage"] as? Bool, isLogin {
                    self.needsLogin = true
                    self.isLoggedIn = false
                    self.errorMessage = "Please log in to claude.ai"
                    return
                }

                if let session = json["session"] as? [String: Any] {
                    if let percent = session["percent"] as? Int {
                        self.sessionPercent = Double(percent)
                    }
                    if let resets = session["resets"] as? String {
                        self.sessionResetsIn = resets
                    }
                }

                if let weekly = json["weekly"] as? [String: Any] {
                    if let percent = weekly["percent"] as? Int {
                        self.weeklyPercent = Double(percent)
                    }
                    if let resets = weekly["resets"] as? String {
                        self.weeklyResetsAt = resets
                    }
                }

                if self.sessionPercent > 0 || self.weeklyPercent > 0 {
                    self.isLoggedIn = true
                    self.needsLogin = false
                    self.errorMessage = nil
                    self.lastRefresh = Date()
                } else if self.errorMessage == nil {
                    self.errorMessage = "No usage data found on page"
                }

                self.initialLoadComplete = true
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension StatsViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a moment for the page to render dynamic content
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.extractUsageData()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Failed to load: \(error.localizedDescription)"
            self.initialLoadComplete = true
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Connection failed: \(error.localizedDescription)"
            self.initialLoadComplete = true
        }
    }
}
