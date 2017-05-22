//
//  PQL.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

protocol PQLQuerySource {
    var index: Index { get }
    func serialize() -> String
}


public struct PQLQuery : PQLQuerySource {
    public let pql: String
    let index: Index
    func serialize() -> String {
        return pql
    }
}

public struct PQLBatchQuery {
    var queries: [PQLQuery]
    public init() {
        self.queries = []
    }
    public mutating func add(_ query: PQLQuery) {
        queries.append(query)
    }
    func serialize() -> String {
        return queries.map { $0.serialize() }.joined(separator: " ")
    }
    func query() -> PQLQuery {
        assert(queries.count > 0, "Batched query must contain at least one query")
        return PQLQuery(pql: serialize(), index: queries[0].index)
    }
}
