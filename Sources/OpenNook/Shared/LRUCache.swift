struct LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var order: [Key] = []
    private var store: [Key: Value] = [:]

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var values: [Value] {
        order.compactMap { store[$0] }
    }

    var isEmpty: Bool { order.isEmpty }

    func value(for key: Key) -> Value? {
        store[key]
    }

    mutating func insert(_ value: Value, for key: Key) {
        if store[key] != nil {
            order.removeAll { $0 == key }
        }
        order.insert(key, at: 0)
        store[key] = value
        while order.count > capacity {
            let evicted = order.removeLast()
            store.removeValue(forKey: evicted)
        }
    }

    mutating func touch(_ key: Key) {
        guard store[key] != nil else { return }
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
    }

    mutating func removeAll() {
        order.removeAll()
        store.removeAll()
    }
}
