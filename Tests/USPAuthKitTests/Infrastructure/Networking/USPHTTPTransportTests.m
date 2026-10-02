#import "USPAuthArchitectureTestCase.h"

@implementation USPAuthArchitectureTests (USPHTTPTransportTests)
- (void)testTransportPreservesBytesHTTPStatusAndTransportError {
  for (NSNumber *status in @[@200, @500]) {
    StubStatus = status.integerValue; StubWait = NO; StubError = nil;
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration; config.protocolClasses = @[StubURLProtocol.class];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    USPURLSessionTransport *transport = [[USPURLSessionTransport alloc] initWithSession:session];
    XCTestExpectation *done = [self expectationWithDescription:@"HTTP response"];
    [transport executeRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.invalid/transport"]] completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
      XCTAssertNil(error); XCTAssertEqual(response.statusCode, status.integerValue); XCTAssertEqualObjects(data, [@"fixture-bytes" dataUsingEncoding:NSUTF8StringEncoding]); [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:2]; [session invalidateAndCancel];
  }
  StubError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
  NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration; config.protocolClasses = @[StubURLProtocol.class];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
  XCTestExpectation *done = [self expectationWithDescription:@"transport error"];
  [[[USPURLSessionTransport alloc] initWithSession:session] executeRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.invalid"]] completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) { XCTAssertEqual(error.code, NSURLErrorNotConnectedToInternet); XCTAssertNil(response); [done fulfill]; }];
  [self waitForExpectations:@[done] timeout:2]; [session invalidateAndCancel]; StubError = nil;
}

- (void)testTransportHandleCancelsURLSessionTask {
  StubWait = YES; StubError = nil;
  NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration; config.protocolClasses = @[StubURLProtocol.class];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
  XCTestExpectation *done = [self expectationWithDescription:@"cancelled"];
  id<USPCancellable> handle = [[[USPURLSessionTransport alloc] initWithSession:session] executeRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://example.invalid"]] completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) { XCTAssertEqual(error.code, NSURLErrorCancelled); [done fulfill]; }];
  [handle cancel]; [self waitForExpectations:@[done] timeout:2]; [session invalidateAndCancel]; StubWait = NO;
}

- (void)testHTTPClientJSONRequestAndEmptyBodyAreTransportNeutral {
  HTTPClient *client = [[HTTPClient alloc] initWithTransport:self.transport];
  __block BOOL done = NO;
  [client postJSON:@{@"fixture":@1} toURL:[NSURL URLWithString:@"https://example.invalid"] headers:@{@"X-Fixture":@"yes"} completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) { XCTAssertEqual(data.length, 0u); XCTAssertEqual(response.statusCode, 204); XCTAssertNil(error); done = YES; }];
  XCTAssertEqualObjects(self.transport.requests[0].HTTPMethod, @"POST");
  XCTAssertEqualObjects([self.transport.requests[0] valueForHTTPHeaderField:@"Content-Type"], @"application/json; charset=UTF-8");
  XCTAssertEqualObjects([self bodyAt:0], (@{@"fixture":@1}));
  XCTAssertEqualObjects([self.transport.requests[0] valueForHTTPHeaderField:@"X-Fixture"], @"yes");
  [self.transport respond:0 text:@"" status:204 error:nil]; XCTAssertTrue(done);
}
@end
