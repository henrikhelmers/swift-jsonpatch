//
//  JSONPatchTests.swift
//  JSONPatchTests
//
//  Created by Raymond Mccrae on 11/11/2018.
//  Copyright © 2018 Raymond McCrae.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

@testable import JSONPatch
import XCTest

class JSONPatchTests: XCTestCase {
    func evaluate(path: String, on json: JSONElement) -> JSONElement? {
        guard let ptr = try? JSONPointer(string: path) else {
            return nil
        }
        return try? json.evaluate(pointer: ptr)
    }

    // This test is based on the sample given in section 5 of RFC 6901
    // https://tools.ietf.org/html/rfc6901
    func testExample() throws {
        let sample = """
        {
        "foo": ["bar", "baz"],
        "": 0,
        "a/b": 1,
        "c%d": 2,
        "e^f": 3,
        "g|h": 4,
        "i\\\\j": 5,
        "k\\"l": 6,
        " ": 7,
        "m~n": 8
        }
        """

        let jsonObject = try JSONSerialization.jsonObject(with: Data(sample.utf8), options: [])
        let json = try JSONElement(any: jsonObject)

        XCTAssertEqual(evaluate(path: "", on: json), json)
        XCTAssertEqual(evaluate(path: "/foo", on: json), .array(value: ["bar", "baz"]))
        XCTAssertEqual(evaluate(path: "/foo/0", on: json), .string(value: "bar"))
        XCTAssertEqual(evaluate(path: "/", on: json), .number(value: NSNumber(value: 0)))
        XCTAssertEqual(evaluate(path: "/a~1b", on: json), .number(value: NSNumber(value: 1)))
        XCTAssertEqual(evaluate(path: "/c%d", on: json), .number(value: NSNumber(value: 2)))
        XCTAssertEqual(evaluate(path: "/e^f", on: json), .number(value: NSNumber(value: 3)))
        XCTAssertEqual(evaluate(path: "/g|h", on: json), .number(value: NSNumber(value: 4)))
        XCTAssertEqual(evaluate(path: "/i\\j", on: json), .number(value: NSNumber(value: 5)))
        XCTAssertEqual(evaluate(path: "/k\"l", on: json), .number(value: NSNumber(value: 6)))
        XCTAssertEqual(evaluate(path: "/ ", on: json), .number(value: NSNumber(value: 7)))
        XCTAssertEqual(evaluate(path: "/m~0n", on: json), .number(value: NSNumber(value: 8)))

        XCTAssertEqual(evaluate(path: "#", on: json), json)
        XCTAssertEqual(evaluate(path: "#/foo", on: json), .array(value: ["bar", "baz"]))
        XCTAssertEqual(evaluate(path: "#/foo/0", on: json), .string(value: "bar"))
        XCTAssertEqual(evaluate(path: "#/", on: json), .number(value: NSNumber(value: 0)))
        XCTAssertEqual(evaluate(path: "#/a~1b", on: json), .number(value: NSNumber(value: 1)))
        XCTAssertEqual(evaluate(path: "#/c%25d", on: json), .number(value: NSNumber(value: 2)))
        XCTAssertEqual(evaluate(path: "#/e%5Ef", on: json), .number(value: NSNumber(value: 3)))
        XCTAssertEqual(evaluate(path: "#/g%7Ch", on: json), .number(value: NSNumber(value: 4)))
        XCTAssertEqual(evaluate(path: "#/i%5Cj", on: json), .number(value: NSNumber(value: 5)))
        XCTAssertEqual(evaluate(path: "#/k%22l", on: json), .number(value: NSNumber(value: 6)))
        XCTAssertEqual(evaluate(path: "#/%20", on: json), .number(value: NSNumber(value: 7)))
        XCTAssertEqual(evaluate(path: "#/m~0n", on: json), .number(value: NSNumber(value: 8)))
    }

