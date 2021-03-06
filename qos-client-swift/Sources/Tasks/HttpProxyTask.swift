/***************************************************************************
 * Copyright 2017 appscape gmbh
 * Copyright 2019 alladin-IT GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ***************************************************************************/

import Foundation
import CodableJSON
import nntool_shared_swift

class HttpProxyTask: QoSTask {

    private var url: String
    private var range: String?
    private var downloadTimeout: UInt64?
    private var connectionTimeout: UInt64?

    private var semaphore: DispatchSemaphore?

    private var resultStatusCode: Int?
    private var resultDuration: UInt64?
    private var resultLength: Int64?
    private var resultHeader: String?
    private var resultHash: String?

    ///
    enum CodingKeys4: String, CodingKey {
        case url
        case range
        case downloadTimeout = "download_timeout"
        case connectionTimeout = "conn_timeout"
    }

    override var result: QoSTaskResult {
        var r = super.result

        r["http_objective_url"] = JSON(url)
        r["http_objective_range"] = JSON(range)

        r["http_result_status"] = JSON(resultStatusCode)
        r["http_result_duration"] = JSON(resultDuration)
        r["http_result_length"] = JSON(resultLength)
        r["http_result_header"] = JSON(resultHeader)

        r["http_result_hash"] = JSON(resultHash)

        return r
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys4.self)

        url = try container.decode(String.self, forKey: .url) // TODO: url check?

        range = try container.decodeIfPresent(String.self, forKey: .range)

        downloadTimeout = container.decodeIfPresentWithStringFallback(UInt64.self, forKey: .downloadTimeout)
        connectionTimeout = container.decodeIfPresentWithStringFallback(UInt64.self, forKey: .connectionTimeout)

        try super.init(from: decoder)
    }

    override func taskMain() {
        guard let url = URL(string: url) else {
            status = .error
            return
        }

        let configuration = URLSessionConfiguration.ephemeral

        configuration.allowsCellularAccess = true
        //configuration.HTTPShouldUsePipelining = true

        if let dt = downloadTimeout {
            configuration.timeoutIntervalForResource = TimeInterval(dt / NSEC_PER_SEC)
        }

        if let ct = connectionTimeout {
            configuration.timeoutIntervalForRequest = TimeInterval(ct / NSEC_PER_SEC)
        }

        var additonalHeaderFields = [String: String]()

        // Set user agent
        if let userAgent = UserDefaults.standard.string(forKey: "UserAgent") {
            additonalHeaderFields["User-Agent"] = userAgent
        }

        // add range header if it exists
        if let r = range {
            additonalHeaderFields["Range"] = r
        }

        configuration.httpAdditionalHeaders = additonalHeaderFields

        ////

        let requestStartTimeNs = TimeHelper.currentTimeNs()

        let urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let dataTask = urlSession.dataTask(with: url) { (data, response, error) in
            self.resultDuration = TimeHelper.currentTimeNs() - requestStartTimeNs

            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    self.status = .timeout
                    self.resultHash = QoSTaskStatus.timeout.rawValue // ...
                } else {
                    self.status = .error
                    self.resultHash = QoSTaskStatus.error.rawValue // ...
                }
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    self.resultStatusCode = httpResponse.statusCode
                    self.resultLength = httpResponse.expectedContentLength

                    if let data = data {
                        self.resultHash = CommonCryptoHelper.md5(data)
                    }

                    self.resultHeader = httpResponse.allHeaderFields
                                                    .compactMap({ "\($0): \($1)" })
                                                    .joined(separator: "\n")
                }

                self.status = .ok
            }

            self.semaphore?.signal()
        }

        dataTask.resume()

        semaphore = DispatchSemaphore(value: 0)
        let timeoutResult = semaphore?.wait(timeout: .now() + .nanoseconds(Int(timeoutNs)))

        if timeoutResult == .timedOut {
            status = .timeout
        }

        taskLogger.debug("finished HTTP Proxy Task")
    }
}

extension HttpProxyTask: URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        // prevent redirects
        completionHandler(nil)
    }
}
