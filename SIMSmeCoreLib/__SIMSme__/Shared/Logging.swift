//
//  Logging.swift
//  SIMSmeCore
//
//  Created by Adnan Zildzic on 26.06.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import Foundation

var appLogger = Logger()

public enum LogLevel {
    case error
    case warning
    case info
    case debug
    case verbose
}

public func DPAGLog<T>(_ object: @escaping @autoclosure () -> T, _ args: CVarArg..., level: LogLevel = .info, file: String = #file, functionName: String = #function, lineNum: Int = #line) {
    appLogger.log(object(), args, level: level, file: file, functionName: functionName, lineNum: lineNum)
}

public func DPAGLog(_ error: Error, message: String = "", file: String = #file, functionName: String = #function, lineNum: Int = #line) {
    DPAGLog("\(message.isEmpty ? "Error" : message) : \(error)", level: .error, file: file, functionName: functionName, lineNum: lineNum)
}

public struct LoggingHelper {
    private init() {}
    public static func stripNameFromPayload(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var payload = userInfo
        if payload[jsonDict: "aps"]?[jsonDict: "alert"]?[array: "loc-args"] != nil {
            payload[jsonDict: "aps"]?[jsonDict: "alert"]?[array: "loc-args"] = ["not nil"]
        }
        return payload
    }
}
