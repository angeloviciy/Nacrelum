import Cocoa

final class AboutWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        configureWindow(window)
    }

    private func configureWindow(_ window: NSWindow) {
        window.title = "About"
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.documentIconButton)?.isHidden = true
        window.standardWindowButton(.documentVersionsButton)?.isHidden = true
        window.center()

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        // App icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = NSApp.applicationIconImage
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 16
        iconView.layer?.masksToBounds = true
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80)
        ])

        let titleLabel = NSTextField(labelWithString: AppMetadata.projectName)
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.alignment = .center

        let versionLabel = NSTextField(labelWithString: "Version \(AppMetadata.displayVersion)")
        versionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.alignment = .center

        let descriptionLabel = NSTextField(labelWithString: "A tiny animated pet that lives on your Dock.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .center

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let creditField = NSTextField(labelWithAttributedString: creditString())
        creditField.allowsEditingTextAttributes = true
        creditField.isSelectable = true
        creditField.drawsBackground = false
        creditField.isBordered = false
        creditField.alignment = .center

        let sourceLinkField = NSTextField(labelWithAttributedString: sourceLinkString())
        sourceLinkField.allowsEditingTextAttributes = true
        sourceLinkField.isSelectable = true
        sourceLinkField.drawsBackground = false
        sourceLinkField.isBordered = false
        sourceLinkField.alignment = .center

        let stack = NSStackView(views: [
            iconView, titleLabel, versionLabel, descriptionLabel,
            separator, creditField, sourceLinkField
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(12, after: iconView)
        stack.setCustomSpacing(2, after: titleLabel)
        stack.setCustomSpacing(10, after: versionLabel)
        stack.setCustomSpacing(16, after: descriptionLabel)
        stack.setCustomSpacing(12, after: separator)
        stack.setCustomSpacing(4, after: creditField)

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 24)
        ])
    }

    private func creditString() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSMutableAttributedString(
            string: "Created by ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: style
            ]
        )
        text.append(NSAttributedString(
            string: "Ron Masas",
            attributes: [
                .link: AppMetadata.creatorURL,
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.linkColor,
                .paragraphStyle: style
            ]
        ))
        return text
    }

    private func sourceLinkString() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return NSAttributedString(
            string: AppMetadata.sourceCodeURL.absoluteString,
            attributes: [
                .link: AppMetadata.sourceCodeURL,
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.linkColor,
                .paragraphStyle: style
            ]
        )
    }
}
