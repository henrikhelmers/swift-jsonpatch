//
//  JSONPatch.swift
//  JSONPatch
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

import Foundation

/// Implementation of IETF JSON Patch (RFC6902). JSON Patch is a format
/// for expressing a sequence of operations to apply to a target JSON document.
/// This implementation works with the representions of JSON produced with
/// JSONSerialization.
///
/// https://tools.ietf.org/html/rfc6902
final public class JSONPatch: Codable {

    /// The mimetype for json-patch
    public static let mimetype = "application/json-patch+json"

    /// Options given to the patch process.
    @frozen
    public enum ApplyOption: Equatable {
        /// By default the patch will be applied directly on to the json object
        /// given, which is the most memory efficient option. However when applying
        /// a patch directly the result is not atomic, if an error occurs then the
        /// json object may be left in a partial state. If applyOnCopy is given then a copy of
        /// the json document is created and the patch applied to the copy.
        case applyOnCopy
        /// All references to non existent values will be ignored and the patch will continue applying all remaining operations
        case ignoreNonexistentValues
        /// Can be used to apply the patch to sub-element within the json document. Using this option will cause the patch process to
        /// treat the specified json element as the root element while applying the patch.
        case relative(to: JSONPointer)
    }

    /// A representation of the supported operations json-patch.
    /// (see [RFC6902], Section 4)
    @frozen
    public enum Operation {
        case add(path: JSONPointer, value: JSONElement)
        case remove(path: JSONPointer)
        case replace(path: JSONPointer, value: JSONElement)
        case move(from: JSONPointer, path: JSONPointer)
        case copy(from: JSONPointer, path: JSONPointer)
        case test(path: JSONPointer, value: JSONElement)
    }

    /// An array of json-patch operations that will be applied in sequence.
    public let operations: [JSONPatch.Operation]

    /// A JSON Array represent of the receiver compatible with JSONSerialization.
    public var jsonArray: NSArray {
        operations.map { $0.jsonObject } as NSArray
    }

    /// Initializes a JSONPatch instance with an array of operations.
    ///
    /// - Parameters:
    ///   - operations: An array of operations.
    public init(operations: [JSONPatch.Operation]) {
        self.operations = operations
    }

    /// Initializes a JSONPatch instance from a JSON array (the result of using
    /// JSONSerialization). The array should directly contain a list of json-patch
    /// operations as NSDictionary representations.
    ///
    /// - Parameters:
    ///   - jsonArray: An array obtained from JSONSerialization containing json-patch operations.
    public convenience init(jsonArray: NSArray) throws {
        var operations: [JSONPatch.Operation] = []
        for (index, element) in (jsonArray as Array).enumerated() {
            guard let obj = element as? NSDictionary else {
                throw JSONError.invalidPatchFormat
            }
            let operation = try JSONPatch.Operation(jsonObject: obj, index: index)
            operations.append(operation)
        }
        self.init(operations: operations)
    }

