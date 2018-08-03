//
//  TableViewControllerUtilities.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-12.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Flow
import UIKit

class DataSource<T>: NSObject, UITableViewDataSource {
    let options: [T]
    let cellForIndexPath: (UITableView, IndexPath, T) -> UITableViewCell

    init(options: [T], cellForIndexPath: @escaping (UITableView, IndexPath, T) -> UITableViewCell) {
        self.options = options
        self.cellForIndexPath = cellForIndexPath
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cellForIndexPath(tableView, indexPath, option(at: indexPath))
    }

    func option(at indexPath: IndexPath) -> T {
        return options[indexPath.row]
    }
}

class Delegate: NSObject, UITableViewDelegate {
    private let callbacker = Callbacker<IndexPath>()
    let didSelect: Signal<IndexPath>

    override init() {
        didSelect = Signal<IndexPath>(callbacker: callbacker)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        callbacker.callAll(with: indexPath)
    }
}

extension UITableViewController {
    func configure<T>(dataSource: DataSource<T>, delegate: Delegate = Delegate()) -> Signal<T> {
        return self.tableView.configure(dataSource: dataSource, delegate: delegate)
    }
}

extension UITableView {
    func configure<T>(dataSource: DataSource<T>, delegate: Delegate = Delegate()) -> Signal<T> {
        self.dataSource = dataSource
        self.delegate = delegate
        let bag = DisposeBag()
        bag.hold(dataSource, delegate)

        let result = Signal<T> { callback in
            bag += delegate.didSelect.onValue { callback(dataSource.option(at: $0)) }
            return bag
        }
        return result
    }
}

extension DataSource where T: CustomStringConvertible {
    convenience init(options: [T]) {
        self.init(options: options) { tableView, indexPath, option in
            let cellIdentifier = "OptionCell"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) ?? UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)

            cell.textLabel?.text = option.description
            return cell
        }
    }
}
