import AppKit

class OverlayWindow: NSPanel {
  var text: String {
    get {
      if let contentView = contentView as? OverlayContentView {
        return contentView.text
      }
      return ""
    }
    set {
      if let contentView = contentView as? OverlayContentView {
        contentView.text = newValue
      }
    }
  }

  var leadingMargin: CGFloat {
    get {
      if let contentView = contentView as? OverlayContentView {
        return contentView.leadingMargin
      }
      return 0
    }
    set {
      if let contentView = contentView as? OverlayContentView {
        contentView.leadingMargin = newValue
      }
    }
  }

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.closable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isFloatingPanel = true
    level = .floating

    collectionBehavior.insert(.fullScreenAuxiliary)

    titleVisibility = .hidden
    titlebarAppearsTransparent = true

    isMovableByWindowBackground = false

    isReleasedWhenClosed = false

    hidesOnDeactivate = false
    
    hasShadow = false

    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    ignoresMouseEvents = true

    isOpaque = false
    backgroundColor = .clear

    contentView = OverlayContentView()
  }

  override var canBecomeKey: Bool {
    return false
  }

  override var canBecomeMain: Bool {
    return false
  }
}

fileprivate class OverlayContentView: NSView {
  var text: String = "" {
    didSet {
      textLabel.stringValue = text
      adjustFontSizeToFit()
    }
  }
  private let textLabel = NSTextField(wrappingLabelWithString: "")
  private let defaultFont: NSFont = .systemFont(ofSize: 16)
  var leadingMargin: CGFloat = 0 {
    didSet {
      leadingConstraint?.constant = leadingMargin
    }
  }
  private var leadingConstraint: NSLayoutConstraint?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    let containerView = NSView()
    containerView.wantsLayer = true
    containerView.layer?.backgroundColor = .white

    containerView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(containerView)

    let leadingConstraint = containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingMargin)
    NSLayoutConstraint.activate([
      containerView.topAnchor.constraint(equalTo: topAnchor),
      leadingConstraint,
      containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    self.leadingConstraint = leadingConstraint

    textLabel.translatesAutoresizingMaskIntoConstraints = true
    containerView.addSubview(textLabel)

    textLabel.font = defaultFont
    textLabel.backgroundColor = .clear
    textLabel.drawsBackground = false

    textLabel.autoresizingMask = [.width, .height]
    textLabel.frame = containerView.bounds
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  func adjustFontSizeToFit() {
    let minimumFontSize: CGFloat = 9

    var containerSize = bounds.size
    containerSize.width -= leadingMargin
    containerSize.height = .greatestFiniteMagnitude

    var font = defaultFont
    var fontSize = font.pointSize
    var boundingRect: CGRect = .infinite

    repeat {
      font = font.withSize(fontSize)

      boundingRect = NSString(string: text).boundingRect(
        with: containerSize,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font]
      )
      fontSize -= 0.5
    } while boundingRect.height > bounds.height && fontSize >= minimumFontSize

    textLabel.font = font
  }
}
