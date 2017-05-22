//
//  PilosaTests.swift
//  PilosaTests
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import XCTest
@testable import Pilosa

extension Result {
    func print() {
        Swift.print(self)
    }
}

class PilosaTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testFrameQuery() {
        
        let client = Client()
        let index = try! Index(name: "repos")
        let frame = try! index.frame(name: "language")
        
        print(client.query(frame[2]))
    }
    
    func testSetBit() {
        let client = Client()
        let index = try! Index(name: "repos", columnLabel: "repo_id")
        let frame = try! index.frame(name: "language")
        
        client.status().print()
        client.ensure(index)
        client.ensure(frame)
        
        client.query(
            index.batch(
                frame.setBit(1,1),
                frame.setBit(1,2),
                frame.setBit(2,3)
            )
        )
        
        
        client.query(
            frame[2].union(frame[3]).count()
        ).print()
    }
    
    func testTopN() {
        let client = Client()
        let index = try! Index(name: "repos", columnLabel: "repo_id")
        let frame = try! index.frame(name: "language")
        client.query(try! frame.topN(n: 20)).print()
    }
    
    func testURI() {
        
        struct Segments {
            let scheme: String
            let host: String
            let port: Int
            
            init(_ scheme: String, _ host: String, _ port: Int) {
                self.scheme = scheme
                self.host = host
                self.port = port
            }
            
            func matches(_ uri: URI?) -> Bool {
                if let uri = uri {
                    return uri.scheme == scheme && uri.host == host && uri.port == port
                }
                return false
            }
        }
        
        [
            "http://localhost:10101",
            "http://localhost",
            "http+ssl://:10101",
            "localhost:10101",
            "localhost",
            ":10101"
            ].forEach {
                XCTAssertTrue(Segments("http", "localhost", 10101).matches(URI(address: $0)))
        }
        
        XCTAssertEqual(URI(address: "invalid!"), nil)
    }
}
