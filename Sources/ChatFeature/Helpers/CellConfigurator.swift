import UIKit
import Shared
import Combine
import XXModels
import Voxophone
import AVFoundation

struct CellFactory {
    var canBuild: (Message) -> Bool

    var build: (Message, UICollectionView, IndexPath) -> UICollectionViewCell

    func callAsFunction(
        item: Message,
        collectionView: UICollectionView,
        indexPath: IndexPath
    ) -> UICollectionViewCell {
        build(item, collectionView, indexPath)
    }
}

extension CellFactory {
    static func combined(factories: [CellFactory]) -> Self {
        .init(
            canBuild: { _ in true },
            build: { item, collectionView, indexPath in
                guard let factory = factories.first(where: { $0.canBuild(item)}) else {
                    fatalError("Couldn't find a factory for \(item). Did you forget to implement?")
                }

                return factory(
                    item: item,
                    collectionView: collectionView,
                    indexPath: indexPath
                )
            }
        )
    }
}

extension CellFactory {
    static func incomingAudio(
        voxophone: Voxophone,
        transfer: @escaping (Data) -> FileTransfer
    ) -> Self {
        .init(
            canBuild: { item in
                guard (item.status == .received || item.status == .receiving),
                      item.replyMessageId == nil,
                      item.fileTransferId != nil else { return false }

                return transfer(item.fileTransferId!).type == "m4a"

            }, build: { item, collectionView, indexPath in
                let ft = transfer(item.fileTransferId!)
                let cell: IncomingAudioCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                let url = FileManager.url(for: "\(ft.name).\(ft.type)")!

                var model = AudioMessageCellState(
                    date: item.date,
                    audioURL: url,
                    isPlaying: false,
                    transferProgress: ft.progress,
                    isLoudspeaker: false,
                    duration: (try? AVAudioPlayer(contentsOf: url).duration) ?? 0.0,
                    playbackTime: 0.0
                )

                cell.leftView.setup(with: model)
                cell.canReply = false
                cell.performReply = {}

                Bubbler.build(audioBubble: cell.leftView, with: item)

                voxophone.$state
                    .sink {
                        switch $0 {
                        case .playing(url, _, time: let time, _):
                            model.isPlaying = true
                            model.playbackTime = time
                        default:
                            model.isPlaying = false
                            model.playbackTime = 0.0
                        }

                        model.isLoudspeaker = $0.isLoudspeaker

                        cell.leftView.setup(with: model)
                    }.store(in: &cell.leftView.cancellables)

                cell.leftView.didTapRight = {
                    guard item.status != .receiving else { return }

                    voxophone.toggleLoudspeaker()
                }

                cell.leftView.didTapLeft = {
                    guard item.status != .receiving else { return }

                    if case .playing(url, _, _, _) = voxophone.state {
                        voxophone.reset()
                    } else {
                        voxophone.load(url)
                        voxophone.play()
                    }
                }

                return cell
            }
        )
    }

    static func outgoingAudio(
        voxophone: Voxophone,
        transfer: @escaping (Data) -> FileTransfer
    ) -> Self {
        .init(
            canBuild: { item in
                guard (item.status == .sent ||
                       item.status == .sending ||
                       item.status == .sendingFailed ||
                       item.status == .sendingTimedOut)
                        && item.replyMessageId == nil
                        && item.fileTransferId != nil else {
                    return false
                }

                return transfer(item.fileTransferId!).type == "m4a"

            }, build: { item, collectionView, indexPath in
                let ft = transfer(item.fileTransferId!)
                let cell: OutgoingAudioCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                let url = FileManager.url(for: "\(ft.name).\(ft.type)")!
                var model = AudioMessageCellState(
                    date: item.date,
                    audioURL: url,
                    isPlaying: false,
                    transferProgress: ft.progress,
                    isLoudspeaker: false,
                    duration: (try? AVAudioPlayer(contentsOf: url).duration) ?? 0.0,
                    playbackTime: 0.0
                )

                cell.rightView.setup(with: model)
                cell.canReply = false
                cell.performReply = {}

                Bubbler.build(audioBubble: cell.rightView, with: item)

                voxophone.$state
                    .sink {
                        switch $0 {
                        case .playing(url, _, time: let time, _):
                            model.isPlaying = true
                            model.playbackTime = time
                        default:
                            model.isPlaying = false
                            model.playbackTime = 0.0
                        }

                        model.isLoudspeaker = $0.isLoudspeaker

                        cell.rightView.setup(with: model)
                    }.store(in: &cell.rightView.cancellables)

                cell.rightView.didTapRight = {
                    voxophone.toggleLoudspeaker()
                }

                cell.rightView.didTapLeft = {
                    if case .playing(url, _, _, _) = voxophone.state {
                        voxophone.reset()
                    } else {
                        voxophone.load(url)
                        voxophone.play()
                    }
                }

                return cell
            }
        )
    }
}

