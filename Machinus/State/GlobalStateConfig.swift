//
//  GlobalStateConfig.swift
//  Machinus
//
//  Created by Derek Clarkson on 11/6/21.
//  Copyright © 2021 Derek Clarkson. All rights reserved.
//

/// Global states do not need to be in allowed transition lists as any other state can transition to them, except for final states which are always final.
public final class GlobalStateConfig<T>: StateConfig<T> where T: StateIdentifier {}
