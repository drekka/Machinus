//
//  Notifications.swift
//  Machinus
//
//  Created by Derek Clarkson on 21/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

import Foundation

/// State change keys for notifications.
private enum StateChange: String {
    case notificationName
    case fromState
    case toState
}

/// Marchinus extensions to the notification center.
public extension NotificationCenter {

    /**
      Creates and sends the notification of a state change.

      The notification sent contains the old state, new state and a machine reference in the user info data.

      - Parameter machine: The machine that just had a state change.
      - Parameter oldState: The previous state of the machine.
     */
    func postStateChange<T>(machine: StateMachine<T>, oldState: T) {
        post(.stateChange(machine: machine, oldState: oldState))
    }

    /**
      Adds a passed closure as a notification observer for state change notifications and returns the created notification center observer.

      - Parameter observer: The closure that will be called when a state change notification is sent. This closure will only be called if a state change notification is received
      that matches the types used by the state machine.

      - Parameter machine: The machine that sent the notification.
      - Parameter fromState: The previous state of the machine.
      - Parameter toState: The new state of the machine.
     */
    func addStateChangeObserver<T>(_ observer: @escaping (_ machine: StateMachine<T>, _ fromState: T, _ toState: T) -> Void) -> Any {
        return addObserver(forName: .stateChange, object: nil, queue: nil) { notification in
            if let data: (machine: StateMachine<T>, fromState: T, toState: T) = notification.stateChangeInfo() {
                observer(data.machine, data.fromState, data.toState)
            }
        }
    }
}

public extension Notification.Name {
    static let stateChange = Notification.Name(StateChange.notificationName.rawValue)
}

extension Notification {

    static func stateChange<T>(machine: StateMachine<T>, oldState: T) -> Notification {
        return Notification(name: .stateChange, object: machine, userInfo: [
            StateChange.fromState.rawValue: oldState,
            StateChange.toState.rawValue: machine.state,
        ])
    }

    func stateChangeInfo<T>() -> (machine: StateMachine<T>, fromState: T, toState: T)? {

        guard let machine = object as? StateMachine<T>,
              let info = userInfo,
              let fromState = info[StateChange.fromState.rawValue] as? T,
              let toState = info[StateChange.toState.rawValue] as? T else {
            return nil
        }

        return (machine: machine, fromState: fromState, toState: toState)
    }
}
