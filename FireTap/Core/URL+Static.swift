import Foundation

extension URL {
    /// Builds a URL from a compile-time-constant literal. Because the input is
    /// a `StaticString`, this can only be called with a hard-coded value, so a
    /// failure is a programmer error (a malformed literal) — never a runtime
    /// input problem. Avoids force-unwrapping `URL(string:)` in production code.
    init(static string: StaticString) {
        guard let url = URL(string: string.description) else {
            preconditionFailure("Invalid static URL literal: \(string)")
        }
        self = url
    }
}
