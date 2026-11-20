import Foundation

let defaults = UserDefaults(suiteName: "group.com.namanmittal.famcare")
if let data = defaults?.data(forKey: "widget_family_wellness") {
    print(String(data: data, encoding: .utf8) ?? "no utf8")
} else {
    print("No data found in app group")
}
