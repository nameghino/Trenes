//
//  AlamofireDispatcher.swift
//  HomeAI
//
//  Created by Nico Ameghino on 7/28/15.
//  Copyright © 2015 SecondMind. All rights reserved.
//

import Foundation
import Alamofire

let HomeAIServiceErrorDomain = "ai.home.error"
let HomeAIServiceErrorMessageKey = "HomeAIServiceErrorMessage"

typealias JSONDictionary = [String: AnyObject]

public protocol ServiceRequest {
    typealias ReturnType
    
    var endpoint: String { get }
    var method: String { get }
    var baseURLString: String { get }
    var validateResponse: AlamofireDispatcherResponseValidator { get }
    var encoding: Alamofire.ParameterEncoding { get }
    static var processResponseData: ((Self, ReturnType) -> ())? { get }
    static func convert(JSONObject: AnyObject?, _ request: Self) throws -> ReturnType
    
    func params() throws -> [String : AnyObject]
    func getURLRequest() throws -> NSMutableURLRequest
}

extension ServiceRequest {
    public func getURLRequest() throws -> NSMutableURLRequest {
        let URL = NSURL(string: baseURLString)
        let URLRequest = NSMutableURLRequest(URL: URL!.URLByAppendingPathComponent(endpoint))
        URLRequest.HTTPMethod = method
        let encoding = self.encoding
        let p = try params()
        return encoding.encode(URLRequest, parameters: p).0
    }
    
    public var encoding: Alamofire.ParameterEncoding { return Alamofire.ParameterEncoding.URL }
    
    public var method: String { return "POST" }
    
    public var validateResponse: AlamofireDispatcherResponseValidator {
        return {
            response, data in
            let validResponses = 200..<300
            if validResponses.contains(response.statusCode) { return nil }
            
            if let data = data {
                var buffer = [UInt8](count:data.length, repeatedValue:0)
                data.getBytes(&buffer, length:data.length)
                if let message = String(bytes:buffer, encoding:NSUTF8StringEncoding) {
                    return NSError(domain: HomeAIServiceErrorDomain,
                        code: response.statusCode,
                        userInfo: [
                            NSLocalizedDescriptionKey: "[\(response.statusCode)] - \(message)",
                            HomeAIServiceErrorMessageKey: message
                        ])
                }
            }
            
            return NSError(domain: AlamofireDispatcher.AlamofireDispatcherErrorDomain,
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "No error message reported. Default response validator failed: status code was \(response.statusCode)"])
        }
    }
    
    public static var processResponseData: ((Self, ReturnType) -> ())? { return nil }
}

public typealias AlamofireDispatcherResponseValidator = (NSHTTPURLResponse, NSData?) -> NSError?

public class AlamofireDispatcher {
    static let AlamofireDispatcherErrorDomain = "AlamofireDispatcherErrorDomain"
    static var activeTasks: [String : Alamofire.Request] = [:]
    static var shouldShowNetworkActivityIndicator: Bool { return !activeTasks.isEmpty }
    
    public enum AlamofireDispatcherError: ErrorType {
        case SerializerFailed
        case NoDataReceived
        case JSONParsingFailed
        case ServiceRequestValidatorFailed
        case NoResponseReceived
        case CouldNotBuildParameters(String?)
        case UnknownError
        
        var code: Int {
            switch self {
            case .SerializerFailed:
                return -1000
            case .NoDataReceived:
                return -1001
            case .JSONParsingFailed:
                return -1002
            case .ServiceRequestValidatorFailed:
                return -1003
            case .NoResponseReceived:
                return -1004
            case .CouldNotBuildParameters:
                return -1005
            case .UnknownError:
                return -999
            }
            
        }
        