    /// Initializes a JSONPatch instance from JSON represention. This should be a
    /// top-level array with the json-patch operations.
    ///
    /// - Parameters:
    ///   - data: The json-patch document as data.
    public convenience init(data: Data) throws {
        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let jsonArray = jsonObject as? NSArray else {
            throw JSONError.invalidPatchFormat
        }
        try self.init(jsonArray: jsonArray)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        operations = try container.decode([JSONPatch.Operation].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(operations)
    }

    /// Returns a representation of the patch as UTF-8 encoded json.
    ///
    /// - Parameters:
    ///   - option: The writing options.
    /// - Returns: UTF-8 encoded json.
    public func data(options: JSONSerialization.WritingOptions = []) throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonArray, options: options)
    }

    /// Applies a json-patch to a target json document. Operations are applied
    /// sequentially in the order they appear in the operations array.
    /// Each operation in the sequence is applied to the target document;
    /// the resulting document becomes the target of the next operation.
    /// Evaluation continues until all operations are successfully applied
    /// or until an error condition is encountered. If you are going to apply
    /// the patch inplace then it can be more performant if the jsonObject
    /// has been parsing using the .mutableContainers reading option on
    /// JSONSerialization, as this will eliminate the need to make copies of sections
    /// of the json document while applying the patch.
    ///
    /// - Parameters:
    ///   - jsonObject: The target json document to patch the patch to.
    ///   - path: Can be used to apply the patch to sub-element within the json document.
    ///           If nil then the patch is applied directly to the jsonObject given.
    ///   - options: The options to be used when applying the patch.
    /// - Returns: A transformed json document with the patch applied.
    public func apply(to jsonObject: Any, options: [ApplyOption] = []) throws -> Any {
        var jsonDocument = try JSONElement(any: jsonObject)
        if options.contains(.applyOnCopy) {
            jsonDocument = try jsonDocument.copy()
        }
        try jsonDocument.apply(patch: self, options: options)
        return jsonDocument.rawValue
    }

    /// Applies a json-patch to a target json document. Operations are applied
    /// sequentially in the order they appear in the operations array.
    /// Each operation in the sequence is applied to the target document;
    /// the resulting document becomes the target of the next operation.
    /// Evaluation continues until all operations are successfully applied
    /// or until an error condition is encountered. If you are going to apply
    /// the patch inplace then it can be more performant if the jsonObject
    /// has been parsing using the .mutableContainers reading option on
    /// JSONSerialization, as this will eliminate the need to make copies of sections
    /// of the json document while applying the patch.
    ///
    /// - Parameters:
    ///   - jsonObject: The target json document to patch the patch to.
    ///   - path: Can be used to apply the patch to sub-element within the json document.
    ///           If nil then the patch is applied directly to the jsonObject given.
    ///   - inplace: If true the patch will be applied directly on to the json object
    ///              given, which is the most memory efficient option. However when applying
    ///              a patch inplace the result is not atomic, if an error occurs then the
    ///              json object may be left in a partial state. If false then a copy of
    ///              the json document is created and the patch applied to the copy.
    /// - Returns: A transformed json document with the patch applied.
    @available(*, deprecated, message: "Use apply(to: options:) instead")
    public func apply(to jsonObject: Any,
                      relativeTo path: JSONPointer? = nil,
                      inplace: Bool) throws -> Any {
        var options: [ApplyOption] = []
        if let path = path {
            options.append(.relative(to: path))
        }
        if !inplace {
            options.append(.applyOnCopy)
        }
        return try apply(to: jsonObject, options: options)
    }

    /// Applies a json-patch to a target json document represented as data (see apply(to jsonObject:)
    /// for more details. The given data will be parsed using JSONSerialization using the
    /// reading options. If the patch was successfully applied with no errors, the result will be
    /// serialized back to data with the writing options.
    ///
    /// - Parameters:
    ///   - data: A data representation of the json document to apply the patch to.
    ///   - readingOptions: The options given to JSONSerialization to parse the json data.
    ///   - writingOptions: The options given to JSONSerialization to write the result to data.
    ///   - applyingOptions: The options to be used when applying the patch.
    /// - Returns: The transformed json document as data.
    public func apply(to data: Data,
                      readingOptions: JSONSerialization.ReadingOptions = [.mutableContainers],
                      writingOptions: JSONSerialization.WritingOptions = [],
                      applyingOptions: [JSONPatch.ApplyOption] = []) throws -> Data {
        let jsonObject = try JSONSerialization.jsonObject(with: data,
                                                          options: readingOptions)
        var jsonElement = try JSONElement(any: jsonObject)
        try jsonElement.apply(patch: self, options: applyingOptions)
        let transformedData = try JSONSerialization.data(with: jsonElement,
                                                         options: writingOptions)
        return transformedData
    }

    /// Applies a json-patch to a target json document represented as data (see apply(to jsonObject:)
    /// for more details. The given data will be parsed using JSONSerialization using the
    /// reading options. If the patch was successfully applied with no errors, the result will be
    /// serialized back to data with the writing options.
    ///
    /// - Parameters:
    ///   - data: A data representation of the json document to apply the patch to.
    ///   - path: Can be used to apply the patch to sub-element within the json document.
    ///           If nil then the patch is applied directly to the whole json document.
    ///   - readingOptions: The options given to JSONSerialization to parse the json data.
    ///   - writingOptions: The options given to JSONSerialization to write the result to data.
    /// - Returns: The transformed json document as data.
    @available(*, deprecated, message: "Use apply(to: readingOptions, writingOptions, applyingOptions:)")
    public func apply(to data: Data,
                      relativeTo path: JSONPointer?,
                      readingOptions: JSONSerialization.ReadingOptions = [.mutableContainers],
                      writingOptions: JSONSerialization.WritingOptions = []) throws -> Data {
        var applyingOptions: [ApplyOption] = []
        if let path = path {
            applyingOptions.append(.relative(to: path))
        }
        return try apply(to: data,
                         readingOptions: readingOptions,
                         writingOptions: writingOptions,
                         applyingOptions: applyingOptions)
    }
}

extension JSONPatch.Operation {

