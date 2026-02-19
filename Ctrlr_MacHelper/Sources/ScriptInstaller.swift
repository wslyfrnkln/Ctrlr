import Foundation

// MARK: - Script Installer

/// Installs the bundled Ableton Remote Script into the user's Ableton User Library.
struct ScriptInstaller {

    static let installPath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Music/Ableton/User Library/Remote Scripts/Ctrlr")

    /// True when both Python files are present at the install path.
    static var isInstalled: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: installPath.appendingPathComponent("__init__.py").path)
            && fm.fileExists(atPath: installPath.appendingPathComponent("Ctrlr.py").path)
    }

    /// Copies bundled AbletonScript files to ~/Music/Ableton/User Library/Remote Scripts/Ctrlr/.
    /// Overwrites existing files.
    static func install() throws {
        guard let src = Bundle.main.resourceURL?
            .appendingPathComponent("AbletonScript") else {
            throw InstallError.bundleNotFound
        }
        let fm = FileManager.default
        try fm.createDirectory(at: installPath, withIntermediateDirectories: true)
        for file in ["__init__.py", "Ctrlr.py"] {
            let dest = installPath.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: src.appendingPathComponent(file), to: dest)
        }
    }

    enum InstallError: Error, LocalizedError {
        case bundleNotFound
        case copyFailed(String)

        var errorDescription: String? {
            switch self {
            case .bundleNotFound: return "Script bundle not found inside app."
            case .copyFailed(let msg): return "Copy failed: \(msg)"
            }
        }
    }
}
