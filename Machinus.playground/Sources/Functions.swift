import Foundation

// A little playground async helper
public func wait() {
    //print("    Executing run loop")
    RunLoop.current.run(until: Date() + TimeInterval(0.5))
}

public func registerUser() {
    print("    Registering a user")
}

public func displayUserHome() {
    print("    Displaying the user's home screen")
}

public func displayEnterPassword() {
    print("    Please enter a password")
}
