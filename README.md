# Machinus
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.com/drekka/Machinus.svg?branch=master)](https://travis-ci.com/drekka/Machinus)

* [Quick guide](#quickguide)
* [States](#states)
    * [Adding actions to states](#addingactionstostates)
    * [Global states](#globalstates)
    * [Final states](#finalstates)
    * [Transition barriers](#transitionbarriers)
    * [The background state](#thebackgroundstate)
* [The state machine](#thestatemachine)
    * [Options](#options)
    * [Checking the engine's state](#checkingtheenginesstate)
    * [Transitions](#transitions)
        * [Transition execution](#transitionexecution)
        * [Manual transitions](#manualtransitions)
        * [Dynamic transitions](#dynamictransitions)
        * [Transition errors](#transitionerrors)
        * [Transition actions](#transitionactions)
        * [Listening to transition notifications](#listeningtotransitionnotifications)
    * [Resetting the engine](#resettingtheengine)

# What is a state machine?

Often there are things in your app that have a number of unique *'states'*. For example - a user's states include being registered, logged out or logged in. You represent these states with booleans or enums, then add code which looks at these values to decide what to do. Displaying a home screen when the user logs in for example. 

It usually starts this with some simple `if` or `switch` statements, but as the app grows it's not uncommon to end up adding more variables with the code starting to get complicated, difficult to manage, debug and develop.

This is where a state machine can help. Basically a state machine provides a simple interface for creating states, defining which state changes are allowed and which aren't, and attaching code to execute when a state change occurs, without you having to add all the logic to decide what to do.

# Machinus?

If you look around [Github](https://www.github.com) you'll find plenty of state machine implementations so why write another? Simply put - Because none of them worked the way I wanted and... because I could. 

Generally speaking I found two different types of state machines implementations on Github - Those that defined states using enums and those that defined states using classes. Enum based machines tend to have limited functionality because of the limitations of enums, but be easy to setup and work with. Machines where state's were defined by creating classes tended to require more code and not be as easy to work with as enum based ones. 

With Machinus I decided to take a different approach. I use a protocol to provide the unique identities of the states, and then a single class to setup the functionality of those states. I found this gives me the best of both styles of machines.

# Quick guide

## 1. Installing

Machinus is [Carthage](https://github.com/Carthage/Carthage) friendly. Just add this to your `Cartfile`:

```
github "drekka/Machinus"
```

And update your dependencies.

## 1. Declare your state identifiers

First you need a way to identify the states of the machine. The simplest way to start is to use an enum. You can use other things, but an enum is the easiest. Then just implement the `StateIdentifer` protocol.

```swift
enum UserState: StateIdentifier {
    case initialising
    case registering
    case loggedIn
    case loggedOut
}
```

## 2. Create the states and the machine

Once we have our state identifiers, we can then create a series of `Now we can create a set of states`State<T>` instances which are used to configure the states and a machine instance to manage them.

```swift
let initialising = State<UserState>(withIdentifier: .initialising, allowedTransitions: .registering, .loggedOut)
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
let loggedIn = State<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
let loggedOut = State<UserState>(withIdentifier: .loggedOut, allowedTransitions: .loggedIn)

let machine = Machinus(withStates: initialising, registering, loggedIn, loggedOut)
```

By default Machinus starts in the first state, so...

```swift
machine.state == .initialising // = true
```

Notice that whist we create `State<T>` instances to configure the machine, we only need to use our `StateIdentifier`s to talk to it. `State<T>` and `StateIdentifier` implement `Equatable` and can be directly compared. In addition, all Machinus functions that have a state argument use the `StateIdentifer` instances. The goal of all of this is to give you the ease of configuration that classes provide through the `State<T>` class whilst still keeping comparisons and arguments simple. 

## 3. Add functionality

Now let's do something when a state changes.

```swift
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
    .afterEntering { _ in
        registerUser()
}
```

This is just one hook. There are plenty more.

## 4. Transition

And finally lets tell the machine to change state. Something we call a 'Transition'.

```swift
machine.transition(toState: .registering) { previousState, error in
    // Do stuff after the transition.
}
```

Ta da!

# States

As you saw in the quick guide, creating a state is just a matter of defining its identifier and creating an instance of the `State<I>` class.

```swift
let initialising = State<UserState>(withIdentifier: .initialising, allowedTransitions: .registering, .loggedOut)
```

The `allowedTransitions` argument is where you can specify states that the machine is allowed to transition to from this one. If you try and transition to a state not in this list an error will be thrown.

## Adding actions to states

As previously stated, state machines provide the ability to attach functionality (which we call 'Actions') to transitions from one state to another. 

There are four actions you can attach to each state and you can define more than one at a time. The four actions are: 

* **`.beforeEntering { previousState in ... }`** - Executed just before the machine changes to the state you defined it on. It's passed the state that the machine is changing from as an argument.

* **`.afterEntering { previousState in ... }`** - Executed just after the machine changes to the state you defined it on.  It's passed the state that the machine is changing from as an argument.

* **`.beforeLeaving { nextState in ... }`** - Executed just before the machine changes from the state you defined it on. It's passed the state that the machine is changing to as an argument.

* **`.afterLeaving { nextState in ... }`** - Executed just after the machine changes from the state you defined it on. It's passed the state that the machine is changing to as an argument.

Here's how you would define all of these actions on a state.

```swift
let registering = State<UserState>(withIdentifier: .registering, allowedTransitions: .loggedIn)
    .beforeEntering { previousState in
        setupForRegistering()
    }
    .afterEntering { previousState in
        startRegistering()
    }
    .beforeLeaving { nextState in
        saveRegisteringData()
    }
    .afterLeaving { nextState in
        registationIsDone()
}
```

As you can see these are all chaining methods and can be entered in any order that suites you. They're also passed the relevant 'other' state. For the state being left, it's the state the machine is going to, and for the state being changed too, it's the previous state. 

## Global states

You can also specify that a state is 'global' in nature. Global states do not need to specified in other state's allowed transitions lists because any state in the machine can transition to them. Hence the global nature of them.

```swift
let initialising = State<UserState>(withIdentifier: .appError)
    .makeGlobal()
```

## Final states

Sometimes you might want to have a state that cannot be exited. For example, where the application has got itself into some wierd state of confusion and cannot continue. Ok, it's a stretch, but I have had a requirement for this. 

```swift
let systemError = State<UserState>(withIdentifier: .systemError)
    .makeFinal()
```

Anyway, if you designate a state and being 'final', then once entered, the machine cannot exit it. Final states:

* Cannot be transitioned from.
* Do not allow any of the 'leaving' actions to be set. A  swift `fatalError` will be generated.
* The only way out of a final state is to `reset()` the state machine.

## Transition barriers

Transition barriers are simple closures that can cancel a transition. They are most useful where you have some criteria for allowing a change to a state, but don't want to repeat that criteria on all the other states that can transition to it. 

A state's barrier closure is called before a transition is started. If the closure returns false then the transition is cancelled and the completion called with a `MachinusError.transitionDenied` error.

You can setup a barrier like this.

```swift
let loggedIn = State<UserState>(withIdentifier: .loggedIn, allowedTransitions: .loggedOut)
    .withTransitionBarrier {
        Return self.user != nil
}
```

Just return false to deny the transition.

## The background state

Something that often occurs is a need for the state machine to know when the application has been put into the background. For example, if the application has sensitive data, it might want to add and remove a privacy screen when the application goes to and from the background. Machinus supports this and will automatically track the application by transitioning to and from a specific state as the application is moved to and from the background. 

Here's an example of how this is setup:

```swift
self.backgroundState = StateConfig(identifier: .background)
    .beforeEntering { previousState in
        addPrivacyScreen()
    }
    .afterLeaving { nextState in
        removePrivacyScreen()
}

self.machine = Machinus(withStates: initialising, registering, loggedIn, loggedOut, backgroundState)
self.machine.backgroundState = .background
```

That's all you have to do. Note:

* You don't need to add the background state to the `allowedTransition` lists of other states. Machinus bypasses this checking for transitions to and from the background state.
* Transition barriers are not tested when entering or leaving the background state.
* Machinus stores the current state before transitioning to the background state. It then automatically returns to that state when the application enters the foreground again.
* All the normal actions are executed.

# The state machine

Creating a state machine looks like this.

```swift
let machine = Machinus(
    name: "User state machine", 
    withStates: initialising, registering, loggedIn, loggedOut)
```

The `name` argument is option and is used to uniquely identify the state machine in logs and debug sessions. If you don't set it, a UUID is generated appended with the type of the state identifier.

You cannot create a state machine without at least 3 states. This is simple logic. A state machine is a waste of time if it only has 1 or two states. So the initialiser won't compile with anything less than 3. 

## Options

* `enableSameStateError: Bool` (property)  - Default false. If true and you request a transition to a state when the machine is already in that state then the `MachinusError.alreadyInState` is passed to the completion closure. \
When false (the default) the machine simply calls the transition completion with a `nil` previous state and a `nil` error. No transition or transition closures are executed.

* `enableFinalStateTransitionError: Bool` (property)  - Default false. If true and you request a transition from a state that has the final flag.

* `postNotifications: Bool` (property)  - Default false. If true, every time a transition is done, a matching state change notification will be sent. This allows objects which cannot directly access the machine to still know about state changes.

* `transitionQueue: DispatchQueue` (property) - Default `DispatchQueue.main`. The dispatch queue that transition will be queued on.

## Checking the engine's state

Machinus has a `state` variable which allows you to see the current state of the machine and because states are defined using the `StateIdentifier`, which is an extension of `Hashable` and `Equatable`, you can easy compare states using stadnard operators.

```swift
machine.state == .initialising // = true
```

## Transitions

A 'Transition' is the process of a state machine changing from one state to another. Machinus provides two types of transitions and you can use one or the other, or both in any combination you want.

### Transition execution

The execution of the actions for a transition follow a specific order. Here's an outline of what happens.

* The transition is requested and queued on the transition queue.
    1. The transition is pre-flighted and errors returned if any of these conditions fail:
          * The current state is not a final state.
	    * The new state has not been registered.
	    * The new state is not global or in the list of allowed transitions of the current  state.
	    * The new state's transition barrier denies the transition.
	    * The new state and the old state are the same. Error optional, see properties.
    1. The transition is executed:
        1. The machines `beforeTransition` closure is called.
        1. The old state's `beforeLeaving` closure is called.
        1. The new state's `beforeEntering` closure is called.
        1. The state is changed.
        1. The old state's `AfterLeaving` closure is called.
        1. The new state's `afterEntering` closure is called.
        1. The machines `afterTransition` closure is called.
        1. The state change notification is sent.
    1. The transition completion is called with the old state.

#### Dispatch queues

All transitions are queued on a dispatch queue. This is to ensure that they execute smoothly and that if one of their actions triggers another state change, the first transitions gets a chance to execute before the second transition is started.

The default dispatch queue is the main dispatch queue, but you can change it to another if you like.

### Manual transitions

Manual transitions are the simplest to follow. They are where you pass the state you want the machine to transition to as an argument. 

```swift
machine.transition(toState: .registering) { previousState, error in
    if let error = error {
        // Handle the error
        return
    }
    // The transition was successful.
}
```

If the transition was successful the completion closure is passed the previous state of the machine. If there was a problem, an error is passed instead. Depending on the setup of your machine it may also be possible for the closure to get both a nil previous state and a nil error. This can occur if you have told the machine to transition to the state it's already in, and not set or from a final state, in which case the default is to do nothing.

### Dynamic transitions

Dynamic transitions are a different thing. They are most useful when you have some logic that defines the next state and you want to set it on the engine rather than the code calling it. Here's an example:

```swift
let restarting = State<UserState>(withIdentifier: .restarting)
    .withDynamicTransitions {
        return userWasLoggedIn() ? .loggedIn : .loggedOut
}

// And when the machine is in the restarting state. 
machine.transition { previousState, error in
    if let error = error {
        // Handle the error
        return
    }
    // The transition was successful.
}
```

Notice how we trigger the dynamic transition by not specifying the new state.

### Transition errors

Transitions can return the following `MachinusError` errors:

* **.alreadyInState** - Returned if a state change is requested, the requested state is the same as the current state and the `enableSameStateError` flag is set.

* **.transitionDenied** - Returned when a transition barrier rejects a transition.

* **.illegalTransition** - Returned when the target state is not in the current state's allowed transition list.

* **.dynamicTransitionNotDefined** - Returned when a dynamic transition is requested and there is no dynamic transition defined on the current state.

* **.finalState** - Returned when the `enableFinalStateTransitionError`flag is turned on and you attempt to transition from a state that is marked as final.

### Transition actions

In addition to actions which are attached to states, you can add the following actions to the state machine itself.

* **`.beforeTransition { fromState, toState in ...}`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

* **`.afterTransition { fromState, toState in ... }`** - Executed just before the machine changes state. It's passed both the from and to states as arguments.

### Listening to transition notifications

Sometimes you want to be notified of a state change but it's in a state machines that's somewhere else in the code base. Machinus supports this by providing a property which enables the sending a notification once a transition has executed. Here's how to use it.

```swift
self.machine!.postNotifications = true
self.machine!.transition(toState: .loggedIn) { _, _ in } 
```

And somewhere else in you code:

```swift
let observer = NotificationCenter.default.addStateChangeObserver { [weak self] (stateMachine: Machinus<MyState>, fromState: MyState, toState: MyState) in
    // Do something here.
}
```

It's important to get the type of the states right in the closure as the observer will only call it for state machines of that type.


## Resetting the engine

Resetting the state machine to it's initial state is quite simple. This is a hard reset which does not execute any actions or rules.

```swift
machine.reset()
```
 
