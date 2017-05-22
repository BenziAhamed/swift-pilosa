//
//  Result.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

public enum Result<T> {
    case success(T)
    case failure(Error)
}

extension Result : CustomStringConvertible {
    public var description: String {
        switch self {
        case .success(let item): return "✅ \(item)"
        case .failure(let error): return "❌ \(error)"
        }
    }
}

extension Result {
    
    func andIf(_ condition: @autoclosure ()->Bool, then next: ()->Result<T>) -> Result<T> {
        if condition() {
            return self.then(next)
        }
        return self
    }
    
    func then(_ next: () -> Result<T>) -> Result<T> {
        switch self {
        case .failure: return self
        case .success: return next()
        }
    }
}

public typealias OperationResult = Result<()>