extension CellFactory {
    static func outgoingImage(
        transfer:  @escaping (Data) -> FileTransfer
    ) -> Self {
        .init(
            canBuild: { item in
                guard (item.status == .sent ||
                       item.status == .sending ||
                       item.status == .sendingFailed ||
                       item.status == .sendingTimedOut)
                        && item.replyMessageId == nil
                        && item.fileTransferId != nil else {
                    return false
                }

                return transfer(item.fileTransferId!).type == "jpeg"

            }, build: { item, collectionView, indexPath in
                let ft = transfer(item.fileTransferId!)
                let cell: OutgoingImageCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.build(imageBubble: cell.rightView, with: item, with: transfer(item.fileTransferId!))
                cell.canReply = false
                cell.performReply = {}

                if let image = UIImage(data: ft.data!) {
                    cell.rightView.imageView.image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .up)
                }

                return cell
            }
        )
    }

    static func incomingImage(
        transfer: @escaping (Data) -> FileTransfer
    ) -> Self {
        .init(
            canBuild: { item in
                guard (item.status == .received || item.status == .receiving)
                        && item.replyMessageId == nil
                        && item.fileTransferId != nil else {
                    return false
                }

                return transfer(item.fileTransferId!).type == "jpeg"

            }, build: { item, collectionView, indexPath in
                let ft = transfer(item.fileTransferId!)
                let cell: IncomingImageCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.build(imageBubble: cell.leftView, with: item, with: ft)
                cell.canReply = false
                cell.performReply = {}

                if let data = ft.data {
                    cell.leftView.imageView.image = UIImage(data: data)
                } else {
                    cell.leftView.imageView.image = Asset.transferImagePlaceholder.image
                }

                return cell
            }
        )
    }
}

extension CellFactory {
    static func outgoingReply(
        performReply: @escaping () -> Void,
        replyContent: @escaping (Data) -> (String, String),
        showRound: @escaping (String?) -> Void
    ) -> Self {
        .init(
            canBuild: { item in
                (item.status == .sent || item.status == .sending)
                && item.replyMessageId != nil

            }, build: { item, collectionView, indexPath in
                let cell: OutgoingReplyCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.buildReply(
                    bubble: cell.rightView,
                    with: item,
                    reply: replyContent(item.replyMessageId!)
                )

                cell.canReply = item.status == .sent
                cell.performReply = performReply
                cell.rightView.didTapShowRound = { showRound(item.roundURL) }
                return cell
            }
        )
    }

    static func incomingReply(
        performReply: @escaping () -> Void,
        replyContent: @escaping (Data) -> (String, String),
        showRound: @escaping (String?) -> Void
    ) -> Self {
        .init(
            canBuild: { item in
                item.status == .received
                && item.replyMessageId != nil

            }, build: { item, collectionView, indexPath in
                let cell: IncomingReplyCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.buildReply(
                    bubble: cell.leftView,
                    with: item,
                    reply: replyContent(item.replyMessageId!)
                )
                cell.canReply = item.status == .received
                cell.performReply = performReply
                cell.leftView.didTapShowRound = { showRound(item.roundURL) }
                cell.leftView.revertBottomStackOrder()
                return cell
            }
        )
    }

    static func outgoingFailedReply(
        performReply: @escaping () -> Void,
        replyContent: @escaping (Data) -> (String, String)
    ) -> Self {
        .init(
            canBuild: { item in
                (item.status == .sendingFailed || item.status == .sendingTimedOut)
                && item.replyMessageId != nil

            }, build: { item, collectionView, indexPath in
                let cell: OutgoingFailedReplyCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.buildReply(
                    bubble: cell.rightView,
                    with: item,
                    reply: replyContent(item.replyMessageId!)
                )

                cell.canReply = false
                cell.performReply = performReply
                return cell
            }
        )
    }
}

extension CellFactory {
    static func incomingText(
        performReply: @escaping () -> Void,
        showRound: @escaping (String?) -> Void
    ) -> Self {
        .init(
            canBuild: { item in
                item.status == .received
                && item.replyMessageId == nil

            }, build: { item, collectionView, indexPath in
                let cell: IncomingTextCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.build(bubble: cell.leftView, with: item)
                cell.canReply = item.status == .received
                cell.performReply = performReply
                cell.leftView.didTapShowRound = { showRound(item.roundURL) }
                cell.leftView.revertBottomStackOrder()
                return cell
            }
        )
    }

    static func outgoingText(
        performReply: @escaping () -> Void,
        showRound: @escaping (String?) -> Void
    ) -> Self {
        .init(
            canBuild: { item in
                (item.status == .sending || item.status == .sent)
                && item.replyMessageId == nil

            }, build: { item, collectionView, indexPath in
                let cell: OutgoingTextCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.build(bubble: cell.rightView, with: item)
                cell.canReply = item.status == .sent
                cell.performReply = performReply
                cell.rightView.didTapShowRound = { showRound(item.roundURL) }

                return cell
            }
        )
    }

    static func outgoingFailedText(performReply: @escaping () -> Void) -> Self {
        .init(
            canBuild: { item in
                (item.status == .sendingFailed || item.status == .sendingTimedOut)
                && item.replyMessageId == nil

            }, build: { item, collectionView, indexPath in
                let cell: OutgoingFailedTextCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)

                Bubbler.build(bubble: cell.rightView, with: item)
                cell.canReply = false
                cell.performReply = performReply
                return cell
            }
        )
    }
}

struct ActionFactory {
    enum Action {
        case copy
        case retry
        case reply
        case delete
        case report

        var title: String {
            switch self {

            case .copy:
                return Localized.Chat.BubbleMenu.copy
            case .retry:
                return Localized.Chat.BubbleMenu.retry
            case .reply:
                return Localized.Chat.BubbleMenu.reply
            case .delete:
                return Localized.Chat.BubbleMenu.delete
            case .report:
                return Localized.Chat.BubbleMenu.report
            }
        }
    }

    static func build(
        from item: Message,
        action: Action,
        closure: @escaping (Message) -> Void
    ) -> UIAction? {

        switch action {
        case .report:
            guard item.status == .received else { return nil }
        case .reply:
            guard item.status == .received || item.status == .sent else { return nil }
        case .retry:
            guard item.status == .sendingFailed || item.status == .sendingTimedOut else { return nil }
        case .delete, .copy:
            break
        }

        return UIAction(
            title: action.title,
            state: .off,
            handler: { _ in closure(item) }
        )
    }
}
