//
//  ViewController.swift
//  Trenes
//
//  Created by Nicolas Ameghino on 8/23/15.
//  Copyright © 2015 Nicolas Ameghino. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var linesTableView: UITableView! {
        didSet {
            linesTableView.dataSource = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Ramales"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard let
            vc = segue.destinationViewController as? StationListViewController,
            indexPath = linesTableView.indexPathForCell(sender as! UITableViewCell) else { return }
        vc.line = TrainLineInformation.allLines[indexPath.row]
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return TrainLineInformation.allLines.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("LineCell", forIndexPath: indexPath)
        let line = TrainLineInformation.allLines[indexPath.row]
        cell.detailTextLabel?.text = [line.prefix, line.name].joinWithSeparator(" ")
        if let
            firstStation = line.stations.first,
            lastStation = line.stations.last
            where firstStation != lastStation {
                cell.textLabel?.text = "\(firstStation) - \(lastStation)"
        } else {
            cell.textLabel?.text = nil
        }
        return cell
    }
}
