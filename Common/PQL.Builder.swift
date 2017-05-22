//
//  PQL.Builder.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

public class PQLQueryBuilder : PQLQuerySource {
    
    enum PQLOperation {
        case union
        case difference
        case intersect
    }
    
    let operation: PQLOperation
    var queries = [PQLQuery]()
    let index: Index
    
    static func intersect(_ index: Index) -> PQLQueryBuilder { return .init(.intersect, index) }
    static func union(_ index: Index) -> PQLQueryBuilder { return .init(.union, index) }
    static func difference(_ index: Index) -> PQLQueryBuilder { return .init(.difference, index) }
    
    init(_ operation: PQLOperation, _ index: Index) {
        self.operation = operation
        self.index = index
    }
    
    func add(_ query: PQLQuery) {
        assert(query.index.name == index.name, "Cannot create query across indices")
        queries.append(query)
    }
    
    func serialize() -> String {
        let queries = self.queries.map { $0.serialize() }.joined(separator: ", ")
        switch operation {
        case .union: return "Union(\(queries))"
        case .intersect: return "Intersect(\(queries))"
        case .difference: return "Difference(\(queries))"
        }
    }
    
    public func query() -> PQLQuery {
        return PQLQuery(pql: serialize(), index: index)
    }
    
    public func count() -> PQLQuery {
        return PQLQuery(pql: "Count(\(serialize()))", index: index)
    }
    
}


extension PQLQuery {

    public func union(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, builder: .union(self.index))
    }
    
    public func intersect(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, builder: .intersect(self.index))
    }
    
    public func difference(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, builder: .difference(self.index))
    }
    
    func merge(_ other: PQLQuery, builder: PQLQueryBuilder) -> PQLQueryBuilder {
        builder.add(self)
        builder.add(other)
        return builder
    }
    
    public func union(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, on: .union, newBuilder: PQLQueryBuilder.union(self.index))
    }

    public func intersect(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, on: .intersect, newBuilder: PQLQueryBuilder.intersect(self.index))
    }

    public func difference(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, on: .difference, newBuilder: PQLQueryBuilder.difference(self.index))
    }

    func merge(_ other: PQLQueryBuilder, on operation: PQLQueryBuilder.PQLOperation, newBuilder: @autoclosure ()->PQLQueryBuilder) -> PQLQueryBuilder {
        if other.operation == operation {
            if operation == .difference {
                other.queries.insert(self, at: 0)
            }
            else {
                other.add(self)
            }
            return other
        }
        else {
            let builder = newBuilder()
            builder.add(self)
            builder.add(other.query())
            return builder
        }
    }
}


extension PQLQueryBuilder {
    
    public func union(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, on: .union, newBuilder: PQLQueryBuilder.union(self.index))
    }

    public func intersect(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, on: .intersect, newBuilder: PQLQueryBuilder.intersect(self.index))
    }

    public func difference(_ other: PQLQuery) -> PQLQueryBuilder {
        return merge(other, on: .difference, newBuilder: PQLQueryBuilder.difference(self.index))
    }

    func merge(_ other: PQLQuery, on operation: PQLQueryBuilder.PQLOperation, newBuilder: @autoclosure ()->PQLQueryBuilder) -> PQLQueryBuilder {
        if self.operation == operation {
            add(other)
            return self
        }
        else {
            let builder = newBuilder()
            builder.add(self.query())
            builder.add(other)
            return builder
        }
    }
    
    public func union(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, newBuilder: .union(index.self))
    }
    
    public func intersect(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, newBuilder: .intersect(index.self))
    }
    
    public func difference(_ other: PQLQueryBuilder) -> PQLQueryBuilder {
        return merge(other, newBuilder: .difference(index.self))
    }
    
    func merge(_ other: PQLQueryBuilder, newBuilder: @autoclosure ()->PQLQueryBuilder) -> PQLQueryBuilder {
        if self.operation == other.operation {
            if self.operation == .difference {
                other.queries.insert(contentsOf: queries, at: 0)
            }
            else {
                other.queries.append(contentsOf: queries)
            }
            return other
        }
        else {
            let builder = newBuilder()
            builder.add(self.query())
            builder.add(other.query())
            return builder
        }
    }
    
}

