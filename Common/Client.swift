//
//  Client.swift
//  Pilosa
//
//  Created by Benzi on 21/05/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

public struct Resource<T> {
    public let url: URL
    public typealias Loader = (Data, HTTPURLResponse) throws -> T
    public let parse: Loader
    
    public init(url: URL, parse: @escaping Loader) {
        self.url = url
        self.parse = parse
    }
}

typealias ReferenceResource = Resource<()>

struct Web {
    
    let cluster: Cluster
    let session: URLSession
    
    static func getDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent" : "swift-pilosa/1.0",
            "Content-Type": "application/x-protobuf",
            "Accept": "application/x-protobuf",
        ]
        return URLSession(configuration: config)
    }
    
    init(cluster: Cluster, session: URLSession = Web.getDefaultSession()) {
        self.cluster = cluster
        self.session = session
    }
    
    enum HttpMethod : String {
        case put = "PUT"
        case delete = "DELETE"
        case post = "POST"
        case get = "GET"
        case patch = "PATCH"
    }
    
    
    @discardableResult
    func request<T>(_ method: HttpMethod, _ resourceGenerator: (URI) -> Resource<T>, data: Data? = nil) -> Result<T> {
        if cluster.hosts.count == 0 { return .failure(PilosaError.noHosts) }
        let resource = resourceGenerator(cluster.host)
        return request(method, resource, data: data)
    }
    
    @discardableResult
    func request<T>(_ method: HttpMethod, _ resource: Resource<T>, data: Data? = nil) -> Result<T> {
        let s = DispatchSemaphore(value: 0)
        var result: Result<T>! = nil
        asyncRequest(method: method, resource: resource, data: data) {
            result = $0
            s.signal()
        }
        s.wait()
        if case .failure(let error as NSError) = result!, error.domain == "NSURLErrorDomain", error.code == -1004 {
            do {
                try cluster.remove(cluster.host)
            } catch {
                return .failure(error)
            }
        }
        return result
    }
    
    func asyncRequest<T>(method: HttpMethod, resource: Resource<T>, data: Data? = nil, completion: @escaping (Result<T>) -> () = { _ in }) {
        var req = URLRequest(url: resource.url)
        req.httpMethod = method.rawValue
        req.httpBody = data
        let task = session.dataTask(with: req) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
            }
            else if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode < 200 || response.statusCode >= 300 {
                    let error: PilosaError
                    switch String(data: data, encoding: .utf8) {
                    case .some(let content):
                        error = PilosaError(statusCode: response.statusCode, content: content)
                    default:
                        error = PilosaError.serverDecodeFailed(statusCode: response.statusCode, data: data)
                    }
                    completion(.failure(error))
                }
                else {
                    do {
                        try completion(.success(resource.parse(data, response)))
                    }
                    catch {
                        completion(.failure(error))
                    }
                }
            }
        }
        task.resume()
    }
}


extension String {
    func range(from range: NSRange) -> Range<String.Index>? {
        guard range.length > 0 else { return nil }
        let start = index(startIndex, offsetBy: range.location)
        let end = index(start, offsetBy: range.length)
        return start..<end
    }
}


public struct URI : Equatable {
    let scheme: String
    let host: String
    let port: Int
    
    static let regex = try! NSRegularExpression(pattern: "^(([+a-z]+)://)?([0-9a-z.-]+)?(:([0-9]+))?$", options: [])
    
    public init?(address: String) {
        
        let matches = URI.regex.matches(
            in: address,
            options: [],
            range: .init(location: 0, length: address.characters.count)
        )
        
        if matches.count == 0 {
            return nil
        }
        
        let match = matches[0]
        
        func extract(_ i: Int) -> String? {
            guard let range = address.range(from: match.rangeAt(i))
                else { return nil }
            return address.substring(with: range)
        }
        
        var scheme = "http"
        if let s = extract(2) {
            if let plus = s.characters.index(of: "+") {
                scheme = String.init(s.characters[s.characters.startIndex..<plus])
            }
            else {
                scheme = s
            }
        }
        
        self.scheme = scheme
        self.host = extract(3) ?? "localhost"
        self.port = Int(extract(5) ?? "10101") ?? 10101
    }
    
