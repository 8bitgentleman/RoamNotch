import Combine
import Darwin
import Foundation

class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()

    @Published private(set) var cpuUsage: Double = 0      // 0.0–1.0
    @Published private(set) var ramUsage: Double = 0      // 0.0–1.0
    @Published private(set) var netDown: Double = 0       // bytes/sec
    @Published private(set) var netUp: Double = 0         // bytes/sec

    @Published private(set) var cpuHistory: [Double]     = Array(repeating: 0, count: 40)
    @Published private(set) var ramHistory: [Double]     = Array(repeating: 0, count: 40)
    @Published private(set) var netDownHistory: [Double] = Array(repeating: 0, count: 40)

    private var ticker: AnyCancellable?

    // CPU tick state (Swift arrays, no raw pointer retention)
    private var prevCPUTicks: [[Int32]] = []

    // Network byte counter state
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0

    // Auto-scaling ceiling for network sparkline
    private var netCeiling: Double = 500_000  // starts at 500 KB/s

    private init() {}

    func start() {
        guard ticker == nil else { return }
        update()
        ticker = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
    }

    private func update() {
        cpuUsage = readCPU()
        ramUsage = readRAM()
        let (down, up) = readNetwork()
        netDown = down
        netUp = up

        netCeiling = max(netCeiling, down, up, 100_000)

        cpuHistory     = append(cpuHistory,     value: cpuUsage)
        ramHistory     = append(ramHistory,      value: ramUsage)
        netDownHistory = append(netDownHistory,  value: min(1, down / netCeiling))
    }

    private func append(_ arr: [Double], value: Double) -> [Double] {
        var a = arr
        a.append(value)
        if a.count > 40 { a.removeFirst() }
        return a
    }

    // MARK: - CPU (tick deltas across all logical cores)

    private func readCPU() -> Double {
        var numCPUs: natural_t = 0
        var rawInfo: processor_info_array_t?
        var rawCount: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &rawInfo, &rawCount) == KERN_SUCCESS,
              let info = rawInfo else { return cpuUsage }

        // Copy ticks into value types immediately so we can free the Mach buffer
        var current: [[Int32]] = []
        for i in 0 ..< Int(numCPUs) {
            let b = Int(CPU_STATE_MAX) * i
            current.append([
                info[b + Int(CPU_STATE_USER)],
                info[b + Int(CPU_STATE_SYSTEM)],
                info[b + Int(CPU_STATE_NICE)],
                info[b + Int(CPU_STATE_IDLE)],
            ])
        }
        vm_deallocate(mach_task_self_,
                      vm_address_t(bitPattern: rawInfo),
                      vm_size_t(Int(rawCount) * MemoryLayout<integer_t>.stride))

        defer { prevCPUTicks = current }
        guard prevCPUTicks.count == Int(numCPUs) else { return 0 }

        var total = 0.0
        for i in 0 ..< Int(numCPUs) {
            let c = current[i], p = prevCPUTicks[i]
            let busy  = (c[0]-p[0]) + (c[1]-p[1]) + (c[2]-p[2])
            let ticks = busy + (c[3]-p[3])
            total += ticks > 0 ? Double(max(0, busy)) / Double(ticks) : 0
        }
        return total / Double(numCPUs)
    }

    // MARK: - RAM

    private func readRAM() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return ramUsage }

        let page = UInt64(vm_kernel_page_size)
        let used = (UInt64(stats.active_count) + UInt64(stats.wire_count) +
                    UInt64(stats.compressor_page_count)) * page
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        return total > 0 ? Double(used) / Double(total) : 0
    }

    // MARK: - Network (sum all interfaces, diff from last sample)

    private func readNetwork() -> (down: Double, up: Double) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return (0, 0) }
        defer { freeifaddrs(addrs) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0

        var ptr = addrs
        while let iface = ptr {
            defer { ptr = iface.pointee.ifa_next }
            guard iface.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
                  let raw = iface.pointee.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self)
            bytesIn  += UInt64(data.pointee.ifi_ibytes)
            bytesOut += UInt64(data.pointee.ifi_obytes)
        }

        defer {
            prevBytesIn  = bytesIn
            prevBytesOut = bytesOut
        }

        guard prevBytesIn > 0 else { return (0, 0) }

        // 2-second poll interval; guard against counter rollover
        let down = bytesIn  >= prevBytesIn  ? Double(bytesIn  - prevBytesIn)  / 2 : 0
        let up   = bytesOut >= prevBytesOut ? Double(bytesOut - prevBytesOut) / 2 : 0
        return (down, up)
    }
}
