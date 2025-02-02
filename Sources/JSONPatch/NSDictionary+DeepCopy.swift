//
//  NSDictionary+DeepCopy.swift
//  JSONPatch
//
//  Created by Raymond Mccrae on 13/11/2018.
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

extension NSDictionary {

    func deepMutableCopy() -> NSMutableDictionary {
        let result = NSMutableDictionary()

        enumerateKeysAndObjects { key, value, _ in
            #if os(Linux)
            switch value {
            case let array as NSArray:
                result.setObject(array.deepMutableCopy(), forKey: key as! NSString)
            case let dict as NSDictionary:
                result.setObject(dict.deepMutableCopy(), forKey: key as! NSString)
            case let str as NSMutableString:
                result.setObject(str, forKey: key as! NSString)
            case let obj as NSObject:
                result.setObject(obj.copy(), forKey: key as! NSString)
            default:
                result.setObject(value, forKey: key as! NSString)
            }
            #else
            switch value {
            case let array as NSArray:
                result[key] = array.deepMutableCopy()
            case let dict as NSDictionary:
                result[key] = dict.deepMutableCopy()
            case let str as NSMutableString:
                result[key] = str
            case let obj as NSObject:
                result[key] = obj.copy()
            default:
                result[key] = value
            }
            #endif
        }

        return result
    }

}
