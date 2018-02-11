//
//  Inject.swift
//  Guise
//
//  Created by Gregory Higley on 2/11/18.
//  Copyright © 2018 Gregory Higley. All rights reserved.
//

import Foundation

public extension Resolving {
    @discardableResult func register<Injectable>(injectable: Injectable.Type, injection: @escaping Injection<Injectable>) -> String {
        let key = String(reflecting: injectable)
        return register(key: key) {
            guard let target = $0 as? Injectable else {
                return $0
            }
            return injection(target, $1)
        }
    }
    
    @discardableResult func unregister<Injectable>(injectable: Injectable.Type) -> Int {
        let key = String(reflecting: Injectable.self)
        return unregister(keys: [key])
    }
    
    func into<Target>(injectable type: Target.Type) -> Injector<Target> {
        return Injector(resolver: self)
    }
}

extension _Resolving {
    @discardableResult static func register<Injectable>(injectable: Injectable.Type, injection: @escaping Injection<Injectable>) -> String {
        return resolver.register(injectable: injectable, injection: injection)
    }
    
    @discardableResult static func unregister<Injectable>(injectable: Injectable.Type) -> Int {
        return resolver.unregister(injectable: injectable)
    }
    
    static func into<Target>(injectable type: Target.Type) -> Injector<Target> {
        return resolver.into(injectable: type)
    }
}