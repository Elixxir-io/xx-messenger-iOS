import Models
import XXModels
import Foundation

extension Session {
    public func join(group: Group) throws {
        guard let manager = client.groupManager else { fatalError("A group manager was not created") }

        try manager.join(group.serialized)
        var group = group
        group.authStatus = .participating
        scanStrangers {}
        try dbManager.saveGroup(group)
    }

    public func leave(group: Group) throws {
        guard let manager = client.groupManager else { fatalError("A group manager was not created") }
        try manager.leave(group.id)
        try dbManager.deleteGroup(group)
    }

    public func createGroup(
        name: String,
        welcome: String?,
        members: [Contact],
        _ completion: @escaping (Result<GroupInfo, Error>) -> Void
    ) {
        guard let manager = client.groupManager else {
            fatalError("A group manager was not created")
        }

        manager.create(
            me: myId,
            name: name,
            welcome: welcome,
            with: members.map { $0.id }) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let group):
                try! self.dbManager.saveGroup(group)

                members
                    .map { GroupMember(groupId: group.id, contactId: $0.id) }
                    .forEach { try! self.dbManager.saveGroupMember($0) }

                // TODO: Add saveBulkGroupMembers to the database

                if let welcome = welcome {
                    let message = Message(
                        networkId: nil,
                        senderId: self.myId,
                        recipientId: nil,
                        groupId: group.id,
                        date: group.createdAt,
                        status: .sent,
                        isUnread: false,
                        text: welcome,
                        replyMessageId: nil,
                        roundURL: nil,
                        fileTransferId: nil
                    )

                    try! self.dbManager.saveMessage(message)
                }

                let query = GroupInfo.Query(groupId: group.id)
                let info = try! self.dbManager.fetchGroupInfos(query).first
                completion(.success(info!))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    func processGroupCreation(_ group: Group, memberIds: [Data], welcome: String?) -> GroupInfo {
        /// Save the group
        ///
        _ = try! dbManager.saveGroup(group)

        /// Which of those members are not my friends?
        ///
        let friendsParticipating = try! dbManager.fetchContacts(Contact.Query(id: Set(memberIds)))

        /// Save the strangers as contacts
        ///
        let friendIds = friendsParticipating.map(\.id)
        memberIds.forEach {
            if !friendIds.contains($0) {
                try! dbManager.saveContact(.init(
                    id: $0,
                    marshaled: nil,
                    username: nil,
                    email: nil,
                    phone: nil,
                    nickname: nil,
                    photo: nil,
                    authStatus: .stranger,
                    isRecent: false,
                    createdAt: Date()
                ))
            }
        }

        /// Save group members relation
        ///
        memberIds.forEach {
            try! dbManager.saveGroupMember(.init(groupId: group.id, contactId: $0))
        }

        /// Save the welcome message (if any)
        ///
        if let welcome = welcome {
            _ = try! dbManager.saveMessage(.init(
                networkId: nil,
                senderId: group.leaderId,
                recipientId: nil,
                groupId: group.id,
                date: group.createdAt,
                status: .received,
                isUnread: true,
                text: welcome,
                replyMessageId: nil,
                roundURL: nil,
                fileTransferId: nil
            ))
        }


        if inappnotifications {
            DeviceFeedback.sound(.contactAdded)
            DeviceFeedback.shake(.notification)
        }

        scanStrangers {}

        let info = try! dbManager.fetchGroupInfos(.init(groupId: group.id)).first
        return info!
    }
}

// MARK: - GroupMessages

extension Session {
    public func send(_ payload: Payload, toGroup group: Group) {
        var message = Message(
            senderId: client.bindings.myId,
            recipientId: nil,
            groupId: group.id,
            date: Date(),
            status: .sending,
            isUnread: false,
            text: payload.text,
            replyMessageId: payload.reply?.messageId,
            roundURL: nil,
            fileTransferId: nil
        )

        do {
            message = try dbManager.saveMessage(message)
            send(groupMessage: message)
        } catch {
            log(string: error.localizedDescription, type: .error)
        }
    }

    func send(groupMessage: Message) {
        guard let manager = client.groupManager else { fatalError("A group manager was not created") }
        var message = groupMessage

        var reply: Reply?
        if let replyId = message.replyMessageId,
           let replyMessage = try? dbManager.fetchMessages(Message.Query(networkId: replyId)).first {
            reply = Reply(messageId: replyId, senderId: replyMessage.senderId)
        }

        let payloadData = Payload(text: message.text, reply: reply).asData()

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            switch manager.send(payloadData, to: message.groupId!) {
            case .success((let roundId, let uniqueId, let roundURL)):
                message.roundURL = roundURL

                self.client.bindings.listenRound(id: Int(roundId)) { result in
                    switch result {
                    case .success(let succeeded):
                        message.networkId = uniqueId
                        message.status = succeeded ? .sent : .sendingFailed
                    case .failure:
                        message.status = .sendingFailed
                    }

                    do {
                        try self.dbManager.saveMessage(message)
                    } catch {
                        log(string: error.localizedDescription, type: .error)
                    }
                }
            case .failure:
                message.status = .sendingFailed
            }

            do {
                try self.dbManager.saveMessage(message)
            } catch {
                log(string: error.localizedDescription, type: .error)
            }
        }
    }

    public func scanStrangers(_ completion: @escaping () -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self,
                  let ud = self.client.userDiscovery,
                  let strangers = try? self.dbManager.fetchContacts(.init(username: .some(nil))),
                  !strangers.isEmpty else { return }

            ud.lookup(idList: strangers.map(\.id)) { result in
                switch result {
                case .success(let strangersWithUsernames):
                    let acquaintances = strangers.map { stranger -> Contact in
                        var exStranger = stranger
                        exStranger.username = strangersWithUsernames.first(where: { $0.id == stranger.id })?.username
                        return exStranger
                    }

                    DispatchQueue.main.async {
                        acquaintances.forEach { _ = try? self.dbManager.saveContact($0) }
                    }

                    completion()
                case .failure(let error):
                    print(error.localizedDescription)
                    DispatchQueue.main.async { completion() }
                }
            }
        }
    }
}
