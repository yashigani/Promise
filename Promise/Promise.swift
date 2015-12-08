//
//  Promise.swift
//  Promise
//
//  Created by taiki on 11/28/15.
//  Copyright © 2015 yashigani. All rights reserved.
//

import Dispatch

internal enum State {
    case Pending
    case Fulfilled
    case Rejected
}

internal enum Result<T> {
    case Undefined
    case Value(T)
    case Error(ErrorType)
}

private let queue = dispatch_queue_create("promise.swift.worker", DISPATCH_QUEUE_CONCURRENT)

public final class Promise<T> {
    internal private(set) var state: State = .Pending {
        didSet {
            if case .Pending = oldValue {
                switch (state, result) {
                case (.Fulfilled, .Value(let value)):
                    resolve?(value)
                case (.Rejected, .Error(let error)):
                    reject?(error)
                default: ()
                }
            }
        }
    }
    internal private(set) var result: Result<T> = .Undefined
    private var resolve: (T -> Void)?
    private var reject: (ErrorType -> Void)?

    public init(_ executor: (T -> Void, ErrorType -> Void) -> Void) {
        dispatch_async(queue, {
            executor(self.onFulfilled, self.onRejected)
        })
    }

    public init(_ promise: Promise<T>) {
        if case .Pending = promise.state {
            let semaphore = dispatch_semaphore_create(0)
            promise.then { _ in
                dispatch_semaphore_signal(semaphore)
            }.`catch` { _ in
                dispatch_semaphore_signal(semaphore)
            }
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        }

        switch (promise.state, promise.result) {
        case (.Fulfilled, .Value(let value)):
            onFulfilled(value)
        case (.Rejected, .Error(let error)):
            onRejected(error)
        default:
            assertionFailure()
        }
    }

    public convenience init(@autoclosure(escaping) _ executor: () throws -> T) {
        self.init { resolve, reject in
            do {
                let v = try executor()
                resolve(v)
            } catch {
                reject(error)
            }
        }
    }

    private func onFulfilled(value: T) {
        if case .Pending = state {
            result = .Value(value)
            state = .Fulfilled
        }
    }

    private func onRejected(error: ErrorType) {
        if case .Pending = state {
            result = .Error(error)
            state = .Rejected
        }
    }

    private func then<U>(onFulfilled: T -> U, _ onRejected: (ErrorType -> Void)?) -> Promise<U> {
        return Promise<U> { _resolve, _reject in
            switch (self.state, self.result) {
            case (.Pending, _):
                let resolve = self.resolve
                self.resolve = {
                    resolve?($0)
                    _resolve(onFulfilled($0))
                }
                let reject = self.reject
                self.reject = {
                    reject?($0)
                    _reject($0)
                    onRejected?($0)
                }
            case (.Fulfilled, .Value(let value)):
                _resolve(onFulfilled(value))
            case (.Rejected, .Error(let error)):
                _reject(error)
                onRejected?(error)
            default:
                assertionFailure()
            }
        }
    }

    public func then<U>(onFulfilled: T -> U, _ onRejected: ErrorType -> Void) -> Promise<U> {
        return then(onFulfilled, .Some(onRejected))
    }

    public func then<U>(onFulfilled: T -> U) -> Promise<U> {
        return then(onFulfilled, nil)
    }

    public func `catch`(onRejected: ErrorType -> Void) -> Promise<T> {
        return then({ $0 }, onRejected)
    }

    // MARK: static

    public static func all(promises: [Promise<T>]) -> Promise<[T]> {
        return Promise<[T]> { (resolve: [T] -> Void, reject: ErrorType -> Void) in
            promises.forEach {
                $0.then({ v -> T in
                    if promises.filter({ $0.state == .Fulfilled}).count == promises.count {
                        let value: [T] = promises.flatMap {
                            if case .Value(let v) = $0.result {
                                return v
                            } else {
                                return nil
                            }
                        }
                        resolve(value)
                    }
                    return v
                }, {
                    reject($0)
                })
            }
        }
    }

    public static func race(promises: [Promise<T>]) -> Promise<T> {
        return Promise<T> { (resolve: T -> Void, reject: ErrorType -> Void) in
            promises.forEach({ $0.then({ v in resolve(v) }, reject) })
        }
    }

    public static func resolve(value: T) -> Promise<T> {
        let semaphore = dispatch_semaphore_create(0)
        let promise = Promise { resolve, _ in
            resolve(value)
            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        return promise
    }

    public static func reject(error: ErrorType) -> Promise<T> {
        let semaphore = dispatch_semaphore_create(0)
        let promise = Promise { _, reject in
            reject(error)
            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        return promise
    }

}

