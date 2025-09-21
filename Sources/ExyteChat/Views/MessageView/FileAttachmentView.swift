//
//  FileAttachmentView.swift
//  Chat
//
//  Created by Nihed Majdoub on 01/09/2025.
//

import SwiftUI

public struct FileAttachmentView: View {
    
    @State private var fullScreenShown = false
    
    let file: FileAttachment
    let width: CGFloat
    let isCurrentUser: Bool
    let font: UIFont
    
    public var body: some View {
        HStack {
            FileAttachmentDisplayView(
                url: file.url,
                title: file.url.lastPathComponent,
                sizeString: file.sizeString,
                isCurrentUser: isCurrentUser,
                font: font
                
            )
            Spacer()
        }
        .padding(.all, 8)
        .frame(maxWidth: width)
        .accessibilityIdentifier("FileAttachmentView")
    }
}

public struct FileAttachment: Hashable, Codable {
    
    public let id: String
    public let url: URL
    public let size: Int64
    
    static let sizeFormatter = ByteCountFormatter()
    
    public var mimeType: String {
        type.mimeType
    }
    
    public var sizeString: String {
        Self.sizeFormatter.string(fromByteCount: size)
    }
    
    public var type: AttachmentFileType {
        AttachmentFileType(ext: url.pathExtension)
    }
    
   public init(
        id: String,
        url: URL,
    ) {
        self.id = id
        self.url = url
        
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.size = attributes?[.size] as? Int64 ?? 0
    }
}

public struct FileAttachmentDisplayView: View {
    
    @Environment(\.chatTheme) var theme
    
    let url: URL
    let title: String
    let sizeString: String
    let isCurrentUser: Bool
    let font: UIFont
    
    public var body: some View {
        HStack {
            theme.images.message.attachedDocument
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Font(font))
                    .lineLimit(1)
                    .foregroundColor(theme.colors.messageText(isCurrentUser ? .current : .other))
                Text(sizeString)
                    .font(.footnote)
                    .lineLimit(1)
                    .foregroundColor(theme.colors.messageText(isCurrentUser ? .current : .other))
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

public enum AttachmentFileType: String, Codable, Equatable, CaseIterable {
    /// File
    case generic, doc, docx, pdf, ppt, pptx, tar, xls, zip, x7z, xz, ods, odt, xlsx
    /// Text
    case csv, rtf, txt
    /// Audio
    case mp3, wav, ogg, m4a, aac, mp4
    /// Video
    case mov, avi, wmv, webm
    /// Image
    case jpeg, png, gif, bmp, webp
    /// Unknown
    case unknown
    
    private static let mimeTypes: [String: AttachmentFileType] = [
        "application/octet-stream": .generic,
        "application/msword": .doc,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": .docx,
        "application/pdf": .pdf,
        "application/vnd.ms-powerpoint": .ppt,
        "application/vnd.openxmlformats-officedocument.presentationml.presentation": .pptx,
        "application/x-tar": .tar,
        "application/vnd.ms-excel": .xls,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": .xlsx,
        "application/zip": .zip,
        "application/x-7z-compressed": .x7z,
        "application/x-xz": .xz,
        "application/vnd.oasis.opendocument.spreadsheet": .ods,
        "application/vnd.oasis.opendocument.text": .odt,
        "text/csv": .csv,
        "text/rtf": .rtf,
        "text/plain": .txt,
        "audio/mp3": .mp3,
        "audio/mp4": .m4a,
        "audio/aac": .aac,
        "audio/wav": .wav,
        "audio/ogg": .ogg,
        "video/mp4": .mp4,
        "video/quicktime": .mov,
        "video/x-msvideo": .avi,
        "video/x-ms-wmv": .wmv,
        "video/webm": .webm,
        "image/jpeg": .jpeg,
        "image/jpg": .jpeg,
        "image/png": .png,
        "image/gif": .gif,
        "image/bmp": .bmp,
        "image/webp": .webp
    ]
    
    /// Init an attachment file type by mime type.
    ///
    /// - Parameter mimeType: a mime type.
    public init(mimeType: String) {
        self = AttachmentFileType.mimeTypes[mimeType, default: .generic]
    }
    
    /// Init an attachment file type by a file extension.
    ///
    /// - Parameter ext: a file extension.
    public init(ext: String) {
        // We've seen that iOS sometimes uppercases the filename (and also extension)
        // which breaks our file type detection code.
        // We lowercase it for extra safety
        let ext = ext.lowercased()
        
        if ext == "jpg" {
            self = .jpeg
            return
        }
        
        if ext == "7z" {
            self = .x7z
            return
        }
        
        self = AttachmentFileType(rawValue: ext) ?? .generic
    }
    
    /// Returns a mime type for the file type.
    public var mimeType: String {
        if self == .jpeg {
            return "image/jpeg"
        }
        
        return AttachmentFileType.mimeTypes
            .first(where: { $1 == self })?
            .key ?? "application/octet-stream"
    }
    
    public var isAudio: Bool {
        switch self {
        case .mp3, .wav, .ogg, .m4a, .aac:
            return true
        default:
            return false
        }
    }
    
    public var isUnknown: Bool {
        self == .unknown
    }
}
