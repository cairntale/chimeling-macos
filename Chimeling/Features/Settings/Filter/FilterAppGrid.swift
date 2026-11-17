import AppKit
import SwiftUI

/// The row is 440pt wide inside the fixed 500pt settings window, so four columns fill it.
/// The grouped form is already the scroller, so this view does not nest another one.
struct FilterAppGrid: NSViewRepresentable {
    var identifiers: [String]
    @Binding var selection: Set<String>
    var onDrop: ([URL]) -> Void
    var onRemoveSelection: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, onDrop: onDrop, onRemoveSelection: onRemoveSelection)
    }

    func makeNSView(context: Context) -> FilterAppCollectionView {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 104, height: Metrics.itemHeight)
        layout.minimumInteritemSpacing = Metrics.spacing
        layout.minimumLineSpacing = Metrics.spacing
        layout.sectionInset = NSEdgeInsetsZero

        let view = FilterAppCollectionView()
        view.collectionViewLayout = layout
        view.isSelectable = true
        view.allowsMultipleSelection = true
        view.backgroundColors = []
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        view.register(FilterAppItem.self, forItemWithIdentifier: FilterAppItem.reuseIdentifier)
        view.registerForDraggedTypes([.fileURL])
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let remove = NSMenuItem(title: "Remove", action: #selector(Coordinator.removeSelection(_:)), keyEquivalent: "")
        remove.target = context.coordinator
        let menu = NSMenu()
        menu.addItem(remove)
        view.itemMenu = menu
        return view
    }

    func updateNSView(_ view: FilterAppCollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.identifiers = identifiers
        coordinator.selection = $selection
        coordinator.onDrop = onDrop
        coordinator.onRemoveSelection = onRemoveSelection
        view.onRemoveSelection = onRemoveSelection

        if coordinator.rendered != identifiers {
            coordinator.rendered = identifiers
            view.reloadData()
        }

        let paths = Set(identifiers.enumerated().compactMap { index, identifier in
            selection.contains(identifier) ? IndexPath(item: index, section: 0) : nil
        })
        guard view.selectionIndexPaths != paths else { return }
        coordinator.applyingSelection = true
        view.selectionIndexPaths = paths
        coordinator.applyingSelection = false
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FilterAppCollectionView, context: Context) -> CGSize? {
        let width = proposal.width ?? 0
        guard width > 0 else { return CGSize(width: 0, height: Metrics.minimumHeight) }
        nsView.frame.size.width = width
        nsView.collectionViewLayout?.invalidateLayout()
        nsView.layoutSubtreeIfNeeded()
        let contentHeight = nsView.collectionViewLayout?.collectionViewContentSize.height ?? 0
        return CGSize(width: width, height: max(Metrics.minimumHeight, contentHeight))
    }

    private enum Metrics {
        static let columns: CGFloat = 4
        static let spacing: CGFloat = 8
        static let itemHeight: CGFloat = 108
        static let minimumHeight: CGFloat = 180
    }

    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout {
        var identifiers: [String] = []
        var rendered: [String] = []
        var selection: Binding<Set<String>>
        var onDrop: ([URL]) -> Void
        var onRemoveSelection: () -> Void
        var applyingSelection = false

        init(selection: Binding<Set<String>>, onDrop: @escaping ([URL]) -> Void, onRemoveSelection: @escaping () -> Void) {
            self.selection = selection
            self.onDrop = onDrop
            self.onRemoveSelection = onRemoveSelection
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            identifiers.count
        }

        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
            let item = collectionView.makeItem(withIdentifier: FilterAppItem.reuseIdentifier, for: indexPath)
            if let item = item as? FilterAppItem, identifiers.indices.contains(indexPath.item) {
                item.configure(identifiers[indexPath.item])
            }
            return item
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> NSSize {
            let gaps = Metrics.spacing * (Metrics.columns - 1)
            let itemWidth = floor((collectionView.bounds.width - gaps) / Metrics.columns)
            return NSSize(width: max(itemWidth, 1), height: Metrics.itemHeight)
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            publishSelection(of: collectionView)
        }

        func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
            publishSelection(of: collectionView)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            validateDrop draggingInfo: any NSDraggingInfo,
            proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
            dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
        ) -> NSDragOperation {
            guard draggedApps(from: draggingInfo) != nil else { return [] }
            proposedDropOperation.pointee = .on
            return .copy
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            acceptDrop draggingInfo: any NSDraggingInfo,
            indexPath: IndexPath,
            dropOperation: NSCollectionView.DropOperation
        ) -> Bool {
            guard let apps = draggedApps(from: draggingInfo) else { return false }
            onDrop(apps)
            return true
        }

        @objc func removeSelection(_ sender: Any?) {
            onRemoveSelection()
        }

        private func publishSelection(of collectionView: NSCollectionView) {
            guard !applyingSelection else { return }
            let selected = Set(collectionView.selectionIndexPaths.compactMap { indexPath -> String? in
                guard identifiers.indices.contains(indexPath.item) else { return nil }
                return identifiers[indexPath.item]
            })
            guard selection.wrappedValue != selected else { return }
            selection.wrappedValue = selected
        }

        private func draggedApps(from draggingInfo: NSDraggingInfo) -> [URL]? {
            let urls = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL]
            let apps = urls?.filter { AppBundle.identifier(at: $0) != nil } ?? []
            return apps.isEmpty ? nil : apps
        }
    }
}

