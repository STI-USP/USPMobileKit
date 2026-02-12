import XCTest
@testable import USPAuthKit

final class USPAuthKitTests: XCTestCase {
    private func parseOAuthQuery(_ query: String) -> [String: String] {
        let selector = NSSelectorFromString("parametersFromQueryString:")
        let classCandidates = ["OAuth1Controller", "USPAuthKit.OAuth1Controller"]

        for className in classCandidates {
            guard let cls = NSClassFromString(className) as? NSObject.Type else { continue }
            guard cls.responds(to: selector) else { continue }
            guard let result = cls.perform(selector, with: query)?.takeUnretainedValue() as? [String: String] else {
                XCTFail("Parser retornou tipo inesperado para \(className).")
                return [:]
            }
            return result
        }

        XCTFail("Classe OAuth1Controller não encontrada para testar parser.")
        return [:]
    }

    func testUserMappingPreservesWSUserIDAndVinculos() {
        let rawUser: [String: Any] = [
            "loginUsuario": "jdoe",
            "nomeUsuario": "John Doe",
            "emailPrincipalUsuario": "john@usp.br",
            "wsuserid": "123456",
            "vinculo": [
                [
                    "codigoSetor": 10,
                    "codigoUnidade": 20,
                    "nomeUnidade": "Instituto de Testes",
                    "nomeVinculo": "Aluno",
                    "siglaUnidade": "ITEST",
                    "tipoVinculo": "GRAD"
                ]
            ]
        ]

        let user = USPAuthUser(dictionary: rawUser)

        XCTAssertEqual(user.wsuserid, "123456")
        XCTAssertEqual(user.nomeUsuario, "John Doe")
        XCTAssertEqual(user.vinculos.count, 1)
        XCTAssertEqual(user.vinculos.first?.siglaUnidade, "ITEST")
    }

    func testUserMappingHandlesMissingOptionalFields() {
        let user = USPAuthUser(dictionary: [:])
        XCTAssertEqual(user.wsuserid, "")
        XCTAssertTrue(user.vinculos.isEmpty)
    }

    func testConfigFactoryMethodsExposeExpectedBaseURL() {
        let dev = USPAuthConfig.dev(withConsumerKey: "ck", consumerSecret: "cs", appKey: "app")
        let prod = USPAuthConfig.prod(withConsumerKey: "ck", consumerSecret: "cs", appKey: "app")
        let custom = USPAuthConfig.custom(withBaseURL: "https://auth.interno.usp.br", consumerKey: "ck", consumerSecret: "cs", appKey: "app")

        XCTAssertEqual(dev.baseURL, "https://dev.uspdigital.usp.br")
        XCTAssertEqual(prod.baseURL, "https://uspdigital.usp.br")
        XCTAssertEqual(custom.baseURL, "https://auth.interno.usp.br")
        XCTAssertEqual(custom.appKey, "app")
    }

    func testOAuthQueryParserIgnoresInvalidPairsWithoutCrashing() {
        let parsed = parseOAuthQuery("oauth_token=abc&&=invalido&semvalor&oauth_verifier=xyz")

        XCTAssertEqual(parsed["oauth_token"], "abc")
        XCTAssertEqual(parsed["oauth_verifier"], "xyz")
        XCTAssertNil(parsed[""])
        XCTAssertNil(parsed["semvalor"])
    }

    func testOAuthQueryParserDecodesEncodedValues() {
        let parsed = parseOAuthQuery("oauth_verifier=abc%23_%3D&oauth_token=123")

        XCTAssertEqual(parsed["oauth_verifier"], "abc#_=")
        XCTAssertEqual(parsed["oauth_token"], "123")
    }
}
