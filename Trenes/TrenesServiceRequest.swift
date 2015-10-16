//
//  TrenesServiceRequest.swift
//  Trenes
//
//  Created by Nicolas Ameghino on 8/23/15.
//  Copyright © 2015 Nicolas Ameghino. All rights reserved.
//

import Foundation
import Alamofire

public struct TrenesServiceRequest: ServiceRequest {
    public let ramal: Int
    
    static var dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "dd/MM/yy HH:mm"
        return df
        }()
    
    public var baseURLString: String { return "http://trenes.mininterior.gov.ar/apps" }
    public var endpoint: String { return "/api_tiempos_temp.php" }
    public var method: String { return "GET" }
    public func params() throws -> [String : AnyObject] {
        return ["ramal": ramal]
    }
    
    public static var processResponseData: ((TrenesServiceRequest, TrenesServiceResponse) -> ())? {
        return { (serviceRequest, var response) -> () in
            response.lineId = serviceRequest.ramal
        }
    }
    
    
    public static func convert(JSONObject: AnyObject?, _ request: TrenesServiceRequest) throws -> TrenesServiceResponse {
        
        //        guard let
        //            path = NSBundle.mainBundle().pathForResource("MockResponse", ofType: "json"),
        //            data = NSData(contentsOfFile: path) else { fatalError() }
        //
        //        let o = try! NSJSONSerialization.JSONObjectWithData(data, options: []) as! JSONDictionary
        //        guard let r = TrenesServiceResponse(dict: o, lineId: request.ramal) else {
        guard let r = TrenesServiceResponse(dict: JSONObject as! JSONDictionary, lineId: request.ramal) else {
            
            throw AlamofireDispatcher.AlamofireDispatcherError.SerializerFailed
        }
        return r
    }
}

enum TrainStatus: String {
    case Confirmed = "confirmado"
    case OnPlatform = "en anden"
    case NotConfirmed = "a confirmar"
}

enum TrainServiceType: String {
    case Regular = "N"
}

protocol TimetableItem {
    var timestamp: NSDate { get }
    var serviceType: TrainServiceType { get }
    var lineId: Int { get }
    var est: AnyObject { get }
    static func create(dict: JSONDictionary) -> [TimetableItem]
}

protocol IntermediateTimetableItem: TimetableItem {
    var trainNumberString: String { get }
    var trainIdString: String { get }
    var mysteryId: AnyObject? { get }
}

protocol TerminusTimetableItem: TimetableItem {
    var platform: Int { get }
    var status: TrainStatus { get }
}

private struct TimetableItemStorage {
    
    typealias TimestampParser = String -> NSDate?
    
    static var intermediateTimestampParser: TimestampParser = {
        return {
            (minutesToTrain: String) -> NSDate in
            guard let minutes = NSTimeInterval(minutesToTrain) else { fatalError() }
            return NSDate(timeIntervalSinceNow: 60 * minutes)
        }
        }()
    
