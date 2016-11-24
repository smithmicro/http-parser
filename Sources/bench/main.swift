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

let httpData : StaticString = "POST /joyent/http-parser HTTP/1.1\r\nHost: github.com\r\nDNT: 1\r\nAccept-Encoding: gzip, deflate, sdch\r\nAccept-Language: ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.65 Safari/537.36\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9, image/webp,*/*;q=0.8\r\nReferer: https://github.com/joyent/http-parser\r\nConnection: keep-alive\r\nTransfer-Encoding: chunked\r\nCache-Control: max-age=0\r\n\r\nb\r\nhello world\r\n0\r\n\r\n"


    func on_message_begin() -> Int {
        return 0
    }
    func on_url(_ at: UnsafePointer<UInt8>, _ length: Int) -> Int {
        return 0
    }
    func on_status(_ at: UnsafePointer<UInt8>, _ length: Int) -> Int {
        return 0
    }
    func on_header_field(_ at: UnsafePointer<UInt8>, _ length: Int) -> Int {
        return 0
    }
    func on_header_value(_ at: UnsafePointer<UInt8>, _ length: Int) -> Int {
        return 0
    }
    func on_headers_complete() -> Int {
        return 0
    }
    func on_body(_ at: UnsafePointer<UInt8>, _ length: Int) -> Int {
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
let  HTTPCallback = http_parser_delegate(
    on_message_begin: on_message_begin,
    on_url: on_url,
    on_status: on_status,
    on_header_field: on_header_field,
    on_header_value: on_header_value,
    on_headers_complete: on_headers_complete,
    on_body: on_body,
    on_message_complete: on_message_complete,
    on_chunk_header: on_chunk_header,
    on_chunk_complete: on_chunk_complete
    )

func bench(_ iter_count: Int, silent: Bool) -> Int {
    var parser = http_parser()
    parser.delegate = HTTPCallback
    var rps = 0.0

    let start = Date()
    httpData.withUTF8Buffer {(bytes: UnsafeBufferPointer<UInt8>) -> Void in

        for _ in 0 ..< iter_count {
            var parsed = 0
            parser.reset(.HTTP_REQUEST)

            parser.delegate = HTTPCallback
            parsed = parser.execute(bytes.baseAddress!, bytes.count)
            assert(parsed == bytes.count)
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
