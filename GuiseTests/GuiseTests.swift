//
//  GuiseTests.swift
//  Guise
//
//  Created by Gregory Higley on 3/12/16.
//  Copyright © 2016 Gregory Higley. All rights reserved.
//

import XCTest
@testable import Guise

enum BundleName {
    case main
}

enum Container {
    case people
    case dogs
}

protocol Animal {
    var name: String { get }
}

struct Human: Animal {
    let name: String
}

struct 🐶: Animal {
    let name: String
}

struct HumanMetadata: Equatable {
    let coolness: Int
}

func ==(lhs: HumanMetadata, rhs: HumanMetadata) -> Bool {
    return lhs.coolness == rhs.coolness
}

protocol Controlling: class {
    
}

class Controller: Controlling, Init {
    required init() {
        
    }
}

struct A: Init {
    let value = "a"
}

struct B {
    let a: A
    let i: Int
    init(a: A, i: Int) {
        self.a = a
        self.i = i
    }
}

struct C {
    let b: B
    init(b: B) {
        self.b = b
    }
}

class GuiseTests: XCTestCase {
    
    override func tearDown() {
        _ = Guise.clear()
        super.tearDown()
    }
    
    func testKeyEquality() {
        let key1 = Key<Int>(name: "three", container: Guise.Container.default)
        let key2 = Key<Int>(name: "three", container: Guise.Container.default)
        let key3 = Key<Int>(name: Guise.Name.default, container: Guise.Container.default)
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, key3)
    }
    
    func testFilteringAndMetadata() {
        let names = ["Huayna Capac": 7, "Huáscar": 1, "Atahualpa": 9]
        for (name, coolness) in names {
            _ = Guise.register(instance: Human(name: name), name: name, container: Container.people, metadata: HumanMetadata(coolness: coolness))
        }
        XCTAssertEqual(3, (Guise.filter(container: Container.people) as Set<AnyKey>).count)
        _ = Guise.register(instance: Human(name: "Augustus"), name: "Augustus", container: Container.people, metadata: 77)
        var metafilter: Metafilter<HumanMetadata> = { $0.coolness > 1 }
        // Only two humans in Container.people have HumanMetadata with coolness > 1.
        // Augustus does not have HumanMetadata. He has Int metadata, so he is simply skipped.
        XCTAssertEqual(2, Guise.filter(container: Container.people, metafilter: metafilter).count)
        _ = Guise.register(instance: Human(name: "Trump"), metadata: HumanMetadata(coolness: 0))
        // This metafilter effectively queries for all registrations using HumanMetadata,
        // regardless of the value of this Metadata.
        metafilter = { _ in true }
        // We have 4 Humans matching the metafilter query. 3 in Container.people and 1 in the default container.
        XCTAssertEqual(4, Guise.filter(type: Human.self, metafilter: metafilter).count)
        _ = Guise.register(instance: 🐶(name: "Brian Griffin"), metadata: HumanMetadata(coolness: 10))
        // After we added a dog with HumanMetadata, we query by metafilter only, ignoring type and container.
        // We have 5 matching registrations: the three Sapa Incas, Trump, and Brian Griffin.
        XCTAssertEqual(5, (Guise.filter(metafilter: metafilter) as Set<AnyKey>).count)
    }
    
    func testRegistrationsWithEqualKeysOverwrite() {
        let fidoKey = Guise.register(container: Container.dogs) { 🐶(name: "Fido") }
        // This registration should overwrite Fido's.
        let brutusKey = Guise.register(container: Container.dogs) { 🐶(name: "Brutus") }
        // These two keys are equal because they register the same type in the same container.
        XCTAssertEqual(fidoKey, brutusKey)
        // We should only have 1 dog in the container…
        XCTAssertEqual(1, (Guise.filter(container: Container.dogs) as Set<AnyKey>).count)
        // and that dog should be Brutus, not Fido. Last one wins.
        let brutus = Guise.resolve(container: Container.dogs)! as 🐶
        XCTAssertEqual(brutus.name, "Brutus")
    }
    
    func testMultipleRegistrations() {
        let keys: Set<Key<Animal>> = [Key(name: "Lucy"), Key(name: "Fido")]
        _ = Guise.register(keys: keys) { (name: String) in 🐶(name: name) as Animal }
        var name = "Fido"
        XCTAssertNotNil(Guise.resolve(name: name, parameter: name) as Animal?)
        name = "Lucy"
        XCTAssertNotNil(Guise.resolve(name: name, parameter: name) as Animal?)
    }
    
    func testResolutionWithParameter() {
        _ = Guise.register(container: Container.dogs) { (name: String) in 🐶(name: name) }
        let dog = Guise.resolve(container: Container.dogs, parameter: "Brutus")! as 🐶
        XCTAssertEqual(dog.name, "Brutus")
    }
    
    func testCaching() {
        _ = Guise.register(cached: true) { Controller() as Controlling }
        let controller1 = Guise.resolve()! as Controlling
        let controller2 = Guise.resolve()! as Controlling
        // Because we asked Guise to cache this registration, we should get back the same reference every time.
        XCTAssert(controller1 === controller2)
        // Here we've asked Guise to call the registered block again, thus creating a new instance.
        let controller3 = Guise.resolve(type: Controlling.self, cached: false)!
        XCTAssertFalse(controller1 === controller3)
        // However, the existing cached instance is still there.
        let controller4 = Guise.resolve()! as Controlling
        XCTAssert(controller1 === controller4)
    }
    
    func testResolutionWithEquatableMetadata() {
        let metadata = HumanMetadata(coolness: 1000)
        let metawronga = HumanMetadata(coolness: 0)
        let human = Human(name: "Ludwig von Mises")
        let name = human.name
        _ = Guise.register(instance: human, name: name, metadata: metadata)
        // Sanity check. Can we resolve without metadata?
        XCTAssertNotNil(Guise.resolve(type: Human.self, name: name))
        // This succeeds because all the ducks are in a row.
        XCTAssertNotNil(Guise.resolve(type: Human.self, name: name, metadata: metadata))
        // Although the metadata is of the right type, the equality comparison fails, so `resolve` returns `nil`.
        XCTAssertNil(Guise.resolve(type: Human.self, name: name, metadata: metawronga))
        // The metadata is not of the right type, so `resolve` returns `nil`.
        XCTAssertNil(Guise.resolve(type: Human.self, name: name, metadata: 7))
    }
    
    func testMultipleResolutionsWithMetafilter() {
        let names = ["Huayna Capac": 7, "Huáscar": 1, "Atahualpa": 9]
        for (name, coolness) in names {
            _ = Guise.register(instance: Human(name: name), name: name, container: Container.people, metadata: HumanMetadata(coolness: coolness))
        }
        _ = Guise.register(instance: Human(name: "Augustus"), name: "Augustus", container: Container.people, metadata: 77)
        // This excludes poor Huáscar, because his coolness is only 1.
        let metafilter: Metafilter<HumanMetadata> = { $0.coolness > 1 }
        let keys = Guise.filter(type: Human.self, container: Container.people, metafilter: metafilter)
        let people = Guise.resolve(keys: keys) as [Human]
        XCTAssertEqual(2, people.count)
    }
    
    func testMultipleHeterogeneousResolutionsUsingProtocol() {
        _ = Guise.register(instance: Human(name: "Lucy") as Animal, name: "Lucy")
        _ = Guise.register(instance: 🐶(name: "Fido") as Animal, name: "Fido")
        let keys = Guise.filter(type: Animal.self)
        let animals = Guise.resolve(keys: keys) as [Animal]
        XCTAssertEqual(2, animals.count)
    }
    
    func testMultipleResolutionsReturningDictionary() {
        _ = Guise.register(instance: Human(name: "Lucy") as Animal, name: "Lucy", metadata: 3)
        _ = Guise.register(instance: 🐶(name: "Fido") as Animal, name: "Fido", metadata: 10)
        _ = Guise.register(instance: 7, metadata: 4)
        let metafilter: Metafilter<Int> = { $0 >= 3 }
        let keys = Guise.filter(type: Animal.self, metafilter: metafilter)
        let animals = Guise.resolve(keys: keys) as [Key<Animal>: Animal]
        // The resolution of the integer 7 above is skipped, because it is not an Animal.
        XCTAssertEqual(2, animals.count)
    }
    
    func testResolutionByKey() {
        let key = Guise.register(instance: 🐶(name: "Lucy"))
        XCTAssertNotNil(Guise.resolve(key: key))
    }
    
    func testResolutionsWithKeysOfIncorrectTypeAreSkipped() {
        _ = Guise.register(instance: Human(name: "Abraham Lincoln"), metadata: HumanMetadata(coolness: 9))
        _ = Guise.register(instance: 🐶(name: "Brian Griffin"), metadata: HumanMetadata(coolness: 10))
        let metafilter: Metafilter<HumanMetadata> = { $0.coolness > 5 }
        let keys = Guise.filter(metafilter: metafilter)
        // We get back two keys, but they resolve disparate types.
        XCTAssertEqual(2, keys.count)
        let humans = Guise.resolve(keys: Set(keys.flatMap(Key.init))) as [Human]
        // Because we are resolving Humans, not dogs, Brian Griffin is skipped.
        XCTAssertEqual(1, humans.count)
    }
    
    func testRetrieveTypedMetadata() {
        let key = Guise.register(instance: Human(name: "Ruijie Li"), metadata: HumanMetadata(coolness: 99))
        XCTAssertNotNil(Guise.metadata(for: key, type: HumanMetadata.self))
    }
    
    func testRetrieveUntypedMetadata() {
        let key = Guise.register(instance: Human(name: "Ruijie Li"), metadata: HumanMetadata(coolness: 99))
        XCTAssertNotNil(Guise.metadata(for: key))
    }
    
    func testTypeRegistrationAndResolution() {
        let name = UUID()
        // `type` is always the type we're registering in the key. `Controller` must implement `Init`.
        _ = Guise.register(type: Controlling.self, for: Controller.self, name: name)
        XCTAssertNotNil(Guise.resolve(type: Controlling.self, name: name))
    }
    
    func testDependencyInjectionAndParameters() {
        _ = Guise.register(type: A.self)
        _ = Guise.register{ (i: Int) in B(a: Guise.resolve()!, i: i) }
        _ = Guise.register{ (i: Int) in C(b: Guise.resolve(parameter: i)!) }
        XCTAssertNotNil(Guise.resolve(parameter: 3) as C?)
    }
}