    public init(scheme: String = "http", host: String = "localhost", port: Int = 10101) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }
    
    var normalized: String {
        return "\(scheme)://\(host):\(port)"
    }
    
    var url: URL {
        return URL(string: normalized)!
    }
    
    func endpoint(_ path: String) -> URL {
        return url.appendingPathComponent(path)
    }
}

public func ==(lhs: URI, rhs: URI) -> Bool {
    return lhs.normalized == rhs.normalized
}


protocol StringProtocol { }
extension String : StringProtocol { }
extension Dictionary where Key: StringProtocol, Value: Any {
    var jsonData: Data {
        return try! JSONSerialization.data(withJSONObject: self, options: [])
    }
    var jsonString: String {
        return String(data: jsonData, encoding: .utf8)!
    }
}


public class Cluster {
    var hosts: [URI]
    var nextHostIndex: Int
    var host: URI {
        return hosts[nextHostIndex]
    }
    public init(hosts: [URI]) {
        self.hosts = hosts
        self.nextHostIndex = 0
    }
    public func add(_ host: URI) {
        if hosts.contains(host) { return }
        hosts.append(host)
    }
    func remove(_ host: URI) throws {
        if let i = hosts.index(of: host) {
            hosts.remove(at: i)
        }
        if hosts.count == 0 { throw PilosaError.noHosts }
    }
    func nextHost() -> URI {
        nextHostIndex = (nextHostIndex + 1) % hosts.count
        return host
    }
}

public class Client {
    
    let web: Web
    
    public init(_ uri: URI = URI()) {
        self.web = Web(cluster: Cluster(hosts: [uri]))
    }
    
    public init(_ cluster: Cluster) {
        self.web = Web(cluster: cluster)
    }
    
    public func status() -> Result<String>  {
        let _status:(URI)->Resource<String> = {
            return Resource(url: $0.endpoint("/status")) { data, _ in
                return String(data: data, encoding: .utf8)!
            }
        }
        return web.request(.get, _status)
    }
    
    
    
    public func create(_ index: Index) -> OperationResult {
        let options: [String: Any] = ["options": ["columnLabel" : index.columnLabel]]
        return web
            .request(.post, index.resource, data: options.jsonData)
            .andIf(index.timeQuantum != .none) {
                let payload:[String: Any] = ["timeQuantum" : index.timeQuantum.rawValue]
                return web.request(.patch, index.timeQuantumResource, data: payload.jsonData)
        }
    }
    
    public func ensure(_ index: Index) {
        _ = create(index)
    }
    
    public func delete(_ index: Index) {
        web.request(.delete, index.resource)
    }
    
    public func create(_ frame: Frame) -> OperationResult {
        return web.request(.post, frame.resource, data: frame.options.jsonData)
    }
    
    public func delete(_ frame: Frame) -> OperationResult {
        return web.request(.delete, frame.resource)
    }
    
    public func ensure(_ frame: Frame) {
        _ = create(frame)
    }
}



extension Client {
    
    @discardableResult
    public func query(_ builder: PQLQueryBuilder, columns: Bool = false, timeQuantum: TimeQuantum = .none) -> Result<QueryResponse> {
        return query(builder.query(), columns: columns, timeQuantum: timeQuantum)
    }
    
    @discardableResult
    public func query(_ query: PQLQuery, columns: Bool = false, timeQuantum: TimeQuantum = .none) -> Result<QueryResponse> {
        let request = Internal_QueryRequest.with {
            $0.query = query.serialize()
            $0.columnAttrs = columns
            $0.quantum = timeQuantum.rawValue
        }
        let queryResource: (URI) -> Resource<QueryResponse> = { uri in
            return Resource(url: uri.endpoint("/index/\(query.index.name)/query"), parse: { data, response in
                return try QueryResponse(response: Internal_QueryResponse(serializedData: data))
            })
        }
        do {
            return try web.request(.post, queryResource, data: request.serializedData())
        }
        catch {
            return .failure(error)
        }
    }
}
