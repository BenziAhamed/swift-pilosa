//
//  Validator.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

struct Validator {
    static let indexNameRegex = try! NSRegularExpression(pattern: "^[a-z0-9_-]+$", options: [])
    static let frameNameRegex = try! NSRegularExpression(pattern: "^[a-z0-9][.a-z0-9_-]*$", options: [])
    static let labelRegex = try! NSRegularExpression(pattern: "^[a-zA-Z][a-zA-Z0-9_]*$", options: [])
    static let maxIndexNameLength = 64
    static let maxFrameNameLength = 64
    static let maxLabelLength = 64
    
    static func validate(frameName: String) throws {
        if !isValid(name: frameName, regex: frameNameRegex, maxLength: maxFrameNameLength) {
            throw PilosaError.validationError("Invalid frame name \(frameName)")
        }
    }
    
    static func validate(indexName: String) throws {
        if !isValid(name: indexName, regex: indexNameRegex, maxLength: maxIndexNameLength) {
            throw PilosaError.validationError("Invalid index name \(indexName)")
        }
    }
    
    static func validate(label: String) throws {
        if !isValid(name: label, regex: labelRegex, maxLength: maxLabelLength) {
            throw PilosaError.validationError("Invalid label \(label)")
        }
    }
    
    static func isValid(name: String, regex: NSRegularExpression, maxLength: Int) -> Bool {
        let count = name.characters.count
        if count > maxLength { return false }
        if regex.numberOfMatches(in: name, options: .anchored, range: .init(location: 0, length: count)) != 1 { return false }
        return true
    }
}

