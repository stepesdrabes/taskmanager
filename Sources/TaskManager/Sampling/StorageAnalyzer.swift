import Foundation

nonisolated struct StorageUsage: Sendable {
    var applications: UInt64 = 0
    var photos: UInt64 = 0
    var movies: UInt64 = 0
    var audio: UInt64 = 0

    var categorized: UInt64 { applications + photos + movies + audio }
}

/// Computes a storage breakdown by file type the way System Settings does, but
/// from the Spotlight index — which already holds every file's size, so this
/// reads results instead of scanning the disk. Every query runs on a background
/// `OperationQueue`, so neither the index work nor the summation touches the
/// main thread. Run once and cache; this is not part of the 1 Hz sampler.
nonisolated enum StorageAnalyzer {
    /// Holds the non-Sendable query so the background closures capture only this
    /// box; all access stays on the query's own serial operation queue.
    private final class Holder: @unchecked Sendable {
        let query = NSMetadataQuery()
        var token: NSObjectProtocol?
    }

    static func analyze() async -> StorageUsage {
        async let applications = size(ofType: "com.apple.application-bundle")
        async let photos = size(ofType: "public.image")
        async let movies = size(ofType: "public.movie")
        async let audio = size(ofType: "public.audio")
        return await StorageUsage(applications: applications, photos: photos, movies: movies, audio: audio)
    }

    private static func size(ofType contentType: String) async -> UInt64 {
        await withCheckedContinuation { (continuation: CheckedContinuation<UInt64, Never>) in
            let holder = Holder()
            let query = holder.query
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            query.operationQueue = queue
            query.predicate = NSPredicate(fromMetadataQueryString: "kMDItemContentTypeTree == '\(contentType)'")
            query.searchScopes = [NSMetadataQueryLocalComputerScope]

            holder.token = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering, object: query, queue: queue
            ) { notification in
                guard let query = notification.object as? NSMetadataQuery else { return }
                query.disableUpdates()
                var total: UInt64 = 0
                for index in 0..<query.resultCount {
                    if let item = query.result(at: index) as? NSMetadataItem,
                       let size = item.value(forAttribute: "kMDItemFSSize") as? Int64, size > 0 {
                        total += UInt64(size)
                    }
                }
                query.stop()
                if let token = holder.token { NotificationCenter.default.removeObserver(token) }
                continuation.resume(returning: total)
            }
            queue.addOperation { holder.query.start() }
        }
    }
}