final class FilterAppCollectionView: NSCollectionView {
    var onRemoveSelection: (() -> Void)?
    var itemMenu: NSMenu?
    private var keyWindowObservers: [NSObjectProtocol] = []

    deinit {
        stopObservingKeyWindow()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeKeyWindow()
        refreshSelectionAppearance()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let indexPath = indexPathForItem(at: point) else { return nil }
        if !selectionIndexPaths.contains(indexPath) {
            selectionIndexPaths = [indexPath]
        }
        return itemMenu
    }

    override func keyDown(with event: NSEvent) {
        switch event.specialKey {
        case .delete, .deleteForward:
            onRemoveSelection?()
        default:
            super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { refreshSelectionAppearance() }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { refreshSelectionAppearance() }
        return resigned
    }

    private func refreshSelectionAppearance() {
        for indexPath in indexPathsForVisibleItems() {
            (item(at: indexPath) as? FilterAppItem)?.applySelectionAppearance()
        }
    }

    private func observeKeyWindow() {
        stopObservingKeyWindow()
        guard let window else { return }
        keyWindowObservers = [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refreshSelectionAppearance()
                }
            }
        }
    }

    private func stopObservingKeyWindow() {
        for observer in keyWindowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        keyWindowObservers.removeAll()
    }
}

final class FilterAppItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("FilterAppItem")

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        let image = NSImageView()
        image.imageScaling = .scaleProportionallyDown
        image.imageAlignment = .alignCenter
        image.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(wrappingLabelWithString: "")
        name.isSelectable = false
        name.alignment = .center
        name.maximumNumberOfLines = 2
        name.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        name.translatesAutoresizingMaskIntoConstraints = false
        if let cell = name.cell as? NSTextFieldCell {
            cell.truncatesLastVisibleLine = true
        }

        container.addSubview(image)
        container.addSubview(name)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            image.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            image.widthAnchor.constraint(equalToConstant: 64),
            image.heightAnchor.constraint(equalToConstant: 64),
            name.topAnchor.constraint(equalTo: image.bottomAnchor, constant: 4),
            name.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            name.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            name.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -4),
        ])

        view = container
        imageView = image
        textField = name
    }

    func configure(_ identifier: String) {
        let source = AppBundle.icon(for: identifier)
        let icon = source.copy() as? NSImage ?? source
        icon.size = NSSize(width: 64, height: 64)
        imageView?.image = icon
        textField?.stringValue = AppBundle.name(for: identifier)
        applySelectionAppearance()
    }

    override var isSelected: Bool {
        didSet { applySelectionAppearance() }
    }

    func applySelectionAppearance() {
        let emphasized = isSelected
            && collectionView?.isFirstResponder == true
            && collectionView?.window?.isKeyWindow == true
        view.layer?.cornerRadius = 6
        view.layer?.backgroundColor = emphasized
            ? NSColor.selectedContentBackgroundColor.cgColor
            : (isSelected ? NSColor.unemphasizedSelectedContentBackgroundColor.cgColor : nil)
        textField?.textColor = emphasized ? .alternateSelectedControlTextColor : .labelColor
    }
}
