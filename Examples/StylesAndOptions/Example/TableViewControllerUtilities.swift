//
//  TableViewControllerUtilities.swift
//  Example
//
//  Created by Nataliya Patsovska on 2018-06-12.
//  Copyright © 2018 iZettle. All rights reserved.
//

import Flow
import UIKit

class DataSource<T: CustomStringConvertible>: NSObject, UITableViewDataSource {
    let options: [T]
    private let cellIdentifier = "OptionCell"

    init(options: [T]) {
        self.options = options
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)

        let option = self.option(at: indexPath)
        cell.textLabel?.text = option.description
        return cell
    }

    func option(at indexPath: IndexPath) -> T {
        return options[indexPath.row]
    }
}

class Delegate: NSObject, UITableViewDelegate {
    let callbacker = Callbacker<IndexPath>()

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        callbacker.callAll(with: indexPath)
    }
}

extension UITableViewController {
    func configure<T>(dataSource: DataSource<T>, delegate: Delegate) -> Signal<T> {
        return self.tableView.configure(dataSource: dataSource, delegate: delegate)
    }
}

extension UITableView {
    func configure<T>(dataSource: DataSource<T>, delegate: Delegate) -> Signal<T> {
        self.dataSource = dataSource
        self.delegate = delegate
        let selectSignal = Signal(callbacker: delegate.callbacker)
        let bag = DisposeBag()
        bag.hold(dataSource, delegate)

        let result = Signal<T> { callback in
            bag += selectSignal.onValue { callback(dataSource.option(at: $0)) }
            return bag
        }
        return result
    }
}
