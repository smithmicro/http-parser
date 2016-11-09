/* Copyright Fedor Indutny. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

/*
 * Swift 3 port
 * Copyright (c) 2016 Dave Sperling - Smith Micro Software, Inc.
 * Swift changes are licensed under the same terms above.
 * All rights reserved.
*/

import Foundation
import HTTPParser

let data =
"POST /joyent/http-parser HTTP/1.1\r\n" +
"Host: github.com\r\n" +
"DNT: 1\r\n" +
"Accept-Encoding: gzip, deflate, sdch\r\n" +
"Accept-Language: ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4\r\n" +
"User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) " +
"AppleWebKit/537.36 (KHTML, like Gecko) " +
"Chrome/39.0.2171.65 Safari/537.36\r\n" +
"Accept: text/html,application/xhtml+xml,application/xml;q=0.9," +
"image/webp,*/*;q=0.8\r\n" +
"Referer: https://github.com/joyent/http-parser\r\n" +
"Connection: keep-alive\r\n" +
"Transfer-Encoding: chunked\r\n" +
"Cache-Control: max-age=0\r\n\r\nb\r\nhello world\r\n0\r\n\r\n"


class HTTPCallback: http_parser_delegate {
    func on_message_begin() -> Int {
        return 0
    }
    func on_url(at: UnsafePointer<UInt8>, length: Int) -> Int {
        return 0
    }
    func on_status(at: UnsafePointer<UInt8>, length: Int) -> Int {
        return 0
    }
    func on_header_field(at: UnsafePointer<UInt8>, length: Int) -> Int {
        return 0
    }
    func on_header_value(at: UnsafePointer<UInt8>, length: Int) -> Int {
        return 0
    }
    func on_headers_complete() -> Int {
        return 0
    }
    func on_body(at: UnsafePointer<UInt8>, length: Int) -> Int {
        return 0
    }
    func on_message_complete() -> Int {
        return 0
    }
    func on_chunk_header() -> Int {
        return 0
    }
    func on_chunk_complete() -> Int {
        return 0
    }
}

func bench(_ iter_count: Int, silent: Bool) -> Int {
    let parser = http_parser()
    let settings = HTTPCallback()
    var rps = 0.0

    let start = Date()
    let httpData = data.data(using: .utf8)!
    httpData.withUnsafeBytes {(bytes: UnsafePointer<UInt8>) -> Void in

        for _ in 0 ..< iter_count {
            var parsed = 0
            parser.reset(.HTTP_REQUEST)

            parsed = parser.execute(settings, bytes, httpData.count)
            assert(parsed == httpData.count)
        }
    }

    if !silent {
        print("Benchmark result:");

        rps = NSDate().timeIntervalSince(start)
        print("Took \(Double(Int(rps * 100))/100.0) seconds to run");

        rps = Double(iter_count) / rps
        print("\(Double(Int(rps * 100))/100.0) req/sec")
    }

    return 0
}


func main() -> Int {

    let loop = 5000000
    return bench(loop, silent: false)
}

let result = main()
