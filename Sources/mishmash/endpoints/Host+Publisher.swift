import Combine

extension Host {
    var publisher: HostPublisher { HostPublisher(self) }
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
        // ignoring command, single val
    }
}
