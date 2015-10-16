//
//  StationListViewController.swift
//  Trenes
//
//  Created by Nicolas Ameghino on 10/15/15.
//  Copyright © 2015 Nicolas Ameghino. All rights reserved.
//

import UIKit

class StationListTableViewCell: UITableViewCell {
    @IBOutlet weak var stationNameLabel: UILabel!
    @IBOutlet weak var inboundTimeLabel: UILabel!
    @IBOutlet weak var outboundTimeLabel: UILabel!
}

class StationListViewController: UIViewController {

    var line: TrainLine!
    @IBOutlet weak var stationsTableView: UITableView! {
        didSet {
            stationsTableView.dataSource = self
        }
    }
    
    lazy var getButton: UIBarButtonItem! = {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: "getButtonHandler:")
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = getButton
        navigationItem.title = "\(line.prefix) \(line.name)"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getButtonHandler(sender: AnyObject!) {
        let request = TrenesServiceRequest(ramal: line.outboundLineId)
        AlamofireDispatcher.dispatch(request,
            success: {
                (info: TrenesServiceResponse) -> () in
                NSLog("Success!")
                NSLog("\(info)")
                NSLog("=====")
            }, failure: {
                (error) -> () in
                NSLog("error: \(error.localizedDescription)")
        })
    }
}

extension StationListViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return line.stations.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let
            cell = tableView.dequeueReusableCellWithIdentifier("StationCellIdentifier", forIndexPath: indexPath) as? StationListTableViewCell
        else { fatalError() }
        
        let station = line.stations[indexPath.row]
        cell.stationNameLabel?.text = station
        cell.inboundTimeLabel?.text = "3 min"
        cell.outboundTimeLabel?.text = "2 min"
        
        return cell
    }
}