    static var terminusTimestampParser: TimestampParser = {
        return {
            (trainTime: String) -> NSDate in
            
            let stringComponents = trainTime.componentsSeparatedByString(":")
            let components = NSDateComponents()
            components.hour = Int(stringComponents.first!)!
            components.minute = Int(stringComponents.last!)!

            guard let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian) else { fatalError() }
            let today = calendar.startOfDayForDate(NSDate())
            return calendar.dateByAddingComponents(components, toDate: today, options: [])!
        }
    }()
    
    let _status: TrainStatus?
    let _timestamp: NSDate
    let _serviceType: TrainServiceType
    let _platform: Int?
    let _lineId: Int
    let _est: AnyObject? // don't know what this is
    let _trainNumberString: String?
    let _trainIdString: String?
    let _mysteryId: AnyObject?
    
    //    init(dict: JSONDictionary) {
    //        _status = .Confirmed
    //        _timestamp = NSDate()
    //        _serviceType = .Regular
    //        _platform = 0
    //        _lineId = 0
    //        _est = NSObject()
    //        _trainNumberString = "ASD"
    //        _trainIdString = "QWERTY"
    //        _mysteryId = NSObject()
    //    }
    
    static func create(dict: JSONDictionary) -> [TimetableItem] {
        
        
        if let
            serviceTypeString = dict["tipo_s"] as? String,
            serviceType = TrainServiceType.init(rawValue: serviceTypeString),
            est = dict["est"],
            statusString = dict["estado"] as? String,
            status = TrainStatus(rawValue: statusString.lowercaseString),
            platformString = dict["and"] as? String,
            platform = Int(platformString),
            timestampString = dict["min"] as? String,
            timestamp = terminusTimestampParser(timestampString) {
                let lineId: Int = {
                    if let lid = dict["ramal"] as? Int { return lid }
                    return Int(dict["ramal"] as! String) ?? -1
                }()
                
                let item = TimetableItemStorage(
                    _status: status,
                    _timestamp: timestamp,
                    _serviceType: serviceType,
                    _platform: platform,
                    _lineId: lineId,
                    _est: est,
                    _trainNumberString: nil,
                    _trainIdString: nil,
                    _mysteryId: nil) as TerminusTimetableItem
                return [item]
        } else {
            return (1...6).map {
                i in
                if let
                    serviceTypeString = dict["tipo_s_\(i)"] as? String,
                    serviceType = TrainServiceType.init(rawValue: serviceTypeString),
                    lineIdString = dict["ramal_\(i)"] as? String,
                    lineId = Int(lineIdString),
                    est = dict["est_\(i)"],
                    timestampString = dict["min_\(i)"] as? String,
                    timestamp = intermediateTimestampParser(timestampString),
                    trainNumberString = dict["tren_\(i)"] as? String,
                    trainIdString = dict["chapa_\(i)"] as? String,
                    mysteryId = dict["_id"] {
                        let item = TimetableItemStorage(
                            _status: nil,
                            _timestamp: timestamp,
                            _serviceType: serviceType,
                            _platform: nil,
                            _lineId: lineId,
                            _est: est,
                            _trainNumberString: trainNumberString,
                            _trainIdString: trainIdString,
                            _mysteryId: mysteryId) as IntermediateTimetableItem
                        return item
                }
                fatalError()
            }
        }
    }
}

extension TimetableItemStorage: IntermediateTimetableItem {
    var timestamp: NSDate { return _timestamp }
    var serviceType: TrainServiceType { return _serviceType }
    var lineId: Int { return _lineId }
    var est: AnyObject { return _est! }
    var trainNumberString: String { return _trainNumberString! }
    var trainIdString: String { return _trainIdString! }
    var mysteryId: AnyObject? { return _mysteryId }
}

extension TimetableItemStorage: TerminusTimetableItem {
    var platform: Int { return _platform! }
    var status: TrainStatus { return _status! }
}


public struct TrenesServiceResponse {
    var lineId: Int
    let timestamp: NSDate
    let message: String?
    
//    var intermediates: [Int : IntermediateTimetableItem]
    
    private var timetable: [TimetableItem]
    
    func nextInboundForStationAtIndex(index: Int) -> TimetableItem {
        return timetable.first!
    }
    
    func nextOutboundForStationAtIndex(index: Int) -> TimetableItem {
        return timetable.last!
    }
    
    init?(dict: JSONDictionary, lineId: Int) {
        self.lineId = lineId
        guard let
            dateString = dict["fecha"],
            timeString = dict["hora"],
            timestamp = TrenesServiceRequest.dateFormatter.dateFromString("\(dateString) \(timeString)")
            else { return nil }
        self.timestamp = timestamp
        
        guard let
            terminus1Info = dict["salidas"] as? [JSONDictionary],
            terminus2Info = dict["salidas2"] as? [JSONDictionary],
            intermediatesInfo = dict["intermedias"] as? [JSONDictionary],
            alerts = dict["alertas"] as? JSONDictionary
            else { return nil }
        
        let stuff = [
            terminus1Info.flatMap(TimetableItemStorage.create),
            terminus2Info.flatMap(TimetableItemStorage.create),
            intermediatesInfo.flatMap(TimetableItemStorage.create)
        ].reduce([], combine: { return $0 + [$1] })
        
        timetable = Array(stuff.flatten())
        
        timetable.forEach {
            item in
            if let item = item as? IntermediateTimetableItem {
                NSLog("\(item.mysteryId)")
            }
        }
        
        message = alerts["mensaje"] as? String
    }
}