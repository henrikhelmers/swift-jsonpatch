//
//  JSONPatchTests.swift
//  JSONPatchTests
//
//  Created by Michiel Horvers on 01/24/2020.
//  Copyright © 2020 Michiel Horvers.
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
import Foundation
import Testing

private struct Person: Codable {
    var firstName: String
    var lastName: String
    var age: Int
}

struct JSONCodableTests {
    @Test func testCreatePatch() throws {
        let source = Person(firstName: "Michiel", lastName: "Horvers", age: 99)
        let target = Person(firstName: "Michiel", lastName: "Horvers", age: 100)

        let patch = try JSONPatch.createPatch(from: source, to: target)
        try #require(patch.operations.count == 1, "Patch should have only 1 operation, but has \(patch.operations.count)")

        let dict = patch.operations[0].jsonObject

        #expect((dict["op"] as? String) == "replace", "Operation should be 'replace', but is: \(String(describing: dict["op"]))")
        #expect((dict["path"] as? String) == "/age", "Path should be 'age', but is: \(String(describing: dict["path"]))")
        #expect((dict["value"] as? Int) == 100, "Value should be 100, but is: \(String(describing: dict["value"]))")
    }

    @Test func testApplyPatch() throws {
        let person = Person(firstName: "Michiel", lastName: "Horvers", age: 99)
        let patchData = Data("""
        [
            { "op": "replace", "path": "/age", "value": 100 }
        ]
        """.utf8)
        let patch = try JSONDecoder().decode(JSONPatch.self, from: patchData)

        let patchedPerson = try patch.applied(to: person)
        #expect(patchedPerson.age == 100, "Age should be patched to 100, but is: \(patchedPerson.age)")
    }
}
