//
//  orm.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

public enum TimeQuantum : String {
    case none = ""
    case year = "Y"
    case month = "M"
    case day = "D"
    case hour = "H"
    case yearMonth = "YM"
    case monthDay = "MD"
    case dayHour = "DH"
    case yearMonthDay = "YMD"
    case monthDayHour = "MDH"
    case yearMonthDayHour = "YMDH"
}

public enum CacheType : String {
    case standard
    case lru = "lru"
    case ranked = "ranked"
}

public struct Index {
    public let name: String
    public let columnLabel: String
    public let timeQuantum: TimeQuantum
    public init(name: String, columnLabel: String = "columnID", timeQuantum: TimeQuantum = .none) throws {
        try Validator.validate(indexName: name)
        self.name = name
        self.columnLabel = columnLabel
        self.timeQuantum = timeQuantum
    }
}

public struct Frame {
    public let name: String
    public let index: Index
    public let timeQuantum: TimeQuantum
    public let inverseEnabled: Bool
    public let cacheType: CacheType
    public let cacheSize: Int
    public let rowLabel: String
    public init(index: Index, name: String, timeQuantum: TimeQuantum = .none, inverseEnabled: Bool = false, cacheType: CacheType = .standard, cacheSize: Int = 0, rowLabel: String = "rowID") throws {
        try Validator.validate(frameName: name)
        try Validator.validate(label: rowLabel)
        self.index = index
        self.name = name
        self.timeQuantum = timeQuantum
        self.inverseEnabled = inverseEnabled
        self.cacheType = cacheType
        self.cacheSize = cacheSize
        self.rowLabel = rowLabel
    }
    
    var options: [String: Any] {
        var data: [String: Any] = [ "rowLabel": rowLabel ]
        if inverseEnabled { data["inverseEnabled"] = true }
        if timeQuantum != .none { data["timeQuantum"] = timeQuantum.rawValue }
        if cacheType != .standard { data["cacheType"] = cacheType.rawValue }
        if cacheSize > 0  { data["cacheSize"] = cacheSize }
        return [ "options" : data ]
    }
}

extension Index {
    public func frame(name: String, timeQuantum: TimeQuantum = .none, inverseEnabled: Bool = false, cacheType: CacheType = .standard, cacheSize: Int = 0, rowLabel: String = "rowID") throws -> Frame {
        return try Frame(
            index: self,
            name: name,
            timeQuantum: timeQuantum,
            inverseEnabled: inverseEnabled,
            cacheType: cacheType,
            cacheSize: cacheSize,
            rowLabel: rowLabel
        )
    }
    func resource(_ api: URI) -> ReferenceResource {
        return Resource(url: api.endpoint("/index/\(name)"), parse: { _ in })
    }
    func timeQuantumResource(_ api: URI) -> ReferenceResource {
        return Resource(url: api.endpoint("/index/\(name)/time-quantum"), parse: { _ in })
    }
    
    public func batch(_ queries: PQLQuery...) -> PQLQuery {
        var b = PQLBatchQuery()
        queries.forEach { b.add($0) }
        return b.query()
    }
    
    public func union(_ queries: PQLQuery...) -> PQLQuery {
        let b = PQLQueryBuilder.union(self)
        queries.forEach { b.add($0) }
        return b.query()
    }
    
    public func intersect(_ queries: PQLQuery...) -> PQLQuery {
        let b = PQLQueryBuilder.intersect(self)
        queries.forEach { b.add($0) }
        return b.query()
    }
    
    public func difference(_ queries: PQLQuery...) -> PQLQuery {
        let b = PQLQueryBuilder.difference(self)
        queries.forEach { b.add($0) }
        return b.query()
    }
    
    public func count(_ bitmap: PQLQuery) -> PQLQuery {
        return PQLQuery(pql: "Count(\(bitmap.pql))", index: self)
    }
    
    public func raw(pql: String) -> PQLQuery {
        return PQLQuery(pql: pql, index: self)
    }
    
