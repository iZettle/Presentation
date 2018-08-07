//
//  ChooseStyle.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-12.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Flow
import Presentation

struct ChooseStyle { }

extension PresentationStyle {
    static func createStylesDataSource(containerForEmbedStyle containerView: UIView,
                                       sourceForPartialPresentations: UIView? = nil) -> DataSource<PresentationStyle> {
        let sourceView = sourceForPartialPresentations ?? containerView
        let styles: [PresentationStyle] = [
            .default,
            .modal,
            .embed(in: containerView),
            .invisible,
            .sheet(from: sourceView, rect: nil),
            .popover(from: sourceView),
            ]
        return DataSource(options: styles)
    }
}

extension ChooseStyle: Presentable {
    // Some presentation styles require additional setup, for example `.sheet` can only be used for alerts
    // In this particular example the style chooser creates the styles and provides the additional info if needed
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

        let dataSource = PresentationStyle.createStylesDataSource(containerForEmbedStyle: containerForEmbeddingViews)
        let result = tableView.configure(dataSource: dataSource)
        return (viewController, result.map { style in
            if style.name == PresentationStyle.embed(in: nil).name {
                return (style, viewController, nil)
            } else if style.name == PresentationStyle.sheet().name {
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
