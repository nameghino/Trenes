//
//  TrainLineInformation.swift
//  Trenes
//
//  Created by Nicolas Ameghino on 8/23/15.
//  Copyright © 2015 Nicolas Ameghino. All rights reserved.
//

import UIKit

/*

{
"Nombre": "Tren de la Costa",
"Prefijo": "",
"Ramales": [
{
"RamalIda": 41,
"RamalVuelta": 42,
"Mostrar": true,
"Mapa": true,
"Estaciones": [
"Maipú",
"Borges",
"Libertador",
"Juan Anchorena",
"Las Barrancas",
"San Isidro R",
"Punta Chica",
"Marina Nueva",
"San Fernando R",
"Canal San Fernando",
"Delta"
]
}
]
}
*/

struct TrainLine {
    let name: String
    let prefix: String
    let shouldBeDisplayed: Bool
    let inboundLineId: Int
    let outboundLineId: Int
    let stations: [String]
    
    static func createLines(d: JSONDictionary) -> [TrainLine] {
        guard let
            name = d["Nombre"] as? String,
            prefix = d["Prefijo"] as? String,
            sublines = d["Ramales"] as? [JSONDictionary] else { fatalError() }
        return sublines.map {
            s -> TrainLine in
            guard let
                outboundId = s["RamalIda"] as? Int,
                inboundId = s["RamalVuelta"] as? Int,
                shouldBeDisplayed = s["Mostrar"] as? Bool,
                stations = s["Estaciones"] as? [String] else { fatalError() }
            
            return TrainLine(
                name: name,
                prefix: prefix,
                shouldBeDisplayed: shouldBeDisplayed,
                inboundLineId: inboundId,
                outboundLineId: outboundId,
                stations: stations)
            
        }
    }
}

public class TrainLineInformation {
    
    static let allLines: [TrainLine] = {
        let path = NSBundle.mainBundle().pathForResource("Lineas", ofType: "json")!
        let stream = NSInputStream(fileAtPath: path)!
        defer {
            stream.close()
        }
        stream.open()
        guard let
            object = try! NSJSONSerialization.JSONObjectWithStream(stream, options: NSJSONReadingOptions.AllowFragments) as? JSONDictionary,
            lines = object["Lineas"] as? [JSONDictionary] else { fatalError() }
        return lines.flatMap(TrainLine.createLines)
        

    }()
    
    static let lineIndex: [Int : TrainLine] = {
        var r = [Int : TrainLine]()
        return allLines.reduce(r) {
            (var dict, line) -> [Int : TrainLine] in
            dict[line.outboundLineId] = line
            dict[line.inboundLineId] = line
            return dict
        }
    }()
}