    public func setColumnAttributes(_ columnId: UInt64, _ attributes: [String: Any]) throws -> PQLQuery {
        let attributeText = try createAttributeText(attributes)
        return PQLQuery(pql: "SetRowAttrs(\(columnLabel)=\(columnId), frame='\(name)', \(attributeText))", index: self)
    }
}

extension Frame {
    func resource(_ api: URI) -> ReferenceResource {
        return Resource(url: api.endpoint("/index/\(index.name)/frame/\(name)"), parse: { _ in })
    }
}


func createAttributeText(_ dict: [String: Any]) throws -> String {
    var segments = [String]()
    for (key, value) in dict {
        try Validator.validate(label: key)
        if !JSONSerialization.isValidJSONObject(value) {
            throw PilosaError.error("Invalid value for attribute")
        }
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: []),
            let valueText = String(data: data, encoding: .utf8)
            else { throw PilosaError.error("Unable to encode value for attribute as JSON") }
        
        segments.append("\(key)=\(valueText)")
    }
    return segments.sorted().joined(separator: ", ")
}

extension Frame {
    
    public func bitmap(_ rowId: UInt64) -> PQLQuery {
        return PQLQuery(pql: "Bitmap(\(rowLabel)=\(rowId), frame=\"\(name)\")", index: self.index)
    }
    
    public func inverseBitmap(_ columnId: UInt64) throws -> PQLQuery {
        if !inverseEnabled {
            throw PilosaError.error("Inverse bitmaps support was not enabled for this frame")
        }
        return PQLQuery(pql: "Bitmap(\(index.columnLabel)=\(columnId), frame='\(name)')", index: index)
    }
    
    public func setRowAttributes(_ rowId: UInt64, _ attributes: [String: Any]) throws -> PQLQuery {
        let attributeText = try createAttributeText(attributes)
        return PQLQuery(pql: "SetRowAttrs(\(rowLabel)=\(rowId), frame='\(name)', \(attributeText))", index: index)
    }
    
    public func range(_ rowId: UInt64, _ start: Date, _ end: Date) -> PQLQuery {
        return PQLQuery(
            pql: "Range(\(rowLabel)=\(rowId), frame='\(name)', start='\(start.pilosaFormat)', end='\(end.pilosaFormat)')",
            index: index
        )
    }
    
    public func topN(n: UInt64, bitmap: PQLQuery? = nil, field: String? = nil, filters: [Any]? = nil) throws -> PQLQuery {
        let pql: String
        if let bitmap = bitmap, let field = field, let filters = filters {
            try Validator.validate(label: field)
            guard let data = try? JSONSerialization.data(withJSONObject: filters, options: []),
                let filterText = String(data: data, encoding: .utf8) else {
                    throw PilosaError.error("Unable to create JSON for filters")
            }
            pql = "TopN(\(bitmap.serialize()), frame='\(name)', n=\(n), field='\(field)', \(filterText))"
        }
        else if let bitmap = bitmap {
            pql = "TopN(\(bitmap.serialize()), frame='\(name)', n=\(n))"
        }
        else {
            pql = "TopN(frame='\(name)', n=\(n))"
        }
        return PQLQuery(pql: pql, index: index)
    }
    
    public subscript(_ rowId: UInt64) -> PQLQuery {
        get { return bitmap(rowId) }
    }
    
    public func setBit(_ rowId: UInt64, _ columnID: UInt64, timestamp: Date? = nil) -> PQLQuery {
        var ts = ""
        if let time = timestamp {
            ts = ", timestamp='\(time.pilosaFormat)'"
        }
        return PQLQuery(pql: "SetBit(\(rowLabel)=\(rowId), frame='\(name)', \(index.columnLabel)=\(columnID)\(ts))", index: index)
    }
    
    public func clearBit(_ rowId: UInt64, _ columnID: UInt64) -> PQLQuery {
        return PQLQuery(pql: "ClearBit(\(rowLabel)=\(rowId), frame='\(name)', \(index.columnLabel)=\(columnID))", index: index)
    }
}


extension Date {
    var pilosaFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.string(from: self)
    }
}