        var description: String {
            switch self {
            case .SerializerFailed:
                return "JSON -> Object converter failed"
            case .NoDataReceived:
                return "No data received from endpoint"
            case .JSONParsingFailed:
                return "JSON parser failed to parse the content in the response"
            case .ServiceRequestValidatorFailed:
                return "Service request implements a validation which failed. See underlying error"
            case .NoResponseReceived:
                return "Inconsistent state: didn't get an HTTP response, bailing out"
            case .CouldNotBuildParameters(let missingParameter):
                return "The parameter \"\(missingParameter)\" could not be obtained for creating the request"
            case .UnknownError:
                return "AlamofireDispatcher response processor experienced an unknown error while attempting serialization of the response"
            }
        }
    }
    
    private class func updateNetworkActivityIndicator() {
        if UIApplication.sharedApplication().applicationState == .Active {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = shouldShowNetworkActivityIndicator
        }
    }
    
    private class func constructError(dispatcherError: AlamofireDispatcherError, underlyingError: NSError? = nil) -> NSError {
        var userInfo = [NSObject : AnyObject]()
        userInfo[NSLocalizedDescriptionKey] = dispatcherError.description
        if let underlyingError = underlyingError {
            userInfo[NSUnderlyingErrorKey] = underlyingError
        }
        return NSError(
            domain: AlamofireDispatcherErrorDomain,
            code: dispatcherError.code,
            userInfo: userInfo
        )
    }
    
    public class func dispatch<T: ServiceRequest>(
        serviceRequest: T,
        success: (T.ReturnType) -> (),
        failure: (NSError!) -> ()) -> String? {
            let identifier = NSUUID().UUIDString
            
            do {
                let URLRequest = try serviceRequest.getURLRequest()
                let request = Alamofire.request(URLRequest)
                    .response {
                        (request, response, data, error) -> Void in
                        
                        activeTasks[identifier] = nil
                        updateNetworkActivityIndicator()
                        if let error = error {
                            NSLog("error \(error.domain)[\(error.code)]: \(error.localizedDescription)")
                            return failure(error)
                        }
                        
                        guard let response = response else {
                            NSLog(AlamofireDispatcherError.NoResponseReceived.description)
                            return failure(constructError(AlamofireDispatcherError.NoResponseReceived))
                        }
                        
                        if let error = serviceRequest.validateResponse(response, data) {
                            return failure(error)
                        }
                        
                        guard let data = data where data.length > 0 else {
                            // service requests that do not return data won't throw exceptions when "converting" (which should be a NOP) -nico
                            let o = try! T.convert(nil, serviceRequest)
                            T.processResponseData?(serviceRequest, o)
                            return success(o)
                        }
                        
                        do {
                            
                            let s = NSString(data: data, encoding: NSUTF8StringEncoding)
                            NSLog("received: \(s)")
                            let jsonObject = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
                            let modelObject = try T.convert(jsonObject, serviceRequest)
                            T.processResponseData?(serviceRequest, modelObject)
                            return success(modelObject)
                        } catch let error as NSError {
                            return failure(constructError(AlamofireDispatcherError.SerializerFailed, underlyingError: error))
                        } catch AlamofireDispatcher.AlamofireDispatcherError.JSONParsingFailed {
                            return failure(constructError(AlamofireDispatcherError.SerializerFailed))
                        } catch {
                            return failure(constructError(AlamofireDispatcherError.UnknownError))
                        }
                }
                
                activeTasks[identifier] = request
                debugPrint(request)
                updateNetworkActivityIndicator()
                return identifier
            } catch AlamofireDispatcherError.CouldNotBuildParameters(let cause) {
                let errorCause = AlamofireDispatcherError.CouldNotBuildParameters(cause)
                failure(constructError(errorCause))
                return nil
            } catch {
                failure(constructError(AlamofireDispatcherError.UnknownError))
                return nil
            }
    }
    
    public class func cancel(identifier: String) {
        guard let request = activeTasks[identifier] else { return }
        request.cancel()
    }
    
    public class func cancelAll() {
        for (_, request) in activeTasks { request.cancel() }
    }
}