    func testOperationEquality() throws {
        let ptr = try JSONPointer(string: "")
        let oppa = JSONPatch.Operation.add(path: ptr, value: JSONElement(false))
        let oppb = JSONPatch.Operation.add(path: ptr, value: JSONElement(0))
        XCTAssertNotEqual(oppa, oppb)
    }

    func testTopLevelFragments() throws {
        let ptr = try JSONPointer(string: "")
        let doc = Data("3".utf8)
        let op = JSONPatch.Operation.replace(path: ptr, value: JSONElement(false))
        let patch = JSONPatch(operations: [op])
        let result = try patch.apply(to: doc,
                                 readingOptions: [.allowFragments],
                                 writingOptions: [])
        XCTAssertEqual(String(data: result, encoding: .utf8), "false")
    }

    func testLargeJson() throws {
        let sourceURL = Bundle.module.url(forResource: "bigexample1", withExtension: "json")!
        let targetURL = Bundle.module.url(forResource: "bigexample2", withExtension: "json")!
        let patchURL = Bundle.module.url(forResource: "bigpatch", withExtension: "json")!

        let sourceData = try Data(contentsOf: sourceURL)
        let targetData = try Data(contentsOf: targetURL)
        let patchData = try Data(contentsOf: patchURL)

        var sourceElem = try JSONSerialization.jsonElement(with: sourceData, options: [.mutableContainers])
        let targetElem = try JSONSerialization.jsonElement(with: targetData, options: [.mutableContainers])

        let patch = try JSONPatch(data: patchData)
        try sourceElem.apply(patch: patch)
        XCTAssertEqual(sourceElem, targetElem)
    }

    func testLargeJSONPerformance() throws {
        let sourceURL = Bundle.module.url(forResource: "bigexample1", withExtension: "json")!
        let patchURL = Bundle.module.url(forResource: "bigpatch", withExtension: "json")!

        let sourceData = try Data(contentsOf: sourceURL)
        let patchData = try Data(contentsOf: patchURL)

        measure {
            let patch = try? JSONPatch(data: patchData)
            _ = try? patch?.apply(to: sourceData)
        }
    }

    func testPatchRelative() throws {
        let source = """
        {"a": {}}
        """
        let patch = Data("""
        [{ "op": "add", "path": "/b", "value": "qux" }]
        """.utf8)

        let p = try JSONPatch(data: patch)
        let s = try JSONSerialization.jsonObject(with: Data(source.utf8), options: [])
        let applied = try p.apply(to: s, options: [.relative(to: JSONPointer(string: "/a"))])
        XCTAssertEqual(applied as? NSDictionary, ["a": ["b": "qux"]] as NSDictionary)
    }

    func testNonexistentValue() throws {
        let objectData = Data("""
        {
            "prop1": "Value1",
            "prop2": "Value2"
        }
        """.utf8)

        let patchData = Data("""
        [
            { "op": "replace", "path": "/prop3", "value": "Value3" }
        ]
        """.utf8)

        let patch = try JSONDecoder().decode(JSONPatch.self, from: patchData)

        do {
            _ = try patch.apply(to: objectData)
            XCTFail("Should have thrown a nonExistentValue error")
        } catch {
            if let error = error as? JSONError, error == .referencesNonexistentValue {
                // Succeeded
            } else {
                XCTFail("Should have thrown JSONError.referencesNonexistentValue, but throwed: \(error)")
            }
        }
    }

    func testIgnoreNonexistentValue() throws {
        let objectData = Data("""
        {
            "prop1": "Value1",
            "prop2": "Value2"
        }
        """.utf8)

        let patchData = Data("""
        [
            { "op": "replace", "path": "/prop3", "value": "Value3" }
        ]
        """.utf8)

        let patch = try JSONDecoder().decode(JSONPatch.self, from: patchData)

        do {
            _ = try patch.apply(to: objectData, applyingOptions: [.ignoreNonexistentValues])
            // Succeeded
        } catch {
            XCTFail("Should not have thrown JSONError.referencesNonexistentValue, throwed: \(error)")
        }
    }
}
