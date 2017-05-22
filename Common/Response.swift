//
//  Response.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

func getAttributesDict(items: [Internal_Attr]) throws -> [String: Any] {
    var d = [String: Any]()
    for attr in items {
        switch attr.type {
        case 1: d[attr.key] = attr.stringValue
        case 2: d[attr.key] = attr.intValue
        case 3: d[attr.key] = attr.boolValue
        case 4: d[attr.key] = attr.floatValue
        default:
            throw PilosaError.invalidAttributeType(code: attr.type)
        }
    }
    return d
}

public struct BitmapResult {
    public let bits: [UInt64]
    public let attributes: [String: Any]
    
    init(internal bitmap: Internal_Bitmap) throws {
        self.bits = bitmap.bits
        self.attributes = try getAttributesDict(items: bitmap.attrs)
    }
}

public struct CountResultItem {
    public let id: UInt64
    public let count: UInt64
    init(pair: Internal_Pair) {
        self.id = pair.key
        self.count = pair.count
    }
}

public struct QueryResult {
    public let count: UInt64
    public let bitmap: BitmapResult
    public let countItems: [CountResultItem]
    
    init(result: Internal_QueryResult) throws {
        count = result.n
        bitmap = try BitmapResult(internal: result.bitmap)
        countItems = result.pairs.map(CountResultItem.init)
    }
}

public struct ColumnItem {
    public let id: UInt64
    public let attributes: [String: Any]
    
    init(columnAttributeSet: Internal_ColumnAttrSet) throws {
        id = columnAttributeSet.id
        attributes = try getAttributesDict(items: columnAttributeSet.attrs)
    }
}

public struct QueryResponse {
    
    public let results: [QueryResult]
    public let columns: [ColumnItem]
    public let error: String
    
    init(response: Internal_QueryResponse) throws {
        results = try response.results.map(QueryResult.init)
        columns = try response.columnAttrSets.map(ColumnItem.init)
        error = response.err
    }
}
