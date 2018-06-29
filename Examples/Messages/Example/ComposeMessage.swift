//
//  ComposeMessage.swift
//  Messages
//
//  Created by Måns Bernhardt on 2018-04-19.
//  Copyright © 2018 iZettle. All rights reserved.
//

import UIKit
import Flow
import Presentation

struct ComposeMessage { }

extension ComposeMessage: Presentable {
    func materialize() -> (UIViewController, Future<Message>) {
        // Setup view controller and views
        let viewController = UIViewController()
        viewController.title = "Compose Message"

        let titleField = UITextField()
        titleField.placeholder = "Title"

        let bodyField = UITextField()
        bodyField.placeholder = "Body"

        let stack = UIStackView(arrangedSubviews: [titleField, bodyField])
        stack.alignment = .fill
        stack.axis = .vertical
        stack.distribution = .equalSpacing
        stack.spacing = 10

        let view = UIView()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1)

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            titleField.heightAnchor.constraint(equalToConstant: 44),
            bodyField.heightAnchor.constraint(equalToConstant: 44),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            ])

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: nil, action: nil)
        viewController.navigationItem.leftBarButtonItem = cancelButton

        let postButton = UIBarButtonItem(barButtonSystemItem: .save, target: nil, action: nil)
        viewController.navigationItem.rightBarButtonItem = postButton

        viewController.view = view

        return (viewController, Future { completion in
            // Setup event handling
            let bag = DisposeBag()

            bag += cancelButton.onValue { completion(.failure(PresentError.dismissed)) }

            bag += postButton.onValue {
                let message = Message(title: titleField.text ?? "", body: bodyField.text ?? "")
                completion(.success(message))
            }

            titleField.becomeFirstResponder()

            return bag
        })
    }
}
