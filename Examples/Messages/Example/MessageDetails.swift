//
//  MessageDetails.swift
//  Messages
//
//  Created by Måns Bernhardt on 2018-04-19.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Flow
import Presentation

struct MessageDetails {
    let message: Message
    let delete: Presentation<Alert<()>>
}

extension MessageDetails: Presentable {
    func materialize() -> (UIViewController, Disposable) {
        // Setup view controller and views
        let viewController = UIViewController()
        viewController.title = message.title

        let titleLabel = UILabel()
        titleLabel.text = self.message.title

        let bodyLabel = UILabel()
        bodyLabel.text = self.message.body
        bodyLabel.numberOfLines = 0

        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete", for: .normal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, deleteButton])
        stack.alignment = .fill
        stack.axis = .vertical
        stack.distribution = .equalSpacing
        stack.spacing = 10

        let view = UIView()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1)

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            ])

        viewController.view = view

        // Setup event handling
        let bag = DisposeBag()

        bag += deleteButton.onValueDisposePrevious {
            viewController.present(self.delete).disposable
        }

        return (viewController, bag)

    }
}
