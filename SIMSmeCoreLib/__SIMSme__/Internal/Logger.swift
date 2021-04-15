//
//  Logger.swift
//  SIMSmeCore
//
//  Created by Adnan Zildzic on 25.06.19.
//  Copyright © 2020 ginlo.net GmbH. All rights reserved.
//

import CocoaLumberjack
import Foundation

class Logger {
    init() {
        if AppConfig.isNotificationExtension == false, AppConfig.isShareExtension == false {
            DDLog.add(createFileLogger(logsDirectory: DPAGConstantsGlobal.loggingURL))
        }
        if AppConfig.buildConfigurationMode == .DEBUG, let consoleLogger = createConsoleLogger() {
            DDLog.add(consoleLogger)
        }
    }

    func log<T>(_ object: @escaping @autoclosure () -> T, _ args: [CVarArg], level: LogLevel, file: String, functionName: String, lineNum: Int) {
        let value = object()
        let stringRepresentation: String
        if let value = value as? CustomDebugStringConvertible {
            stringRepresentation = value.debugDescription
        } else if let value = value as? CustomStringConvertible {
            stringRepresentation = value.description
        } else {
            fatalError("DPAGLog only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible")
        }
        let messageText = args.count > 0 ? String(format: stringRepresentation, arguments: args) : stringRepresentation
        let message = DDLogMessage(message: messageText, level: level.DDLogLevel, flag: level.DDLogFlag, context: 0, file: file, function: functionName, line: UInt(lineNum), tag: nil, options: .dontCopyMessage, timestamp: nil)
        DDLog.log(asynchronous: true, message: message)
    }

    func getLogs() -> Data? {
        var logData = Data()
        guard let fileLogger = DDLog.allLoggers.compactMap({ $0 as? DDFileLogger }).first else {
            return nil
        }
        let filePaths = fileLogger.logFileManager.sortedLogFilePaths
        for filePath in filePaths {
            let url = URL(fileURLWithPath: filePath)
            if let data = try? Data(contentsOf: url) {
                logData.append(data)
            }
        }
        return logData
    }

    private func createFileLogger(logsDirectory: URL?) -> DDFileLogger {
        var logFileManager: DDLogFileManagerDefault
        if let logsDirectory = logsDirectory {
            logFileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory.path)
        } else {
            logFileManager = DDLogFileManagerDefault()
        }
        let fileLogger = DDFileLogger(logFileManager: logFileManager)
        fileLogger.maximumFileSize = 1_024 * 1_024 // 1 MB
        fileLogger.logFileManager.maximumNumberOfLogFiles = 5
        fileLogger.logFormatter = LogsFormatter()
        return fileLogger
    }

    private func createConsoleLogger() -> DDTTYLogger? {
        let consoleLogger = DDTTYLogger.sharedInstance
        consoleLogger?.logFormatter = LogsFormatter()
        return consoleLogger
    }
}

private class LogsFormatter: NSObject, DDLogFormatter {
    func format(message logMessage: DDLogMessage) -> String? {
        let queue = Thread.isMainThread ? "UI" : "BG"
        let fileName = URL(string: logMessage.file)?.lastPathComponent ?? "Unknown file"
        let function = logMessage.function ?? ""
        let logMessage = "<\(queue)> \(fileName) - \(function)[\(logMessage.line)]: " + logMessage.message
        return DPAGFormatter.date.string(from: Date()) + " " + logMessage + "\r\n"
    }
}

private extension LogLevel {
    var DDLogLevel: DDLogLevel {
        switch self {
            case .error:
                return .error
            case .warning:
                return .warning
            case .info:
                return .info
            case .debug:
                return .debug
            case .verbose:
                return .verbose
        }
    }

    var DDLogFlag: DDLogFlag {
        switch self {
            case .error:
                return .error
            case .warning:
                return .warning
            case .info:
                return .info
            case .debug:
                return .debug
            case .verbose:
                return .verbose
        }
    }
}
