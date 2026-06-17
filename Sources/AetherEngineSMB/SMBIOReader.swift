import Foundation
import AetherEngine

/// Bridges a `ByteRangeSource` into the engine's `IOReader`. `read`/`seek`
/// are synchronous blocking calls on the engine's demux thread; the async
/// source is driven through a `DispatchSemaphore`.
public final class SMBIOReader: IOReader, @unchecked Sendable {
    private let source: ByteRangeSource
    private let ownsSource: Bool
    private var position: Int64 = 0
    private var inFlight: Task<Void, Never>?
    private var didClose = false

    /// `AVSEEK_SIZE` from FFmpeg: return total size, do not move.
    private let avseekSize: Int32 = 65536

    public init(source: ByteRangeSource, ownsSource: Bool = true) {
        self.source = source
        self.ownsSource = ownsSource
    }

    public func read(_ buffer: UnsafeMutablePointer<UInt8>?, size: Int32) -> Int32 {
        guard let buffer, size > 0 else { return 0 }
        let offset = position
        let want = Int(size)

        let semaphore = DispatchSemaphore(value: 0)
        // `outcome` is written once on the Task, read once after wait(): no race.
        nonisolated(unsafe) var outcome: Result<Data, Error> = .success(Data())
        let task = Task { [source] in
            do { outcome = .success(try await source.read(at: offset, length: want)) }
            catch { outcome = .failure(error) }
            semaphore.signal()
        }
        inFlight = task
        semaphore.wait()
        inFlight = nil

        switch outcome {
        case .failure:
            return -1
        case .success(let data):
            if data.isEmpty { return 0 } // EOF
            let n = min(data.count, want)
            data.copyBytes(to: buffer, count: n)
            position += Int64(n)
            return Int32(n)
        }
    }

    public func seek(offset: Int64, whence: Int32) -> Int64 {
        switch whence {
        case Int32(SEEK_SET): position = offset
        case Int32(SEEK_CUR): position += offset
        case Int32(SEEK_END): position = source.byteSize + offset
        case avseekSize:      return source.byteSize
        default:              return -1
        }
        if position < 0 { position = 0; return -1 }
        return position
    }

    public func cancel() {
        inFlight?.cancel()
    }

    public func makeIndependentReader() -> IOReader? {
        // Range reads are stateless and SMB2Manager is thread safe, so the
        // independent reader shares the connection but never owns its teardown.
        SMBIOReader(source: source, ownsSource: false)
    }

    public func close() {
        guard !didClose else { return }
        didClose = true
        if ownsSource { source.close() }
    }
}
