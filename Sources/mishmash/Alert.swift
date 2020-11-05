struct Alert {}
postfix operator /

let alert = Alert()
postfix func /(_ a: Alert) -> Never {
    fatalError()
}
