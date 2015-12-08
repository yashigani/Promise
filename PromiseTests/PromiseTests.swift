//
//  PromiseTests.swift
//  PromiseTests
//
//  Created by taiki on 11/28/15.
//  Copyright © 2015 yashigani. All rights reserved.
//

import XCTest
@testable import Promise

class PromiseTests: XCTestCase {
    enum DummyError: ErrorType {
        case Any
    }

    func testResolve() {
        let p = Promise.resolve(1)
        XCTAssert(p.state == .Fulfilled)
        if case .Value(let value) = p.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }

    func testReject() {
        let p = Promise<Int>.reject(DummyError.Any)
        XCTAssert(p.state == .Rejected)
        if case .Error(let error as DummyError) = p.result {
            XCTAssert(error == .Any)
        } else {
            XCTFail()
        }
    }

    func testResolved() {
        let expectation = expectationWithDescription("Promise.resolve")
        let p = Promise<Int> { resolve, _ in
            resolve(1)
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p.state == .Fulfilled)
        if case .Value(let value) = p.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }

    func testRejected() {
        let expectation = expectationWithDescription("Promise.reject")
        let p = Promise<Int> { _, reject in
            reject(DummyError.Any)
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p.state == .Rejected)
        if case .Error(let error as DummyError) = p.result {
            XCTAssert(error == .Any)
        } else {
            XCTFail()
        }
    }

    func testInitializePromiseWithOtherPromise() {
        let p = Promise<Int> { resolve, _ in
            sleep(3)
            resolve(1)
        }
        let p2 = Promise(p)
        XCTAssert(p2.state == .Fulfilled)
        if case .Value(let value) = p2.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }

    func testInitializePromiseWithAutoclosure() {
        let json = "{\"written_by\": \"yashigani\"}".dataUsingEncoding(NSUTF8StringEncoding)!
        var expectation = expectationWithDescription("success")
        let p1 = Promise(try NSJSONSerialization.JSONObjectWithData(json, options: []))
        p1.then { v in
            if let v = v as? NSObject {
                XCTAssert(v == ["written_by": "yashigani"])
            } else {
                XCTFail()
            }
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p1.state == .Fulfilled)

        let brokenJson = "{\"written_by\": \"yashigani\"".dataUsingEncoding(NSUTF8StringEncoding)!
        expectation = expectationWithDescription("failure")
        let p2 = Promise(try NSJSONSerialization.JSONObjectWithData(brokenJson, options: []))
        p2.`catch` { _ in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p2.state == .Rejected)
    }

    func testThen() {
        let expectation = expectationWithDescription("Promise.then")
        let p = Promise.resolve(1).then { v in v * 2 }
        p.then { _ -> Void in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p.state == .Fulfilled)
        if case .Value(let value) = p.result {
            XCTAssert(value == 2)
        } else {
            XCTFail()
        }
    }

    func testCatch() {
        let expectation = expectationWithDescription("Promise.catch")
        let p = Promise<Int>.reject(DummyError.Any).`catch` { e in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p.state == .Rejected)
        if case .Error( _ as DummyError) = p.result {
        } else {
            XCTFail()
        }
    }

    func testPromiseComposition() {
        func increment(v: Int) -> Int { return v + 1 }
        func doubleUp(v: Int) -> Int { return v * 2 }

        let expectation = expectationWithDescription("Promise.composition")
        let p = Promise.resolve(10)
                       .then(increment)
                       .then(doubleUp)
                       .`catch` { _ in XCTFail() }
                       .then { v in
                           XCTAssert(v == 22)
                           expectation.fulfill()
                       }
        waitForExpectationsWithTimeout(1, handler: nil)
        XCTAssert(p.state == .Fulfilled)
    }

    func testAll() {
        func timer(second: UInt32) -> Promise<UInt32> {
            return Promise { resolve, _ in
                sleep(second)
                resolve(second)
            }
        }

        var expectation = expectationWithDescription("Promise.all")
        let p1 = Promise.all([timer(1), timer(2), timer(3)]).then { v in
            XCTAssert(v == [1, 2, 3])
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5, handler: nil)
        XCTAssert(p1.state == .Fulfilled)

        expectation = expectationWithDescription("Promise.all")
        let p2 = Promise<UInt32> { resolve, reject in
            sleep(1)
            reject(DummyError.Any)
        }
        let p3 = Promise.all([timer(1), timer(2), timer(3), p2]).then { v in
            XCTFail()
        }.`catch` { e in
            switch e {
            case DummyError.Any: ()
            default: XCTFail()
            }
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5, handler: nil)
        XCTAssert(p3.state == .Rejected)
    }

    func testRace() {
        let p1 = Promise<Int> { resolve, _ in
            sleep(1)
            resolve(1)
        }
        let p2 = Promise<Int> { resolve, _ in
            sleep(2)
            resolve(2)
        }
        Promise.race([p1, p2]).then { v in
            XCTAssert(v == 1)
        }

        let p3 = Promise<Int> { resolve, _ in
            sleep(1)
            resolve(1)
        }
        let p4 = Promise<Int> { _, reject in
            sleep(2)
            reject(DummyError.Any)
        }
        Promise.race([p3, p4]).then { v in
            XCTAssert(v == 1)
        }.`catch` { _ in
            XCTFail()
        }

        let p5 = Promise<Int> { resolve, _ in
            sleep(2)
            resolve(1)
        }
        let p6 = Promise<Int> { _, reject in
            sleep(1)
            reject(DummyError.Any)
        }
        Promise.race([p5, p6]).then { v in
            XCTFail()
        }.`catch` { e in
            switch e {
            case DummyError.Any: ()
            default: XCTFail()
            }
        }
    }

}
