//
//  FoundationTasks.swift
//  Deferred
//
//  Created by Zachary Waldowski on 1/10/16.
//  Copyright © 2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Foundation

extension NSURLSession {

    private func beginTask<URLTask: NSURLSessionTask>(@noescape with factoryWithCompletion: ((NSData?, NSURLResponse?, NSError?) -> Void) -> URLTask, @noescape by configuring: URLTask throws -> Void, @autoclosure(escaping) needsDefaultData: () -> Bool) rethrows -> Task<(NSData, NSURLResponse)> {
        let deferred = Deferred<Task<(NSData, NSURLResponse)>.Result>()
        let task = factoryWithCompletion { (data, response, error) in
            if let error = error {
                deferred.fail(error)
            } else if let data = data, let response = response {
                deferred.succeed((data, response))
            } else if let response = response where needsDefaultData() {
                deferred.succeed((NSData(), response))
            } else {
                deferred.fail(NSURLError.BadServerResponse)
            }
        }
        try configuring(task)
        defer { task.resume() }
        return Task(deferred, cancellation: task.cancel)
    }

    // MARK: - Sending and Recieving Small Data

    /// Returns the data from the contents of a URL, based on `request`, as a
    /// future.
    ///
    /// The session bypasses delegate methods for result delivery. Delegate
    /// methods for handling authentication challenges are still called.
    ///
    /// - parameter request: Object that provides the URL, body data, and so on.
    /// - parameter configure: An optional callback for setting properties on
    ///   the URL task.
    public func beginDataTask(with request: NSURLRequest, @noescape by configuring: NSURLSessionDataTask throws -> Void) rethrows -> Task<(NSData, NSURLResponse)> {
        return try beginTask(with: { completionHandler in
            dataTaskWithRequest(request, completionHandler: completionHandler)
        }, by: configuring, needsDefaultData: {
            switch request.HTTPMethod {
            case "GET"?, "POST"?, "PATCH"?:
                return false
            default:
                return true
            }
        }())
    }

    /// Returns the data from the contents of a URL, based on `request`, as a
    /// future.
    public func beginDataTask(request request: NSURLRequest) -> Task<(NSData, NSURLResponse)> {
        return beginDataTask(with: request) { _ in }
    }

    // MARK: - Uploading Data

    /// Returns the data from uploading the optional `bodyData` as a future.
    ///
    /// The session bypasses delegate methods for result delivery. Delegate
    /// methods for handling authentication challenges are still called.
    ///
    /// - parameter request: Object that provides the URL, body data, and so on.
    ///   The body stream and body data are ignored.
    /// - parameter configure: An optional callback for setting properties on
    ///   the URL task.
    public func beginUploadTask(with request: NSURLRequest, from bodyData: NSData? = nil, @noescape by configuring: NSURLSessionUploadTask throws -> Void) rethrows -> Task<(NSData, NSURLResponse)> {
        return try beginTask(with: { completionHandler in
            uploadTaskWithRequest(request, fromData: bodyData, completionHandler: completionHandler)
        }, by: configuring, needsDefaultData: true)
    }

    /// Returns the data from uploading the optional `bodyData` as a future.
    public func beginUploadTask(with request: NSURLRequest, from bodyData: NSData? = nil) -> Task<(NSData, NSURLResponse)> {
        return beginUploadTask(with: request, from: bodyData) { _ in }
    }

    /// Returns the data from uploading the file at `fileURL` as a future.
    ///
    /// The session bypasses delegate methods for result delivery. Delegate
    /// methods for handling authentication challenges are still called.
    ///
    /// - parameter request: Object that provides the URL, body data, and so on.
    ///   The body stream and body data are ignored.
    /// - parameter configure: An optional callback for setting properties on
    ///   the URL task.
    public func beginUploadTask(with request: NSURLRequest, fromFile fileURL: NSURL, @noescape by configuring: NSURLSessionUploadTask throws -> Void) rethrows -> Task<(NSData, NSURLResponse)> {
        return try beginTask(with: { completionHandler in
            uploadTaskWithRequest(request, fromFile: fileURL, completionHandler: completionHandler)
        }, by: configuring, needsDefaultData: true)
    }

    /// Returns the data from uploading the file at `fileURL` as a future.
    public func beginUploadTask(with request: NSURLRequest, fromFile fileURL: NSURL) -> Task<(NSData, NSURLResponse)> {
        return beginUploadTask(with: request, fromFile: fileURL) { _ in }
    }

}
