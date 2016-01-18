//
//  MainStore.swift
//  SwiftFlow
//
//  Created by Benjamin Encz on 11/11/15.
//  Copyright © 2015 DigiTales. All rights reserved.
//

import Foundation

/**
 This class is the default implementation of the `Store` protocol. You will use this store in most
 of your applications. You shouldn't need to implement your own store.
 You initialize the store with a reducer and an initial application state. If your app has multiple
 reducers you can combine them by initializng a `MainReducer` with all of your reducers as an
 argument.
 */
public class MainStore: Store {

    // TODO: Setter should not be public; need way for store enhancers to modify appState anyway

    /*private (set)*/ public var appState: StateType! {
        didSet {
            subscribers.forEach { $0._newState(appState) }
        }
    }

    public var dispatchFunction: DispatchFunction!

    private var reducer: AnyReducer
    var subscribers: [AnyStoreSubscriber] = []
    private var isDispatching = false

    public required convenience init(reducer: AnyReducer, appState: StateType?) {
        self.init(reducer: reducer, appState: appState, middleware: [])
    }

    public required init(reducer: AnyReducer, appState: StateType?, middleware: [Middleware]) {
        self.reducer = reducer

        // Wrap the dispatch function with all middlewares
        self.dispatchFunction = middleware.reverse().reduce(self._defaultDispatch) {
            dispatchFunction, middleware in
            return middleware(self.dispatch, { self.appState })(dispatchFunction)
        }

        if let appState = appState {
            self.appState = appState
        } else {
            dispatch(SwiftFlowInit())
        }
    }

    public func subscribe(subscriber: AnyStoreSubscriber) {
        guard subscribers.indexOf({ $0 === subscriber }) == nil else {
            print("Store subscriber is already added, ignoring.")
            return
        }

        subscribers.append(subscriber)

        if let appState = self.appState {
            subscriber._newState(appState)
        }
    }

    public func unsubscribe(subscriber: AnyStoreSubscriber) {
        let index = subscribers.indexOf { return $0 === subscriber }

        if let index = index {
            subscribers.removeAtIndex(index)
        }
    }

    public func _defaultDispatch(action: Action) -> Any {
        if isDispatching {
            // Use Obj-C exception since throwing of exceptions can be verified through tests
            NSException.raise("SwiftFlow:IllegalDispatchFromReducer", format: "Reducers may not " +
                "dispatch actions.", arguments: getVaList(["nil"]))
        }

        isDispatching = true
        let newState = self.reducer._handleAction(self.appState, action: action)
        isDispatching = false

        self.appState = newState

        return action
    }

    public func dispatch(action: Action) -> Any {
        return dispatch(action, callback: nil)
    }

    public func dispatch(actionCreatorProvider: ActionCreator) -> Any {
        return dispatch(actionCreatorProvider, callback: nil)
    }

    public func dispatch(asyncActionCreatorProvider: AsyncActionCreator) {
        dispatch(asyncActionCreatorProvider, callback: nil)
    }

    public func dispatch(action: Action, callback: DispatchCallback?) -> Any {
        let returnValue = self.dispatchFunction(action)
        callback?(self.appState)

        return returnValue
    }

    public func dispatch(actionCreatorProvider: ActionCreator, callback: DispatchCallback?) -> Any {
        let action = actionCreatorProvider(state: self.appState, store: self)
        if let action = action {
            dispatch(action, callback: callback)
        }

        return action
    }

    public func dispatch(actionCreatorProvider: AsyncActionCreator, callback: DispatchCallback?) {
        actionCreatorProvider(state: self.appState, store: self) { actionProvider in
            let action = actionProvider(state: self.appState, store: self)
            if let action = action {
                self.dispatch(action, callback: callback)
            }
        }
    }

}