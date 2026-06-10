nonisolated struct RingBuffer<Element: Sendable>: Sendable {
    private var storage: [Element] = []
    private var head = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    var count: Int { storage.count }

    var last: Element? {
        guard !storage.isEmpty else { return nil }
        return storage[(head + storage.count - 1) % capacity]
    }

    /// Oldest first.
    var elements: [Element] {
        guard !storage.isEmpty else { return [] }
        return (0..<storage.count).map { storage[(head + $0) % capacity] }
    }

    mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }
}