//func _continueOperation(
//    _ builder: PQLQueryBuilder,
//    _ rhs: PQLQuery,
//    _ rhsTerm: Bool,
//    _ operation: PQLQueryBuilder.PQLOperation,
//    _ createNewBuilder: @autoclosure ()->PQLQueryBuilder) -> PQLQueryBuilder {
//    if builder.operation == operation {
//        builder.add(rhs)
//        return builder
//    }
//    else {
//        let newBuilder = createNewBuilder()
//        if rhsTerm {
//            newBuilder.add(PQLQuery(pql: builder.serialize(), index: builder.index))
//            newBuilder.add(rhs)
//        }
//        else {
//            newBuilder.add(rhs)
//            newBuilder.add(PQLQuery(pql: builder.serialize(), index: builder.index))
//        }
//        return newBuilder
//    }
//}
//
//func _combineBuilders(
//    _ lhs: PQLQueryBuilder,
//    _ rhs: PQLQueryBuilder,
//    _ operation: PQLQueryBuilder.PQLOperation,
//    _ createNewBuilder: @autoclosure ()->PQLQueryBuilder) -> PQLQueryBuilder {
//    switch (lhs.operation, rhs.operation) {
//    case (operation, operation):
//        lhs.queries.append(contentsOf: rhs.queries)
//        return lhs
//    default:
//        let newBuilder = createNewBuilder()
//        newBuilder.add(PQLQuery(pql: lhs.serialize(), index: lhs.index))
//        newBuilder.add(PQLQuery(pql: rhs.serialize(), index: rhs.index))
//        return newBuilder
//    }
//}
//
//
//
//infix operator &>
//
//public func &> (lhs: PQLQuery, rhs: PQLQuery) -> PQLQueryBuilder {
//    let builder = PQLQueryBuilder.union(lhs.index)
//    builder.add(lhs)
//    builder.add(rhs)
//    return builder
//}
//
//public func &> (builder: PQLQueryBuilder, rhs: PQLQuery) -> PQLQueryBuilder {
//    return _continueOperation(builder, rhs, true, .union, PQLQueryBuilder.union(builder.index))
//}
//
//public func &> (lhs: PQLQuery, builder: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _continueOperation(builder, lhs, false, .union, PQLQueryBuilder.union(builder.index))
//}
//
//public func &> (lhs: PQLQueryBuilder, rhs: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _combineBuilders(lhs, rhs, .union, PQLQueryBuilder.union(lhs.index))
//}
//
//
//infix operator |>
//
//public func |> (lhs: PQLQuery, rhs: PQLQuery) -> PQLQueryBuilder {
//    let builder = PQLQueryBuilder.intersect(lhs.index)
//    builder.add(lhs)
//    builder.add(rhs)
//    return builder
//}
//
//public func |> (builder: PQLQueryBuilder, rhs: PQLQuery) -> PQLQueryBuilder {
//    return _continueOperation(builder, rhs, true, .intersect, PQLQueryBuilder.intersect(builder.index))
//}
//
//public func |> (lhs: PQLQuery, builder: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _continueOperation(builder, lhs, false, .intersect, PQLQueryBuilder.intersect(builder.index))
//}
//
//public func |> (lhs: PQLQueryBuilder, rhs: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _combineBuilders(lhs, rhs, .intersect, PQLQueryBuilder.intersect(lhs.index))
//}
//
//
//
//infix operator =>
//
//public func  => (lhs: PQLQuery, rhs: PQLQuery) -> PQLQueryBuilder {
//    let builder = PQLQueryBuilder.difference(lhs.index)
//    builder.add(lhs)
//    builder.add(rhs)
//    return builder
//}
//
//public func => (builder: PQLQueryBuilder, rhs: PQLQuery) -> PQLQueryBuilder {
//    return _continueOperation(builder, rhs, true, .difference, PQLQueryBuilder.difference(builder.index))
//}
//
//public func => (lhs: PQLQuery, builder: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _continueOperation(builder, lhs, false, .difference, PQLQueryBuilder.difference(builder.index))
//}
//
//public func => (lhs: PQLQueryBuilder, rhs: PQLQueryBuilder) -> PQLQueryBuilder {
//    return _combineBuilders(lhs, rhs, .difference, PQLQueryBuilder.difference(lhs.index))
//}



