//
//  ChooseStyle.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-12.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Flow
import Presentation

struct ChooseStyle {
    private let createDataSource: (UIView) -> DataSource<PresentationStyle>

    init() {
        createDataSource = { view in
            let styles: [PresentationStyle] = [
                .default,
                .modal,
                .embed(in: view),
                .invisible,
                .sheet(from: view, rect: nil),
                .popover(from: view),
            ]
            return DataSource(options: styles)
        }
    }
}

extension ChooseStyle: Presentable {
    typealias ChooseStyleResult = (PresentationStyle, preferredPresenter: UIViewController?, alertToPresent: Alert<()>?)
    
    func materialize() -> (UIViewController, Signal<ChooseStyleResult>) {
        let viewController = UIViewController()
        viewController.title = "Presentation Styles"

        let containerForEmbeddingViews = UIView()
        containerForEmbeddingViews.backgroundColor = .white

        let tableView = UITableView()
        
        let content = UIStackView(arrangedSubviews: [tableView, containerForEmbeddingViews])
        content.distribution = .fillEqually
        content.axis = .vertical

        viewController.view = content

        let result = tableView.configure(dataSource: createDataSource(containerForEmbeddingViews), delegate: Delegate())
        return (viewController, result.map { style in
            if style.name == "embed" {
                return (style, viewController, nil)
            } else if style.name == "sheet" {
                let alertAction = Alert<()>.Action(title: "OK", action: { })
                return (style, nil, Alert(message: "Test alert", actions: [alertAction]))
            } else {
                return (style, nil, nil)
            }
        })
    }
}

extension PresentationStyle: CustomStringConvertible {
    public var description: String { return name }
}
