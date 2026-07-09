import Foundation

enum UpdateChecker {

    struct Release {
        let version: String   // tag with any leading "v" stripped
        let url: URL          // html_url of the release page
    }

    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/svcho/Lumo-for-Mac/releases/latest")!

    /// Numeric dotted-version comparison: returns true when `remote` is newer
    /// than `current`. "1.0.10" > "1.0.2"; unequal lengths pad with zeros.
    static func isNewer(remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").map { Int($0) ?? 0 }
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(r.count, c.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }

    static func parseLatestRelease(from data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let urlString = json["html_url"] as? String,
              let url = URL(string: urlString) else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Release(version: version, url: url)
    }

    static func fetchLatestRelease(completion: @escaping (Release?) -> Void) {
        URLSession.shared.dataTask(with: latestReleaseAPI) { data, _, _ in
            let release = data.flatMap { parseLatestRelease(from: $0) }
            DispatchQueue.main.async { completion(release) }
        }.resume()
    }
}
