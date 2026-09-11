import CoreGraphics
import Foundation
import ImageIO

/// Fabrique de petites images en memoire pour les tests d'import, afin de ne jamais
/// embarquer de fichier binaire dans le depot (consigne de la phase 9).
enum ImageFixtures {
    /// Construit un `CGImage` uni d'une couleur, de la taille demandee.
    static func makeCGImage(width: Int, height: Int, hasAlpha: Bool = false) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGImageAlphaInfo = hasAlpha ? .premultipliedLast : .noneSkipLast
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )
        else {
            preconditionFailure("Impossible de creer un CGContext de test.")
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: hasAlpha ? 0.5 : 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            preconditionFailure("Impossible de fabriquer l'image de test.")
        }
        return image
    }

    /// Encode une image en PNG.
    static func pngData(width: Int, height: Int, hasAlpha: Bool = false) -> Data {
        encode(makeCGImage(width: width, height: height, hasAlpha: hasAlpha), uti: "public.png")
    }

    /// Encode une image en JPEG (jamais de canal alpha, format sans transparence).
    static func jpegData(width: Int, height: Int, quality: CGFloat = 0.9) -> Data {
        encode(
            makeCGImage(width: width, height: height, hasAlpha: false),
            uti: "public.jpeg",
            quality: quality
        )
    }

    /// Encode une image en GIF (une seule frame, suffisant pour verifier la
    /// non-recompression : peu importe qu'elle soit animee ou non).
    static func gifData(width: Int, height: Int) -> Data {
        encode(makeCGImage(width: width, height: height, hasAlpha: false), uti: "com.compuserve.gif")
    }

    private static func encode(_ image: CGImage, uti: String, quality: CGFloat = 1) -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, uti as CFString, 1, nil) else {
            preconditionFailure("Impossible de creer le CGImageDestination de test.")
        }
        let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            preconditionFailure("Impossible de finaliser l'image de test.")
        }
        return mutableData as Data
    }
}
