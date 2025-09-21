//
//  Created by Alex.M on 17.06.2022.
//

import Foundation
import GiphyUISDK
import ExyteMediaPicker

public struct DraftMessage: Sendable {
    public var id: String?
    public let text: String
    public let medias: [Media]
    public let giphyMedia: GPHMedia?
    public let recording: Recording?
    public let replyMessage: ReplyMessage?
    public let createdAt: Date
    public var fileAttachment: FileAttachment?

    public init(id: String? = nil,
                text: String,
                medias: [Media],
                giphyMedia: GPHMedia?,
                recording: Recording?,
                replyMessage: ReplyMessage?,
                createdAt: Date,
                fileAttachment: FileAttachment?) {
        self.id = id
        self.text = text
        self.medias = medias
        self.giphyMedia = giphyMedia
        self.recording = recording
        self.replyMessage = replyMessage
        self.createdAt = createdAt
        self.fileAttachment = fileAttachment
    }
}

