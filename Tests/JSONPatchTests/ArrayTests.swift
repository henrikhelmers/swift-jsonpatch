//
//  ArrayTests.swift
//  JSONPatchTests
//
//  Created by Raymond Mccrae on 21/12/2018.
//  Copyright © 2018 Raymond McCrae. All rights reserved.
//

@testable import JSONPatch
import Foundation
import Testing

struct ArrayTests {
    @Test func testLevel1DeepCopy() throws {
        let a = NSArray(array: ["a", "b", "c"])
        let b = a.deepMutableCopy()

        #expect(b.count == 3)
        try #require(b[0] as? String == "a")
        try #require(b[1] as? String == "b")
        try #require(b[2] as? String == "c")
    }

    @Test func testLevel2DeepCopy() throws {
        let a = NSMutableArray(array: ["a", "b", "c"])
        let b = NSMutableArray(array: [a])
        let c = b.deepMutableCopy()
        b.add("d")
        a.add("e")

        #expect(c.count == 1)
        let d = try #require(c[0] as? NSMutableArray)

        #expect(d.count == 3)
        try #require(d[0] as? String == "a")
        try #require(d[1] as? String == "b")
        try #require(d[2] as? String == "c")
    }

    @Test func testLevel3DeepCopy() throws {
        let a = NSMutableArray(array: ["a", "b", "c"])
        let b = NSMutableArray(array: [a])
        let c = NSMutableArray(array: [b])
        let d = c.deepMutableCopy()
        b.add("d")
        a.add("e")
        c.add("f")

        #expect(d.count == 1)
        let e = try #require(d[0] as? NSMutableArray)

        #expect(e.count == 1)
        let f = try #require(e[0] as? NSMutableArray)

        #expect(f.count == 3)
        try #require(f[0] as? String == "a")
        try #require(f[1] as? String == "b")
        try #require(f[2] as? String == "c")
    }

    @Test func testDictDeepCopy() throws {
        let dict = NSMutableDictionary(dictionary: ["a": "1"])
        let array = NSMutableArray(array: [dict])
        let copy = array.deepMutableCopy()
        array.add("b")
        dict["b"] = "2"

        #expect(copy.count == 1)
        let copyDict = try #require(copy[0] as? NSMutableDictionary)
        try #require(copyDict.count == 1)
        try #require(copyDict["a"] as? String == "1")
    }

    @Test func testStringDeepCopy() throws {
        let array = NSMutableArray(array: [NSMutableString(string: "1")])
        let copy = array.deepMutableCopy()
        (array[0] as! NSMutableString).setString("2")

        #expect(copy.count == 1)
        try #require(copy[0] as? String == "1")
    }
}
