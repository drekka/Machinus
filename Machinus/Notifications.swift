//
//  Notifications.swift
//  Machinus
//
//  Created by Derek Clarkson on 21/2/19.
//  Copyright © 2019 Derek Clarkson. All rights reserved.
//

private enum StateChange: String {
    case notificationName
    case fromState
    case toState
}


public extension NotificationCenter {

    func postStateChange<S, T>(machine: S, oldState: T) where S: StateMachine, S.StateIdentifier == T, T: StateIdentifier {
        self.post(Notification.stateChangeNotification(machine: machine, oldState: oldState))
    }
}

extension Notification {

    public static let stateChangeNotification = Notification.Name(StateChange.notificationName.rawValue)

    static func stateChangeNotification<S, T>(machine: S, oldState: T) -> Notification where S: StateMachine, S.StateIdentifier == T, T: StateIdentifier {
        return Notification(name: self.stateChangeNotification, object: machine, userInfo: [
            StateChange.fromState.rawValue: oldState,
            StateChange.toState.rawValue: machine.state
            ])
    }

    public func stateChangeInfo<S, T>() -> (machine: S, fromState: T, toState: T)? where S: StateMachine, S.StateIdentifier == T, T: StateIdentifier {

        guard let machine = self.object as? S,
            let info = self.userInfo,
            let fromState = info[StateChange.fromState.rawValue] as? T,
            let toState = info[StateChange.toState.rawValue] as? T else {
                return nil
        }

        return (machine: machine, fromState: fromState, toState: toState)
    }
}
