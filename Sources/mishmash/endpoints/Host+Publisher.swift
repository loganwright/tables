import Combine

extension Host {//: Publisher {
    var publisher: HostPublisher { HostPublisher(self) }
//    typealias Output = NetworkResponse
//    typealias Failure = Error
//
//    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
//        fatalError()
//    }
}

class HostPublisher: Publisher {
    typealias Output = NetworkResponse
    typealias Failure = Error

    let host: Host

    public init(_ host: Host) {
        self.host = host
    }

    public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = Subscription(subscriber: subscriber)
        subscriber.receive(subscription: subscription)

        host.on.result { result in
            switch result {
            case .success(let resp):
                let _ = subscriber.receive(resp)
                subscriber.receive(completion: .finished)
            case .failure(let err):
                subscriber.receive(completion: .failure(err))
            }
        } .send()
    }
}

extension HostPublisher {
    final class Subscription<S: Subscriber>
    where S.Input == Output, S.Failure == Failure {
        private var subscriber: S?

        init(subscriber: S) {
            self.subscriber = subscriber
        }
    }
}

extension HostPublisher.Subscription: Cancellable {
    func cancel() {
        subscriber = nil
    }
}

extension HostPublisher.Subscription: Subscription {
    func request(_ demand: Subscribers.Demand) {
        print("ignoring demand: \(demand)")
    }
}


import Combine

import Combine

/// A publisher that repeatedly sends the same value as long as there
/// is demand.
public struct Always<Output>: Publisher {
  public typealias Failure = Never

  public let output: Output

  public init(_ output: Output) {
    self.output = output
  }

  public func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
    let subscription = Subscription(output: output, subscriber: subscriber)
    subscriber.receive(subscription: subscription)
  }
}

private extension Always {
    final class Subscription<S: Subscriber>
    where S.Input == Output, S.Failure == Failure {
        var done = 4
        private let output: Output
        private var subscriber: S?

        init(output: Output, subscriber: S) {
            self.output = output
            self.subscriber = subscriber
        }
    }
}

extension Always.Subscription: Cancellable {
  func cancel() {
    subscriber = nil
  }
}

extension Always.Subscription: Subscription {
  func request(_ demand: Subscribers.Demand) {
    var demand = demand
    while let subscriber = subscriber, demand > 0, done >= 0 {
      demand -= 1
        print(demand)
      demand += subscriber.receive(output)
        done -= 1
    }

    subscriber?.receive(completion: .finished)
  }
}