    /// Initialize a json-operation from a JSON Object representation.
    /// If the operation is not recogized or is missing a required field
    /// then an error is thrown. Unrecogized extra fields are ignored.
    ///
    /// - Parameters:
    ///   - jsonObject: The json object representing the operation.
    ///   - index: The index this operation occurs at within the json-patch document.
    public init(jsonObject: NSDictionary, index: Int = 0) throws {
        guard let op = jsonObject["op"] as? String else {
            throw JSONError.missingRequiredPatchField(op: "", index: index, field: "op")
        }

        switch op {
        case "add":
            let path: String = try JSONPatch.Operation.val(jsonObject, "add", "path", index)
            let value: Any = try JSONPatch.Operation.val(jsonObject, "add", "value", index)
            let pointer = try JSONPointer(string: path)
            let element = try JSONElement(any: value)
            self = .add(path: pointer, value: element)
        case "remove":
            let path: String = try JSONPatch.Operation.val(jsonObject, "remove", "path", index)
            let pointer = try JSONPointer(string: path)
            self = .remove(path: pointer)
        case "replace":
            let path: String = try JSONPatch.Operation.val(jsonObject, "replace", "path", index)
            let value: Any = try JSONPatch.Operation.val(jsonObject, "replace", "value", index)
            let pointer = try JSONPointer(string: path)
            let element = try JSONElement(any: value)
            self = .replace(path: pointer, value: element)
        case "move":
            let from: String = try JSONPatch.Operation.val(jsonObject, "move", "from", index)
            let path: String = try JSONPatch.Operation.val(jsonObject, "move", "path", index)
            let fpointer = try JSONPointer(string: from)
            let ppointer = try JSONPointer(string: path)
            self = .move(from: fpointer, path: ppointer)
        case "copy":
            let from: String = try JSONPatch.Operation.val(jsonObject, "copy", "from", index)
            let path: String = try JSONPatch.Operation.val(jsonObject, "copy", "path", index)
            let fpointer = try JSONPointer(string: from)
            let ppointer = try JSONPointer(string: path)
            self = .copy(from: fpointer, path: ppointer)
        case "test":
            let path: String = try JSONPatch.Operation.val(jsonObject, "test", "path", index)
            let value: Any = try JSONPatch.Operation.val(jsonObject, "test", "value", index)
            let pointer = try JSONPointer(string: path)
            let element = try JSONElement(any: value)
            self = .test(path: pointer, value: element)
        default:
            throw JSONError.unknownPatchOperation
        }
    }

    private static func val<T>(_ jsonObject: NSDictionary,
                               _ op: String,
                               _ field: String,
                               _ index: Int) throws -> T {
        guard let value = jsonObject[field] as? T else {
            throw JSONError.missingRequiredPatchField(op: op, index: index, field: field)
        }
        return value
    }

    var jsonObject: NSDictionary {
        let dict = NSMutableDictionary()
        switch self {
        case let .add(path, value):
            dict["op"] = "add"
            dict["path"] = path.string
            dict["value"] = value.rawValue
        case let .remove(path):
            dict["op"] = "remove"
            dict["path"] = path.string
        case let .replace(path, value):
            dict["op"] = "replace"
            dict["path"] = path.string
            dict["value"] = value.rawValue
        case let .move(from, path):
            dict["op"] = "move"
            dict["from"] = from.string
            dict["path"] = path.string
        case let .copy(from, path):
            dict["op"] = "copy"
            dict["from"] = from.string
            dict["path"] = path.string
        case let .test(path, value):
            dict["op"] = "test"
            dict["path"] = path.string
            dict["value"] = value.rawValue
        }
        return dict
    }
}

extension JSONPatch.Operation: Equatable {
    public static func == (lhs: JSONPatch.Operation, rhs: JSONPatch.Operation) -> Bool {
        switch (lhs, rhs) {
        case let (.add(lpath, lvalue), .add(rpath, rvalue)),
             let (.replace(lpath, lvalue), .replace(rpath, rvalue)),
             let (.test(lpath, lvalue), .test(rpath, rvalue)):
            lpath == rpath && lvalue == rvalue
        case let (.remove(lpath), .remove(rpath)):
            lpath == rpath
        case let (.move(lfrom, lpath), .move(rfrom, rpath)),
             let (.copy(lfrom, lpath), .copy(rfrom, rpath)):
            lfrom == rfrom && lpath == rpath
        default:
            false
        }
    }
}

extension JSONPatch: Equatable {
    public static func == (lhs: JSONPatch, rhs: JSONPatch) -> Bool {
        lhs.operations == rhs.operations
    }
}

// MARK: - Patch Codable

public extension JSONPatch {
    /**
     Applies this patch on the specified Codable object

     The originated object won't be changed, a new object will be returned with this patch applied on it

     e.g.

     ```swift
     let patch = ... // get your JSONPatch from somewhere

     let patchedDevice = try! patch.applied(to: self.device)
     ```

     - parameter object: The object to apply the patch on

     - returns: A new object with the applied patch
     */
    func applied<T: Codable>(to object: T) throws -> T {
        let data = try JSONEncoder().encode(object)
        let patchedData = try apply(to: data)

        return try JSONDecoder().decode(T.self, from: patchedData)
    }

    /**
     Creates a patch from the source object to the target object

     - note:
     Generic use case would be that the `from` object is **an older** version of the `to` object.

     e.g.:

     ```swift
     self.device.state.isPowered = false
     var lastSent: Device = IOManager.send(self.device)

     self.device.state.isPowered = true

     let patch = try JSONPatch.createPatch(from: lastSent, to: self.device)

     // Patch will now be a patch that changes
     // the state's `isPowered` from false to true
     ```

     - parameter source: The source object
     - parameter target: The target object

     - returns: The JSONPatch to get from the source to the target object
     */
    static func createPatch<T: Codable>(from source: T, to target: T) throws -> JSONPatch {
        let sourceData = try JSONEncoder().encode(source)
        let targetData = try JSONEncoder().encode(target)

        return try JSONPatch(source: sourceData, target: targetData)
    }
}
