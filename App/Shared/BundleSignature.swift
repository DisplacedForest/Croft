#if os(macOS)
    import Foundation
    import Security

    enum BundleSignature {
        static func isDeveloperIDSigned(at url: URL = Bundle.main.bundleURL) -> Bool {
            var staticCode: SecStaticCode?
            guard
                SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
                let code = staticCode
            else { return false }
            var requirement: SecRequirement?
            guard
                SecRequirementCreateWithString(
                    "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13]"
                        as CFString,
                    [], &requirement) == errSecSuccess,
                let requirement
            else { return false }
            return SecStaticCodeCheckValidity(code, [], requirement) == errSecSuccess
        }
    }
#endif
