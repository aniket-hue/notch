import Foundation
import Darwin
import IOKit
import IOKit.ps

struct Metrics: Equatable {
    var cpu: Double = 0
    var memUsed: UInt64 = 0
    var memTotal: UInt64 = 0
    var gpu: Double = 0
    var diskUsed: Int64 = 0
    var diskTotal: Int64 = 0
    var batteryLevel: Double = 0
    var charging: Bool = false
    var hasBattery: Bool = false
    var netDown: Double = 0
    var netUp: Double = 0
    var uptime: TimeInterval = 0
    var cpuHistory: [Double] = []
    var memHistory: [Double] = []
    var gpuHistory: [Double] = []
}

@MainActor
final class SystemStatsService: ObservableObject {

    @Published private(set) var metrics = Metrics()

    let memTotal = ProcessInfo.processInfo.physicalMemory

    private var timer: Timer?
    private var prevCPU: host_cpu_load_info?
    private var prevNet: (rx: UInt64, tx: UInt64)?
    private var prevNetTime: TimeInterval?

    private let historyLen = 60
    private var cpuHist = [Double](repeating: 0, count: 60)
    private var memHist = [Double](repeating: 0, count: 60)
    private var gpuHist = [Double](repeating: 0, count: 60)

    func start() {
        sample()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        var m = Metrics()
        m.cpu = cpuUsage()
        m.memUsed = Self.memoryUsed()
        m.memTotal = memTotal
        m.gpu = Self.gpuUsage()
        let disk = Self.storage()
        m.diskUsed = disk.used
        m.diskTotal = disk.total
        let bat = Self.battery()
        m.batteryLevel = bat.level
        m.charging = bat.charging
        m.hasBattery = bat.present
        let net = networkThroughput()
        m.netDown = net.down
        m.netUp = net.up
        m.uptime = Self.uptime()

        let memFrac = m.memTotal > 0 ? Double(m.memUsed) / Double(m.memTotal) : 0
        cpuHist.removeFirst(); cpuHist.append(m.cpu)
        memHist.removeFirst(); memHist.append(memFrac)
        gpuHist.removeFirst(); gpuHist.append(m.gpu)
        m.cpuHistory = cpuHist
        m.memHistory = memHist
        m.gpuHistory = gpuHist

        metrics = m
    }

    private func cpuUsage() -> Double {
        guard let ticks = Self.hostCPULoad() else { return metrics.cpu }
        defer { prevCPU = ticks }
        guard let prev = prevCPU else { return 0 }
        let user = Double(ticks.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(ticks.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(ticks.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(ticks.cpu_ticks.3 &- prev.cpu_ticks.3)
        let busy = user + system + nice
        let total = busy + idle
        guard total > 0 else { return metrics.cpu }
        return max(0, min(1, busy / total))
    }

    private static func hostCPULoad() -> host_cpu_load_info? {
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        var load = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &load) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        return result == KERN_SUCCESS ? load : nil
    }

    private static func memoryUsed() -> UInt64 {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let page = UInt64(vm_kernel_page_size)

        return (UInt64(stats.active_count) + UInt64(stats.wire_count)
                + UInt64(stats.compressor_page_count)) * page
    }

    private static func gpuUsage() -> Double {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iterator) }

        var sum = 0.0
        var n = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = (perf["Device Utilization %"] ?? perf["GPU Activity(%)"]) as? Int {
                    sum += Double(util)
                    n += 1
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return n > 0 ? max(0, min(1, sum / Double(n) / 100.0)) : 0
    }

    private static func storage() -> (used: Int64, total: Int64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]), let total = values.volumeTotalCapacity else { return (0, 0) }
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        return (Int64(total) - available, Int64(total))
    }

    private static func battery() -> (level: Double, charging: Bool, present: Bool) {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef]
        else { return (0, false, false) }

        for src in list {
            guard let desc = IOPSGetPowerSourceDescription(snap, src)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            let cur = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            return (max > 0 ? Double(cur) / Double(max) : 0, charging, true)
        }
        return (0, false, false)
    }

    private func networkThroughput() -> (down: Double, up: Double) {
        let now = Date().timeIntervalSince1970
        let cur = Self.netCounters()
        defer { prevNet = cur; prevNetTime = now }
        guard let prev = prevNet, let prevTime = prevNetTime else { return (0, 0) }
        let dt = now - prevTime
        guard dt > 0 else { return (metrics.netDown, metrics.netUp) }
        let down = cur.rx >= prev.rx ? Double(cur.rx - prev.rx) / dt : 0
        let up = cur.tx >= prev.tx ? Double(cur.tx - prev.tx) / dt : 0
        return (down, up)
    }

    private static func netCounters() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ptr) }
        var cur = ptr
        while let c = cur {
            let ifa = c.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if !name.hasPrefix("lo"), let data = ifa.ifa_data {
                    let d = data.assumingMemoryBound(to: if_data.self).pointee
                    rx += UInt64(d.ifi_ibytes)
                    tx += UInt64(d.ifi_obytes)
                }
            }
            cur = ifa.ifa_next
        }
        return (rx, tx)
    }

    private static func uptime() -> TimeInterval {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname("kern.boottime", &boottime, &size, nil, 0) == 0,
              boottime.tv_sec != 0 else { return 0 }
        return Date().timeIntervalSince1970 - Double(boottime.tv_sec)
    }
}
