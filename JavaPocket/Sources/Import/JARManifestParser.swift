import Foundation
import CoreFoundation
import ZIPFoundation

struct JARManifest {
    let values: [String: String]
    let iconData: Data?

    var name: String {
        let midletName = values["MIDlet-Name"]
        guard let declaration = values["MIDlet-1"] else {
            return midletName ?? "Unknown MIDlet"
        }
        let declaredName = declaration.split(separator: ",", omittingEmptySubsequences: false)
            .first.map(String.init)?.trimmingCharacters(in: .whitespaces)
        return declaredName?.isEmpty == false ? declaredName! : (midletName ?? "Unknown MIDlet")
    }

    var vendor: String { values["MIDlet-Vendor"] ?? "Unknown Vendor" }
    var version: String { values["MIDlet-Version"] ?? "Unknown" }
    var profile: String { values["MicroEdition-Profile"] ?? "MIDP" }
    var configuration: String { values["MicroEdition-Configuration"] ?? "CLDC" }

    var mainClass: String? {
        values["MIDlet-1"]?.split(separator: ",", omittingEmptySubsequences: false)
            .last.map(String.init)?.trimmingCharacters(in: .whitespaces)
    }

    var phoneType: String? {
        if values["Nokia-MIDlet-Category"] != nil { return "Nokia" }
        return nil
    }

    var screenSize: (width: Int, height: Int) {
        let candidates = [
            "Nokia-MIDlet-Canvas-Size",
            "MIDlet-ScreenSize",
            "Nokia-MIDlet-Original-Display-Size",
            "MIDlet-Display-Size"
        ]
        for key in candidates {
            if let value = values[key], let size = Self.parseSize(value) { return size }
        }
        if let fileName = values["File-Name"], let size = Self.parseSize(fileName) { return size }
        return (240, 320)
    }

    private static func parseSize(_ value: String) -> (Int, Int)? {
        let pattern = #"(?<!\d)(\d{2,4})\s*[xX,*]\s*(\d{2,4})(?!\d)"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                in: value,
                range: NSRange(value.startIndex..., in: value)
              ),
              let widthRange = Range(match.range(at: 1), in: value),
              let heightRange = Range(match.range(at: 2), in: value),
              let width = Int(value[widthRange]),
              let height = Int(value[heightRange]),
              width > 0,
              height > 0
        else { return nil }
        return (width, height)
    }
}

struct JARManifestParser {
    func parse(url: URL) throws -> JARManifest {
        guard url.pathExtension.lowercased() == "jar" else {
            throw GameStorageError.unsupportedFile
        }
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw GameStorageError.invalidJAR
        }
        guard let manifestEntry = archive.first(where: {
            $0.path.caseInsensitiveCompare("META-INF/MANIFEST.MF") == .orderedSame
        }) else {
            throw GameStorageError.manifestMissing
        }

        let manifestData = try extract(manifestEntry, from: archive)
        guard let content = decodeManifest(manifestData) else {
            throw GameStorageError.invalidJAR
        }
        var values = parseLines(content)
        values["File-Name"] = url.lastPathComponent

        let iconPath = iconPath(from: values)
        let iconData = iconPath.flatMap { path -> Data? in
            let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
            guard let entry = archive.first(where: {
                $0.path.caseInsensitiveCompare(normalized) == .orderedSame
            }) else { return nil }
            return try? extract(entry, from: archive)
        }
        return JARManifest(values: values, iconData: iconData)
    }

    private func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    private func decodeManifest(_ data: Data) -> String? {
        let encodings: [String.Encoding] = [
            .utf8,
            .windowsCP1252,
            .isoLatin1,
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            ))
        ]
        return encodings.lazy.compactMap { String(data: data, encoding: $0) }.first
    }

    private func parseLines(_ content: String) -> [String: String] {
        var values: [String: String] = [:]
        var key: String?
        var value = ""

        func flush() {
            if let key { values[key] = value }
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                value += line.dropFirst()
                continue
            }
            flush()
            guard let colon = line.firstIndex(of: ":") else {
                key = nil
                value = ""
                continue
            }
            key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            value = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
        }
        flush()
        return values
    }

    private func iconPath(from values: [String: String]) -> String? {
        if let declaration = values["MIDlet-1"] {
            let fields = declaration.split(separator: ",", omittingEmptySubsequences: false)
            if fields.count > 1 {
                let value = String(fields[1]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        return values["MIDlet-Icon"]
    }
}
