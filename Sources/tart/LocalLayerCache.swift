import Foundation

struct LocalLayerCache {
  let name: String
  let deduplicatedBytes: UInt64
  let diskURL: URL

  private let mappedDisk: Data
  private var digestToRange: [String : Range<Data.Index>] = [:]

  init?(_ name: String, _ deduplicatedBytes: UInt64, _ diskURL: URL, _ manifest: OCIManifest) throws {
    self.name = name
    self.deduplicatedBytes = deduplicatedBytes
    self.diskURL = diskURL

    // mmap(2) the disk that contains the layers from the manifest
    self.mappedDisk = try Data(contentsOf: diskURL, options: [.alwaysMapped])

    // Record the ranges of the disk layers listed in the manifest
    var offset: UInt64 = 0

    for layer in manifest.layers.filter({ $0.mediaType == diskV2MediaType }) {
      guard let uncompressedSize = layer.uncompressedSize() else {
        return nil
      }

      self.digestToRange[layer.digest] = Int(offset)..<Int(offset+uncompressedSize)

      offset += uncompressedSize
    }
  }

  func find(_ digest: String) -> Data? {
    guard let foundRange = self.digestToRange[digest] else {
      return nil
    }

    return self.mappedDisk.subdata(in: foundRange)
  }
}
