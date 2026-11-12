import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import AutopostCore

private let size = CGSize(width: 6000, height: 4000)

@Test func photoInfoReadsTheMomentTheCameraClockShowed() {
    let properties: [CFString: Any] = [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:09:14 18:42:07"]]
    let info = PhotoInfo(properties: properties, pixelSize: size, fileSize: nil)

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: info.takenAt!)
    #expect(parts == DateComponents(year: 2024, month: 9, day: 14, hour: 18, minute: 42))
}

@Test func southernAndWesternCoordinatesAreNegative() {
    let gps: [CFString: Any] = [
        kCGImagePropertyGPSLatitude: 33.9, kCGImagePropertyGPSLatitudeRef: "S",
        kCGImagePropertyGPSLongitude: 18.4, kCGImagePropertyGPSLongitudeRef: "W",
    ]
    let info = PhotoInfo(properties: [kCGImagePropertyGPSDictionary: gps], pixelSize: size, fileSize: nil)

    #expect(info.latitude == -33.9)
    #expect(info.longitude == -18.4)
}

@Test func cameraMakeIsNotRepeatedWhenTheModelAlreadyNamesIt() {
    let canon: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Canon", kCGImagePropertyTIFFModel: "Canon EOS R5"]]
    let sony: [CFString: Any] = [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "SONY", kCGImagePropertyTIFFModel: "ILCE-6400"]]

    #expect(PhotoInfo(properties: canon, pixelSize: size, fileSize: nil).camera == "Canon EOS R5")
    #expect(PhotoInfo(properties: sony, pixelSize: size, fileSize: nil).camera == "SONY ILCE-6400")
}

@Test func aspectRatioUsesTheNamedRatioClosestToTheSensorShape() {
    func label(_ width: Double, _ height: Double) -> String {
        PhotoInfo(properties: [:], pixelSize: CGSize(width: width, height: height), fileSize: nil).ratioLabel
    }

    #expect(label(6048, 4024) == "3:2")
    #expect(label(4000, 6000) == "2:3")
    #expect(label(4000, 4000) == "1:1")
    #expect(label(7000, 3000) == "2.33:1")
}

@Test func photoWithoutMetadataHasOnlyItsSize() {
    let info = PhotoInfo(properties: [:], pixelSize: size, fileSize: nil)

    #expect(info.takenAt == nil && info.camera == nil && info.latitude == nil && info.place == nil)
    #expect(info.megapixels == 24)
}
