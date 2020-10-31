//
//  FunctionBuilders.swift
//  mishmash
//
//  Created by Logan Wright on 10/31/20.
//

import Foundation


@_functionBuilder
struct Builder {
    static func buildBlock(_ strs: String...) -> String {
        return strs.joined(separator: " – ")
    }

    static func buildBlock(_ strs: Any...) -> String {
        return strs.map { "\($0)" } .joined(separator: " – ")
    }
}

struct Combiner {
    init(@Builder builder: () -> String) {

    }
}

struct Foo {
    var name: String
}

func go() {
    asdfsadfsd()
    let a = Foo(name: "asdf")
    let b = \Foo.name
    let value = a[keyPath: b]
    print(value)
    [1,2,3].map(\.words)
    let c = Combiner {
        "a"
    }
}

