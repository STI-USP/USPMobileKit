import XCTest
@testable import USPAuthKit

final class USPAuthKitTests: XCTestCase {
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
}
