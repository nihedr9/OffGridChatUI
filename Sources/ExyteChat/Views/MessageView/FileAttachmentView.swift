//
//  FileAttachmentView.swift
//  Chat
//
//  Created by Nihed Majdoub on 01/09/2025.
//

import SwiftUI

public struct FileAttachmentView: View {

    @State private var fullScreenShown = false

    let url: URL
    let width: CGFloat
    let isCurrentUser: Bool
    let font: UIFont

    public var body: some View {
        HStack {
            FileAttachmentDisplayView(
                url: url,
                title: "attachment.title" ?? "",
                sizeString: "attachment.file.sizeString",
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
