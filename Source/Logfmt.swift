//
//  Logfmt.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 06/10/2016.
//
//

import Foundation

// public class Logfmt {

//     enum State: Int {
//         case garbage
//         case key
//         case equal
//         case iValue
//         case qValue
//     }

//     static public func isNumeric(str: String) -> Double? {
//         return Double(str)
//     }

//     static public func isInteger(str: String) -> Int? {
//         return Int(str)
//     }

//     static public func parse(line: String) -> [String: Any] {
//         var output: [String: Any] = [:]
//         var key = ""
//         var value: Any = ""
//         var escaped = false
//         var state: State = .garbage

//         var i = 0

//         for (_, character) in line.utf8.enumerated() {
//             i = i + 1

//             if state == .garbage {
//                 if character.hashValue > " ".utf8.first!.hashValue && String(character) != "\"" && String(character) != "=" {
//                     key = String(character)
//                     state = .key
//                 }
//                 continue
//             }

//             if state == .key {
//                 if character.hashValue > " ".utf8.first!.hashValue && String(character) != "\"" && String(character) != "=" {
//                     state = .key
//                     key.append(String(character))
//                 } else if String(character) == "=" {
//                     output[key.trimmingCharacters(in: .whitespaces)] = true
//                     state = .equal
//                 } else {
//                     output[key.trimmingCharacters(in: .whitespaces)] = true
//                     state = .garbage
//                 }

//                 if i >= line.characters.count {
//                     output[key.trimmingCharacters(in: .whitespaces)] = true
//                 }
//                 continue
//             }

//             if state == .equal {
//                 if character.hashValue > " ".utf8.first!.hashValue && String(character) != "\"" && String(character) != "=" {
//                     value = character
//                     state = .iValue
//                 } else if String(character) == "\"" {
//                     value = ""
//                     escaped = false
//                     state = .qValue
//                 } else {
//                     state = .garbage
//                 }
//                 if i >= line.characters.count {
//                     if let strVal = value as? String {
//                         if let int = isInteger(str: strVal) {
//                             value = int
//                         } else if let num = isNumeric(str: strVal) {
//                             value = num
//                         }
//                         output[key.trimmingCharacters(in: .whitespaces)] = strVal
//                     } else {
//                         output[key.trimmingCharacters(in: .whitespaces)] = true
//                     }
//                 }
//                 continue
//             }

//             if state == .iValue {
//                 if character.hashValue > " ".utf8.first!.hashValue && String(character) != "\"" && String(character) != "=" {
//                     let tempVal = (value as! String)
//                     if let int = isInteger(str: tempVal) {
//                         value = int
//                     } else if let num = isNumeric(str: tempVal) {
//                         value = num
//                     }
//                     output[key.trimmingCharacters(in: .whitespaces)] = value
//                     state = .garbage
//                 } else {
//                     var tempVal = (value as! String)
//                     tempVal.append(String(character))
//                     value = tempVal
//                 }
//                 if i >= line.characters.count {
//                     let tempVal = (value as! String)
//                     if let int = isInteger(str: tempVal) {
//                         value = int
//                     } else if let num = isNumeric(str: tempVal) {
//                         value = num
//                     }
//                     output[key.trimmingCharacters(in: .whitespaces)] = value
//                 }
//                 continue
//             }

//             if state == .qValue {
//                 if String(character) == "\\" {
//                     escaped = true
//                     var tempVal = (value as! String)
//                     tempVal.append("\\")
//                     value = tempVal
//                 } else if String(character) == "\"" {
//                     if escaped {
//                         escaped = false
//                         var tempVal = (value as! String)
//                         tempVal.append(String(character))
//                         value = tempVal
//                         continue
//                     }
//                     output[key.trimmingCharacters(in: .whitespaces)] = value
//                     state = .garbage
//                 } else {
//                     escaped = false
//                     var tempVal = (value as! String)
//                     tempVal.append(String(character))
//                     value = tempVal
//                 }
//                 continue
//             }
//         }

//         return output
//     }
// }
