//
//  Errors.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

public enum PilosaError : Error {
    case indexAlreadyExists
    case frameAlreadyExists
    case validationError(String)
    case noHosts
    case error(String)
    case serverDecodeFailed(statusCode: Int, data: Data)
    case serverError(statusCode: Int, content: String)
    case invalidAttributeType(code: UInt64)
    init(statusCode: Int, content: String) {
        switch content {
        case "index already exists\n":
            self = .indexAlreadyExists
        case "frame already exists\n":
            self = .frameAlreadyExists
        default:
            self = .serverError(statusCode: statusCode, content: content)
        }
    }
}
