#if BENCHMARK
import Foundation

extension Vault {
    /// Профиль с выдуманными аккаунтами для замеров производительности.
    static func benchmark(accounts count: Int) -> Vault {
        let accounts = (0..<count).map { index in
            OTPAccount(
                issuer: "Service \(index + 1)",
                name: index.isMultiple(of: 2) ? "user\(index + 1)@example.com" : "",
                secret: Data((0..<20).map { _ in UInt8.random(in: 0...255) })
            )
        }
        return Vault(profiles: [Profile(name: "Benchmark", accounts: accounts)])
    }
}
#endif
