/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
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

@testable import HTTPParser
import XCTest

let MAX_HEADERS = 13
//let MAX_ELEMENT_SIZE = 2048
let MAX_CHUNKS = 16
let MAX_MESSAGE_TESTS = 5

var parser: http_parser? = nil

func HTTP_PARSER_ERRNO(_ p: http_parser?) -> http_errno {
  return p!.http_errno
}

struct message {
  var name = "" // for debugging purposes
  var type:http_parser_type = .HTTP_REQUEST
  var raw = ""
  //var host = ""
  //var userinfo = ""
  //var port:UInt16 = 0
  var should_keep_alive: Bool = false

  var message_complete_on_eof: Bool = false
  var http_major:UInt16 = 0
  var http_minor:UInt16 = 0
  var method: http_method = .HTTP_GET
  var query_string = ""
  var fragment = ""
  var request_path = ""
  var request_url = ""
  var num_headers = 0
  var upgrade = "" // upgraded body
  var headers = [[String]]()
  var body = ""
}

enum last_header_element:Int { case NONE = 0, FIELD, VALUE }

struct message_result {

  var status_code = 0
  var response_status = ""
  var body_size = 0

  var last_header_element:last_header_element = .NONE
  var message_begin_cb_called: Bool = false
  var headers_complete_cb_called: Bool = false
  var message_complete_cb_called: Bool = false
  var body_is_final: Bool = false
  
  var num_chunks = 0
  var num_chunks_complete = 0
  var chunk_lengths = [UInt64]()    // MAX_CHUNKS
}

var currently_parsing_eof = false

var messages = [message]()
var message_results = [message_result](repeating: message_result(), count: 5)
var num_messages = 0
var current_pause_parser: http_parser_delegate? = nil

let CURL_GET = 0
let FIREFOX_GET = 1
let DUMBFUCK = 2
let FRAGMENT_IN_URI = 3
let GET_NO_HEADERS_NO_BODY = 4
let GET_ONE_HEADER_NO_BODY = 5
let GET_FUNKY_CONTENT_LENGTH = 6

/* * R E Q U E S T S * */
var requests: [message] = [
//#define CURL_GET 0
message(
  name: "curl get"
  ,type: .HTTP_REQUEST
  ,raw: "GET /test HTTP/1.1\r\n" +
         "User-Agent: curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1\r\n" +
         "Host: 0.0.0.0=5000\r\n" +
         "Accept: */*\r\n" +
         "\r\n"
  ,should_keep_alive: true
  ,message_complete_on_eof: false
  ,http_major: 1
  ,http_minor: 1
  ,method: .HTTP_GET
  ,query_string: ""
  ,fragment: ""
  ,request_path: "/test"
  ,request_url: "/test"
  ,num_headers: 3
  ,upgrade: ""
  ,headers:
    [ [ "User-Agent", "curl/7.18.0 (i486-pc-linux-gnu) libcurl/7.18.0 OpenSSL/0.9.8g zlib/1.2.3.3 libidn/1.1" ]
    , [ "Host", "0.0.0.0=5000" ]
    , [ "Accept", "*/*" ]
    ]
   ,body: ""
  ),

//#define FIREFOX_GET 1
message(
  name: "firefox get"
  ,type: .HTTP_REQUEST
  ,raw: "GET /favicon.ico HTTP/1.1\r\n" +
         "Host: 0.0.0.0=5000\r\n" +
         "User-Agent: Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9) Gecko/2008061015 Firefox/3.0\r\n" +
         "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,REPLACE_WITH_ASTERISK_SLASH_ASTERISK;q=0.8\r\n" +
         "Accept-Language: en-us,en;q=0.5\r\n" +
         "Accept-Encoding: gzip,deflate\r\n" +
         "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\n" +
         "Keep-Alive: 300\r\n" +
         "Connection: keep-alive\r\n" +
         "\r\n"
  ,should_keep_alive: true
  ,message_complete_on_eof: false
  ,http_major: 1
  ,http_minor: 1
  ,method: .HTTP_GET
  ,query_string: ""
  ,fragment: ""
  ,request_path: "/favicon.ico"
  ,request_url: "/favicon.ico"
  ,num_headers: 8
  ,upgrade: ""
  ,headers:
    [ [ "Host", "0.0.0.0=5000" ]
    , [ "User-Agent", "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9) Gecko/2008061015 Firefox/3.0" ]
    , [ "Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,REPLACE_WITH_ASTERISK_SLASH_ASTERISK;q=0.8" ]
    , [ "Accept-Language", "en-us,en;q=0.5" ]
    , [ "Accept-Encoding", "gzip,deflate" ]
    , [ "Accept-Charset", "ISO-8859-1,utf-8;q=0.7,*;q=0.7" ]
    , [ "Keep-Alive", "300" ]
    , [ "Connection", "keep-alive" ]
    ]
  ,body: ""
  ),

//#define DUMBFUCK 2
  message(
    name: "dumbfuck"
    ,type: .HTTP_REQUEST
    ,raw: "GET /dumbfuck HTTP/1.1\r\n" +
         "aaaaaaaaaaaaa:++++++++++\r\n" +
         "\r\n"
    ,should_keep_alive: true
    ,message_complete_on_eof: false
    ,http_major: 1
    ,http_minor: 1
    ,method: .HTTP_GET
    ,query_string: ""
    ,fragment: ""
    ,request_path: "/dumbfuck"
    ,request_url: "/dumbfuck"
    ,num_headers: 1
    ,upgrade: ""
    ,headers:
    [ [ "aaaaaaaaaaaaa",  "++++++++++" ]
    ]
    ,body: ""
  ),

//#define FRAGMENT_IN_URI 3
  message(
    name: "fragment in url"
    ,type: .HTTP_REQUEST
    ,raw: "GET /forums/1/topics/2375?page=1#posts-17408 HTTP/1.1\r\n" +
         "\r\n"
    ,should_keep_alive: true
    ,message_complete_on_eof: false
    ,http_major: 1
    ,http_minor: 1
    ,method: .HTTP_GET
    ,query_string: "page=1"
    ,fragment: "posts-17408"
    ,request_path: "/forums/1/topics/2375"
    /* XXX request url does include fragment? */
    ,request_url: "/forums/1/topics/2375?page=1#posts-17408"
    ,num_headers: 0
    ,upgrade: ""
    ,headers: []
    ,body: ""
  ),

//#define GET_NO_HEADERS_NO_BODY 4
  message(
    name: "get no headers no body"
    ,type: .HTTP_REQUEST
    ,raw: "GET /get_no_headers_no_body/world HTTP/1.1\r\n" +
         "\r\n"
    ,should_keep_alive: true
    ,message_complete_on_eof: false /* would need Connection: close */
    ,http_major: 1
    ,http_minor: 1
    ,method: .HTTP_GET
    ,query_string: ""
    ,fragment: ""
    ,request_path: "/get_no_headers_no_body/world"
    ,request_url: "/get_no_headers_no_body/world"
    ,num_headers: 0
    ,upgrade: ""
    ,headers: []
    ,body: ""
  ),

//#define GET_ONE_HEADER_NO_BODY 5
  message(
    name: "get one header no body"
    ,type: .HTTP_REQUEST
    ,raw: "GET /get_one_header_no_body HTTP/1.1\r\n" +
           "Accept: REPLACE_WITH_ASTERISK_SLASH_ASTERISK\r\n" +
           "\r\n"
    ,should_keep_alive: true
    ,message_complete_on_eof: false /* would need Connection: close */
    ,http_major: 1
    ,http_minor: 1
    ,method: .HTTP_GET
    ,query_string: ""
    ,fragment: ""
    ,request_path: "/get_one_header_no_body"
    ,request_url: "/get_one_header_no_body"
    ,num_headers: 1
    ,upgrade: ""
    ,headers:
    [ [ "Accept" , "REPLACE_WITH_ASTERISK_SLASH_ASTERISK" ]
    ]
    ,body: ""
  ),
/* This test does yet succeed
//#define GET_FUNKY_CONTENT_LENGTH 6
  message(
    name: "get funky content length body hello"
    ,type: .HTTP_REQUEST
    ,raw: "GET /get_funky_content_length_body_hello HTTP/1.0\r\n" +
         "conTENT-Length: 5\r\n" +
         "\r\n" +
         "HELLO"
    ,should_keep_alive: false
    ,message_complete_on_eof: false
    ,http_major: 1
    ,http_minor: 0
    ,method: .HTTP_GET
    ,query_string: ""
    ,fragment: ""
    ,request_path: "/get_funky_content_length_body_hello"
    ,request_url: "/get_funky_content_length_body_hello"
    ,num_headers: 1
    ,upgrade: ""
    ,headers:
    [ [ "conTENT-Length" , "5" ]
    ]
    ,body: "HELLO"
  )

#define POST_IDENTITY_BODY_WORLD 7
, {.name= "post identity body world"
  ,.type= HTTP_REQUEST
  ,.raw= "POST /post_identity_body_world?q=search#hey HTTP/1.1\r\n"
         "Accept: REPLACE_WITH_ASTERISK_SLASK_ASTERISK\r\n"
         "Transfer-Encoding: identity\r\n"
         "Content-Length: 5\r\n"
         "\r\n"
         "World"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= "q=search"
  ,.fragment= "hey"
  ,.request_path= "/post_identity_body_world"
  ,.request_url= "/post_identity_body_world?q=search#hey"
  ,.num_headers= 3
  ,.headers=
    { { "Accept", "REPLACE_WITH_ASTERISK_SLASK_ASTERISK" }
    , { "Transfer-Encoding", "identity" }
    , { "Content-Length", "5" }
    }
  ,.body= "World"
  }

#define POST_CHUNKED_ALL_YOUR_BASE 8
, {.name= "post - chunked body: all your base are belong to us"
  ,.type= HTTP_REQUEST
  ,.raw= "POST /post_chunked_all_your_base HTTP/1.1\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "1e\r\nall your base are belong to us\r\n"
         "0\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/post_chunked_all_your_base"
  ,.request_url= "/post_chunked_all_your_base"
  ,.num_headers= 1
  ,.headers=
    { { "Transfer-Encoding" , "chunked" }
    }
  ,.body= "all your base are belong to us"
  ,.num_chunks_complete= 2
  ,.chunk_lengths= { 0x1e }
  }

#define TWO_CHUNKS_MULT_ZERO_END 9
, {.name= "two chunks ; triple zero ending"
  ,.type= HTTP_REQUEST
  ,.raw= "POST /two_chunks_mult_zero_end HTTP/1.1\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "5\r\nhello\r\n"
         "6\r\n world\r\n"
         "000\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/two_chunks_mult_zero_end"
  ,.request_url= "/two_chunks_mult_zero_end"
  ,.num_headers= 1
  ,.headers=
    { { "Transfer-Encoding", "chunked" }
    }
  ,.body= "hello world"
  ,.num_chunks_complete= 3
  ,.chunk_lengths= { 5, 6 }
  }

#define CHUNKED_W_TRAILING_HEADERS 10
, {.name= "chunked with trailing headers. blech."
  ,.type= HTTP_REQUEST
  ,.raw= "POST /chunked_w_trailing_headers HTTP/1.1\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "5\r\nhello\r\n"
         "6\r\n world\r\n"
         "0\r\n"
         "Vary: *\r\n"
         "Content-Type: text/plain\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/chunked_w_trailing_headers"
  ,.request_url= "/chunked_w_trailing_headers"
  ,.num_headers= 3
  ,.headers=
    { { "Transfer-Encoding",  "chunked" }
    , { "Vary", "*" }
    , { "Content-Type", "text/plain" }
    }
  ,.body= "hello world"
  ,.num_chunks_complete= 3
  ,.chunk_lengths= { 5, 6 }
  }

#define CHUNKED_W_BULLSHIT_AFTER_LENGTH 11
, {.name= "with bullshit after the length"
  ,.type= HTTP_REQUEST
  ,.raw= "POST /chunked_w_bullshit_after_length HTTP/1.1\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "5; ihatew3;whatthefuck=aretheseparametersfor\r\nhello\r\n"
         "6; blahblah; blah\r\n world\r\n"
         "0\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/chunked_w_bullshit_after_length"
  ,.request_url= "/chunked_w_bullshit_after_length"
  ,.num_headers= 1
  ,.headers=
    { { "Transfer-Encoding", "chunked" }
    }
  ,.body= "hello world"
  ,.num_chunks_complete= 3
  ,.chunk_lengths= { 5, 6 }
  }

#define WITH_QUOTES 12
, {.name= "with quotes"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /with_\"stupid\"_quotes?foo=\"bar\" HTTP/1.1\r\n\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= "foo=\"bar\""
  ,.fragment= ""
  ,.request_path= "/with_\"stupid\"_quotes"
  ,.request_url= "/with_\"stupid\"_quotes?foo=\"bar\""
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define APACHEBENCH_GET 13
/* The server receiving this request SHOULD NOT wait for EOF
 * to know that content-length == 0.
 * How to represent this in a unit test? message_complete_on_eof
 * Compare with NO_CONTENT_LENGTH_RESPONSE.
 */
, {.name = "apachebench get"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /test HTTP/1.0\r\n"
         "Host: 0.0.0.0:5000\r\n"
         "User-Agent: ApacheBench/2.3\r\n"
         "Accept: REPLACE_WITH_ASTERISK_SLASK_ASTERISK\r\n\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/test"
  ,.request_url= "/test"
  ,.num_headers= 3
  ,.headers= { { "Host", "0.0.0.0:5000" }
             , { "User-Agent", "ApacheBench/2.3" }
             , { "Accept", "REPLACE_WITH_ASTERISK_SLASK_ASTERISK" }
             }
  ,.body= ""
  }

#define QUERY_URL_WITH_QUESTION_MARK_GET 14
/* Some clients include '?' characters in query strings.
 */
, {.name = "query url with question mark"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /test.cgi?foo=bar?baz HTTP/1.1\r\n\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= "foo=bar?baz"
  ,.fragment= ""
  ,.request_path= "/test.cgi"
  ,.request_url= "/test.cgi?foo=bar?baz"
  ,.num_headers= 0
  ,.headers= {}
  ,.body= ""
  }

#define PREFIX_NEWLINE_GET 15
/* Some clients, especially after a POST in a keep-alive connection,
 * will send an extra CRLF before the next request
 */
, {.name = "newline prefix get"
  ,.type= HTTP_REQUEST
  ,.raw= "\r\nGET /test HTTP/1.1\r\n\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/test"
  ,.request_url= "/test"
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define UPGRADE_REQUEST 16
, {.name = "upgrade request"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /demo HTTP/1.1\r\n"
         "Host: example.com\r\n"
         "Connection: Upgrade\r\n"
         "Sec-WebSocket-Key2: 12998 5 Y3 1  .P00\r\n"
         "Sec-WebSocket-Protocol: sample\r\n"
         "Upgrade: WebSocket\r\n"
         "Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5\r\n"
         "Origin: http://example.com\r\n"
         "\r\n"
         "Hot diggity dogg"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/demo"
  ,.request_url= "/demo"
  ,.num_headers= 7
  ,.upgrade="Hot diggity dogg"
  ,.headers= { { "Host", "example.com" }
             , { "Connection", "Upgrade" }
             , { "Sec-WebSocket-Key2", "12998 5 Y3 1  .P00" }
             , { "Sec-WebSocket-Protocol", "sample" }
             , { "Upgrade", "WebSocket" }
             , { "Sec-WebSocket-Key1", "4 @1  46546xW%0l 1 5" }
             , { "Origin", "http://example.com" }
             }
  ,.body= ""
  }

#define CONNECT_REQUEST 17
, {.name = "connect request"
  ,.type= HTTP_REQUEST
  ,.raw= "CONNECT 0-home0.netscape.com:443 HTTP/1.0\r\n"
         "User-agent: Mozilla/1.1N\r\n"
         "Proxy-authorization: basic aGVsbG86d29ybGQ=\r\n"
         "\r\n"
         "some data\r\n"
         "and yet even more data"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.method= HTTP_CONNECT
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "0-home0.netscape.com:443"
  ,.num_headers= 2
  ,.upgrade="some data\r\nand yet even more data"
  ,.headers= { { "User-agent", "Mozilla/1.1N" }
             , { "Proxy-authorization", "basic aGVsbG86d29ybGQ=" }
             }
  ,.body= ""
  }

#define REPORT_REQ 18
, {.name= "report request"
  ,.type= HTTP_REQUEST
  ,.raw= "REPORT /test HTTP/1.1\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_REPORT
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/test"
  ,.request_url= "/test"
  ,.num_headers= 0
  ,.headers= {}
  ,.body= ""
  }

#define NO_HTTP_VERSION 19
, {.name= "request with no http version"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 0
  ,.http_minor= 9
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 0
  ,.headers= {}
  ,.body= ""
  }

#define MSEARCH_REQ 20
, {.name= "m-search request"
  ,.type= HTTP_REQUEST
  ,.raw= "M-SEARCH * HTTP/1.1\r\n"
         "HOST: 239.255.255.250:1900\r\n"
         "MAN: \"ssdp:discover\"\r\n"
         "ST: \"ssdp:all\"\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_MSEARCH
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "*"
  ,.request_url= "*"
  ,.num_headers= 3
  ,.headers= { { "HOST", "239.255.255.250:1900" }
             , { "MAN", "\"ssdp:discover\"" }
             , { "ST", "\"ssdp:all\"" }
             }
  ,.body= ""
  }

#define LINE_FOLDING_IN_HEADER 21
, {.name= "line folding in header value"
  ,.type= HTTP_REQUEST
  ,.raw= "GET / HTTP/1.1\r\n"
         "Line1:   abc\r\n"
         "\tdef\r\n"
         " ghi\r\n"
         "\t\tjkl\r\n"
         "  mno \r\n"
         "\t \tqrs\r\n"
         "Line2: \t line2\t\r\n"
         "Line3:\r\n"
         " line3\r\n"
         "Line4: \r\n"
         " \r\n"
         "Connection:\r\n"
         " close\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 5
  ,.headers= { { "Line1", "abc\tdef ghi\t\tjkl  mno \t \tqrs" }
             , { "Line2", "line2\t" }
             , { "Line3", "line3" }
             , { "Line4", "" }
             , { "Connection", "close" },
             }
  ,.body= ""
  }


#define QUERY_TERMINATED_HOST 22
, {.name= "host terminated by a query string"
  ,.type= HTTP_REQUEST
  ,.raw= "GET http://hypnotoad.org?hail=all HTTP/1.1\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= "hail=all"
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "http://hypnotoad.org?hail=all"
  ,.host= "hypnotoad.org"
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define QUERY_TERMINATED_HOSTPORT 23
, {.name= "host:port terminated by a query string"
  ,.type= HTTP_REQUEST
  ,.raw= "GET http://hypnotoad.org:1234?hail=all HTTP/1.1\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= "hail=all"
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "http://hypnotoad.org:1234?hail=all"
  ,.host= "hypnotoad.org"
  ,.port= 1234
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define SPACE_TERMINATED_HOSTPORT 24
, {.name= "host:port terminated by a space"
  ,.type= HTTP_REQUEST
  ,.raw= "GET http://hypnotoad.org:1234 HTTP/1.1\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "http://hypnotoad.org:1234"
  ,.host= "hypnotoad.org"
  ,.port= 1234
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define PATCH_REQ 25
, {.name = "PATCH request"
  ,.type= HTTP_REQUEST
  ,.raw= "PATCH /file.txt HTTP/1.1\r\n"
         "Host: www.example.com\r\n"
         "Content-Type: application/example\r\n"
         "If-Match: \"e0023aa4e\"\r\n"
         "Content-Length: 10\r\n"
         "\r\n"
         "cccccccccc"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_PATCH
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/file.txt"
  ,.request_url= "/file.txt"
  ,.num_headers= 4
  ,.headers= { { "Host", "www.example.com" }
             , { "Content-Type", "application/example" }
             , { "If-Match", "\"e0023aa4e\"" }
             , { "Content-Length", "10" }
             }
  ,.body= "cccccccccc"
  }

#define CONNECT_CAPS_REQUEST 26
, {.name = "connect caps request"
  ,.type= HTTP_REQUEST
  ,.raw= "CONNECT HOME0.NETSCAPE.COM:443 HTTP/1.0\r\n"
         "User-agent: Mozilla/1.1N\r\n"
         "Proxy-authorization: basic aGVsbG86d29ybGQ=\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.method= HTTP_CONNECT
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "HOME0.NETSCAPE.COM:443"
  ,.num_headers= 2
  ,.upgrade=""
  ,.headers= { { "User-agent", "Mozilla/1.1N" }
             , { "Proxy-authorization", "basic aGVsbG86d29ybGQ=" }
             }
  ,.body= ""
  }

#if !HTTP_PARSER_STRICT
#define UTF8_PATH_REQ 27
, {.name= "utf-8 path request"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /δ¶/δt/pope?q=1#narf HTTP/1.1\r\n"
         "Host: github.com\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= "q=1"
  ,.fragment= "narf"
  ,.request_path= "/δ¶/δt/pope"
  ,.request_url= "/δ¶/δt/pope?q=1#narf"
  ,.num_headers= 1
  ,.headers= { {"Host", "github.com" }
             }
  ,.body= ""
  }

#define HOSTNAME_UNDERSCORE 28
, {.name = "hostname underscore"
  ,.type= HTTP_REQUEST
  ,.raw= "CONNECT home_0.netscape.com:443 HTTP/1.0\r\n"
         "User-agent: Mozilla/1.1N\r\n"
         "Proxy-authorization: basic aGVsbG86d29ybGQ=\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.method= HTTP_CONNECT
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= ""
  ,.request_url= "home_0.netscape.com:443"
  ,.num_headers= 2
  ,.upgrade=""
  ,.headers= { { "User-agent", "Mozilla/1.1N" }
             , { "Proxy-authorization", "basic aGVsbG86d29ybGQ=" }
             }
  ,.body= ""
  }
#endif  /* !HTTP_PARSER_STRICT */

/* see https://github.com/ry/http-parser/issues/47 */
#define EAT_TRAILING_CRLF_NO_CONNECTION_CLOSE 29
, {.name = "eat CRLF between requests, no \"Connection: close\" header"
  ,.raw= "POST / HTTP/1.1\r\n"
         "Host: www.example.com\r\n"
         "Content-Type: application/x-www-form-urlencoded\r\n"
         "Content-Length: 4\r\n"
         "\r\n"
         "q=42\r\n" /* note the trailing CRLF */
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 3
  ,.upgrade= 0
  ,.headers= { { "Host", "www.example.com" }
             , { "Content-Type", "application/x-www-form-urlencoded" }
             , { "Content-Length", "4" }
             }
  ,.body= "q=42"
  }

/* see https://github.com/ry/http-parser/issues/47 */
#define EAT_TRAILING_CRLF_WITH_CONNECTION_CLOSE 30
, {.name = "eat CRLF between requests even if \"Connection: close\" is set"
  ,.raw= "POST / HTTP/1.1\r\n"
         "Host: www.example.com\r\n"
         "Content-Type: application/x-www-form-urlencoded\r\n"
         "Content-Length: 4\r\n"
         "Connection: close\r\n"
         "\r\n"
         "q=42\r\n" /* note the trailing CRLF */
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE /* input buffer isn't empty when on_message_complete is called */
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 4
  ,.upgrade= 0
  ,.headers= { { "Host", "www.example.com" }
             , { "Content-Type", "application/x-www-form-urlencoded" }
             , { "Content-Length", "4" }
             , { "Connection", "close" }
             }
  ,.body= "q=42"
  }

#define PURGE_REQ 31
, {.name = "PURGE request"
  ,.type= HTTP_REQUEST
  ,.raw= "PURGE /file.txt HTTP/1.1\r\n"
         "Host: www.example.com\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_PURGE
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/file.txt"
  ,.request_url= "/file.txt"
  ,.num_headers= 1
  ,.headers= { { "Host", "www.example.com" } }
  ,.body= ""
  }

#define SEARCH_REQ 32
, {.name = "SEARCH request"
  ,.type= HTTP_REQUEST
  ,.raw= "SEARCH / HTTP/1.1\r\n"
         "Host: www.example.com\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_SEARCH
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 1
  ,.headers= { { "Host", "www.example.com" } }
  ,.body= ""
  }

#define PROXY_WITH_BASIC_AUTH 33
, {.name= "host:port and basic_auth"
  ,.type= HTTP_REQUEST
  ,.raw= "GET http://a%12:b!&*$@hypnotoad.org:1234/toto HTTP/1.1\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.fragment= ""
  ,.request_path= "/toto"
  ,.request_url= "http://a%12:b!&*$@hypnotoad.org:1234/toto"
  ,.host= "hypnotoad.org"
  ,.userinfo= "a%12:b!&*$"
  ,.port= 1234
  ,.num_headers= 0
  ,.headers= { }
  ,.body= ""
  }

#define LINE_FOLDING_IN_HEADER_WITH_LF 34
, {.name= "line folding in header value"
  ,.type= HTTP_REQUEST
  ,.raw= "GET / HTTP/1.1\n"
         "Line1:   abc\n"
         "\tdef\n"
         " ghi\n"
         "\t\tjkl\n"
         "  mno \n"
         "\t \tqrs\n"
         "Line2: \t line2\t\n"
         "Line3:\n"
         " line3\n"
         "Line4: \n"
         " \n"
         "Connection:\n"
         " close\n"
         "\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/"
  ,.request_url= "/"
  ,.num_headers= 5
  ,.headers= { { "Line1", "abc\tdef ghi\t\tjkl  mno \t \tqrs" }
             , { "Line2", "line2\t" }
             , { "Line3", "line3" }
             , { "Line4", "" }
             , { "Connection", "close" },
             }
  ,.body= ""
  }

#define CONNECTION_MULTI 35
, {.name = "multiple connection header values with folding"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /demo HTTP/1.1\r\n"
         "Host: example.com\r\n"
         "Connection: Something,\r\n"
         " Upgrade, ,Keep-Alive\r\n"
         "Sec-WebSocket-Key2: 12998 5 Y3 1  .P00\r\n"
         "Sec-WebSocket-Protocol: sample\r\n"
         "Upgrade: WebSocket\r\n"
         "Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5\r\n"
         "Origin: http://example.com\r\n"
         "\r\n"
         "Hot diggity dogg"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/demo"
  ,.request_url= "/demo"
  ,.num_headers= 7
  ,.upgrade="Hot diggity dogg"
  ,.headers= { { "Host", "example.com" }
             , { "Connection", "Something, Upgrade, ,Keep-Alive" }
             , { "Sec-WebSocket-Key2", "12998 5 Y3 1  .P00" }
             , { "Sec-WebSocket-Protocol", "sample" }
             , { "Upgrade", "WebSocket" }
             , { "Sec-WebSocket-Key1", "4 @1  46546xW%0l 1 5" }
             , { "Origin", "http://example.com" }
             }
  ,.body= ""
  }

#define CONNECTION_MULTI_LWS 36
, {.name = "multiple connection header values with folding and lws"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /demo HTTP/1.1\r\n"
         "Connection: keep-alive, upgrade\r\n"
         "Upgrade: WebSocket\r\n"
         "\r\n"
         "Hot diggity dogg"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/demo"
  ,.request_url= "/demo"
  ,.num_headers= 2
  ,.upgrade="Hot diggity dogg"
  ,.headers= { { "Connection", "keep-alive, upgrade" }
             , { "Upgrade", "WebSocket" }
             }
  ,.body= ""
  }

#define CONNECTION_MULTI_LWS_CRLF 37
, {.name = "multiple connection header values with folding and lws"
  ,.type= HTTP_REQUEST
  ,.raw= "GET /demo HTTP/1.1\r\n"
         "Connection: keep-alive, \r\n upgrade\r\n"
         "Upgrade: WebSocket\r\n"
         "\r\n"
         "Hot diggity dogg"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_GET
  ,.query_string= ""
  ,.fragment= ""
  ,.request_path= "/demo"
  ,.request_url= "/demo"
  ,.num_headers= 2
  ,.upgrade="Hot diggity dogg"
  ,.headers= { { "Connection", "keep-alive,  upgrade" }
             , { "Upgrade", "WebSocket" }
             }
  ,.body= ""
  }

#define UPGRADE_POST_REQUEST 38
, {.name = "upgrade post request"
  ,.type= HTTP_REQUEST
  ,.raw= "POST /demo HTTP/1.1\r\n"
         "Host: example.com\r\n"
         "Connection: Upgrade\r\n"
         "Upgrade: HTTP/2.0\r\n"
         "Content-Length: 15\r\n"
         "\r\n"
         "sweet post body"
         "Hot diggity dogg"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_POST
  ,.request_path= "/demo"
  ,.request_url= "/demo"
  ,.num_headers= 4
  ,.upgrade="Hot diggity dogg"
  ,.headers= { { "Host", "example.com" }
             , { "Connection", "Upgrade" }
             , { "Upgrade", "HTTP/2.0" }
             , { "Content-Length", "15" }
             }
  ,.body= "sweet post body"
  }

#define CONNECT_WITH_BODY_REQUEST 39
, {.name = "connect with body request"
  ,.type= HTTP_REQUEST
  ,.raw= "CONNECT foo.bar.com:443 HTTP/1.0\r\n"
         "User-agent: Mozilla/1.1N\r\n"
         "Proxy-authorization: basic aGVsbG86d29ybGQ=\r\n"
         "Content-Length: 10\r\n"
         "\r\n"
         "blarfcicle"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.method= HTTP_CONNECT
  ,.request_url= "foo.bar.com:443"
  ,.num_headers= 3
  ,.upgrade="blarfcicle"
  ,.headers= { { "User-agent", "Mozilla/1.1N" }
             , { "Proxy-authorization", "basic aGVsbG86d29ybGQ=" }
             , { "Content-Length", "10" }
             }
  ,.body= ""
  }

/* Examples from the Internet draft for LINK/UNLINK methods:
 * https://tools.ietf.org/id/draft-snell-link-method-01.html#rfc.section.5
 */

#define LINK_REQUEST 40
, {.name = "link request"
  ,.type= HTTP_REQUEST
  ,.raw= "LINK /images/my_dog.jpg HTTP/1.1\r\n"
         "Host: example.com\r\n"
         "Link: <http://example.com/profiles/joe>; rel=\"tag\"\r\n"
         "Link: <http://example.com/profiles/sally>; rel=\"tag\"\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_LINK
  ,.request_path= "/images/my_dog.jpg"
  ,.request_url= "/images/my_dog.jpg"
  ,.query_string= ""
  ,.fragment= ""
  ,.num_headers= 3
  ,.headers= { { "Host", "example.com" }
             , { "Link", "<http://example.com/profiles/joe>; rel=\"tag\"" }
	     , { "Link", "<http://example.com/profiles/sally>; rel=\"tag\"" }
             }
  ,.body= ""
  }

#define UNLINK_REQUEST 41
, {.name = "link request"
  ,.type= HTTP_REQUEST
  ,.raw= "UNLINK /images/my_dog.jpg HTTP/1.1\r\n"
         "Host: example.com\r\n"
         "Link: <http://example.com/profiles/sally>; rel=\"tag\"\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.method= HTTP_UNLINK
  ,.request_path= "/images/my_dog.jpg"
  ,.request_url= "/images/my_dog.jpg"
  ,.query_string= ""
  ,.fragment= ""
  ,.num_headers= 2
  ,.headers= { { "Host", "example.com" }
	     , { "Link", "<http://example.com/profiles/sally>; rel=\"tag\"" }
             }
  ,.body= ""
  }

, {.name= NULL } /* sentinel */
*/
]
/*
/* * R E S P O N S E S * */
const struct message responses[] =
#define GOOGLE_301 0
{ {.name= "google 301"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 301 Moved Permanently\r\n"
         "Location: http://www.google.com/\r\n"
         "Content-Type: text/html; charset=UTF-8\r\n"
         "Date: Sun, 26 Apr 2009 11:11:49 GMT\r\n"
         "Expires: Tue, 26 May 2009 11:11:49 GMT\r\n"
         "X-$PrototypeBI-Version: 1.6.0.3\r\n" /* $ char in header field */
         "Cache-Control: public, max-age=2592000\r\n"
         "Server: gws\r\n"
         "Content-Length:  219  \r\n"
         "\r\n"
         "<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">\n"
         "<TITLE>301 Moved</TITLE></HEAD><BODY>\n"
         "<H1>301 Moved</H1>\n"
         "The document has moved\n"
         "<A HREF=\"http://www.google.com/\">here</A>.\r\n"
         "</BODY></HTML>\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 301
  ,.response_status= "Moved Permanently"
  ,.num_headers= 8
  ,.headers=
    { { "Location", "http://www.google.com/" }
    , { "Content-Type", "text/html; charset=UTF-8" }
    , { "Date", "Sun, 26 Apr 2009 11:11:49 GMT" }
    , { "Expires", "Tue, 26 May 2009 11:11:49 GMT" }
    , { "X-$PrototypeBI-Version", "1.6.0.3" }
    , { "Cache-Control", "public, max-age=2592000" }
    , { "Server", "gws" }
    , { "Content-Length", "219  " }
    }
  ,.body= "<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">\n"
          "<TITLE>301 Moved</TITLE></HEAD><BODY>\n"
          "<H1>301 Moved</H1>\n"
          "The document has moved\n"
          "<A HREF=\"http://www.google.com/\">here</A>.\r\n"
          "</BODY></HTML>\r\n"
  }

#define NO_CONTENT_LENGTH_RESPONSE 1
/* The client should wait for the server's EOF. That is, when content-length
 * is not specified, and "Connection: close", the end of body is specified
 * by the EOF.
 * Compare with APACHEBENCH_GET
 */
, {.name= "no content-length response"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Date: Tue, 04 Aug 2009 07:59:32 GMT\r\n"
         "Server: Apache\r\n"
         "X-Powered-By: Servlet/2.5 JSP/2.1\r\n"
         "Content-Type: text/xml; charset=utf-8\r\n"
         "Connection: close\r\n"
         "\r\n"
         "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
         "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">\n"
         "  <SOAP-ENV:Body>\n"
         "    <SOAP-ENV:Fault>\n"
         "       <faultcode>SOAP-ENV:Client</faultcode>\n"
         "       <faultstring>Client Error</faultstring>\n"
         "    </SOAP-ENV:Fault>\n"
         "  </SOAP-ENV:Body>\n"
         "</SOAP-ENV:Envelope>"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 5
  ,.headers=
    { { "Date", "Tue, 04 Aug 2009 07:59:32 GMT" }
    , { "Server", "Apache" }
    , { "X-Powered-By", "Servlet/2.5 JSP/2.1" }
    , { "Content-Type", "text/xml; charset=utf-8" }
    , { "Connection", "close" }
    }
  ,.body= "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
          "<SOAP-ENV:Envelope xmlns:SOAP-ENV=\"http://schemas.xmlsoap.org/soap/envelope/\">\n"
          "  <SOAP-ENV:Body>\n"
          "    <SOAP-ENV:Fault>\n"
          "       <faultcode>SOAP-ENV:Client</faultcode>\n"
          "       <faultstring>Client Error</faultstring>\n"
          "    </SOAP-ENV:Fault>\n"
          "  </SOAP-ENV:Body>\n"
          "</SOAP-ENV:Envelope>"
  }

#define NO_HEADERS_NO_BODY_404 2
, {.name= "404 no headers no body"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 404 Not Found\r\n\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 404
  ,.response_status= "Not Found"
  ,.num_headers= 0
  ,.headers= {}
  ,.body_size= 0
  ,.body= ""
  }

#define NO_REASON_PHRASE 3
, {.name= "301 no response phrase"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 301\r\n\r\n"
  ,.should_keep_alive = FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 301
  ,.response_status= ""
  ,.num_headers= 0
  ,.headers= {}
  ,.body= ""
  }

#define TRAILING_SPACE_ON_CHUNKED_BODY 4
, {.name="200 trailing space on chunked body"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Content-Type: text/plain\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "25  \r\n"
         "This is the data in the first chunk\r\n"
         "\r\n"
         "1C\r\n"
         "and this is the second one\r\n"
         "\r\n"
         "0  \r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 2
  ,.headers=
    { {"Content-Type", "text/plain" }
    , {"Transfer-Encoding", "chunked" }
    }
  ,.body_size = 37+28
  ,.body =
         "This is the data in the first chunk\r\n"
         "and this is the second one\r\n"
  ,.num_chunks_complete= 3
  ,.chunk_lengths= { 0x25, 0x1c }
  }

#define NO_CARRIAGE_RET 5
, {.name="no carriage ret"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\n"
         "Content-Type: text/html; charset=utf-8\n"
         "Connection: close\n"
         "\n"
         "these headers are from http://news.ycombinator.com/"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 2
  ,.headers=
    { {"Content-Type", "text/html; charset=utf-8" }
    , {"Connection", "close" }
    }
  ,.body= "these headers are from http://news.ycombinator.com/"
  }

#define PROXY_CONNECTION 6
, {.name="proxy connection"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Content-Type: text/html; charset=UTF-8\r\n"
         "Content-Length: 11\r\n"
         "Proxy-Connection: close\r\n"
         "Date: Thu, 31 Dec 2009 20:55:48 +0000\r\n"
         "\r\n"
         "hello world"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 4
  ,.headers=
    { {"Content-Type", "text/html; charset=UTF-8" }
    , {"Content-Length", "11" }
    , {"Proxy-Connection", "close" }
    , {"Date", "Thu, 31 Dec 2009 20:55:48 +0000"}
    }
  ,.body= "hello world"
  }

#define UNDERSTORE_HEADER_KEY 7
  // shown by
  // curl -o /dev/null -v "http://ad.doubleclick.net/pfadx/DARTSHELLCONFIGXML;dcmt=text/xml;"
, {.name="underscore header key"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Server: DCLK-AdSvr\r\n"
         "Content-Type: text/xml\r\n"
         "Content-Length: 0\r\n"
         "DCLK_imp: v7;x;114750856;0-0;0;17820020;0/0;21603567/21621457/1;;~okv=;dcmt=text/xml;;~cs=o\r\n\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 4
  ,.headers=
    { {"Server", "DCLK-AdSvr" }
    , {"Content-Type", "text/xml" }
    , {"Content-Length", "0" }
    , {"DCLK_imp", "v7;x;114750856;0-0;0;17820020;0/0;21603567/21621457/1;;~okv=;dcmt=text/xml;;~cs=o" }
    }
  ,.body= ""
  }

#define BONJOUR_MADAME_FR 8
/* The client should not merge two headers fields when the first one doesn't
 * have a value.
 */
, {.name= "bonjourmadame.fr"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.0 301 Moved Permanently\r\n"
         "Date: Thu, 03 Jun 2010 09:56:32 GMT\r\n"
         "Server: Apache/2.2.3 (Red Hat)\r\n"
         "Cache-Control: public\r\n"
         "Pragma: \r\n"
         "Location: http://www.bonjourmadame.fr/\r\n"
         "Vary: Accept-Encoding\r\n"
         "Content-Length: 0\r\n"
         "Content-Type: text/html; charset=UTF-8\r\n"
         "Connection: keep-alive\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.status_code= 301
  ,.response_status= "Moved Permanently"
  ,.num_headers= 9
  ,.headers=
    { { "Date", "Thu, 03 Jun 2010 09:56:32 GMT" }
    , { "Server", "Apache/2.2.3 (Red Hat)" }
    , { "Cache-Control", "public" }
    , { "Pragma", "" }
    , { "Location", "http://www.bonjourmadame.fr/" }
    , { "Vary",  "Accept-Encoding" }
    , { "Content-Length", "0" }
    , { "Content-Type", "text/html; charset=UTF-8" }
    , { "Connection", "keep-alive" }
    }
  ,.body= ""
  }

#define RES_FIELD_UNDERSCORE 9
/* Should handle spaces in header fields */
, {.name= "field underscore"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Date: Tue, 28 Sep 2010 01:14:13 GMT\r\n"
         "Server: Apache\r\n"
         "Cache-Control: no-cache, must-revalidate\r\n"
         "Expires: Mon, 26 Jul 1997 05:00:00 GMT\r\n"
         ".et-Cookie: PlaxoCS=1274804622353690521; path=/; domain=.plaxo.com\r\n"
         "Vary: Accept-Encoding\r\n"
         "_eep-Alive: timeout=45\r\n" /* semantic value ignored */
         "_onnection: Keep-Alive\r\n" /* semantic value ignored */
         "Transfer-Encoding: chunked\r\n"
         "Content-Type: text/html\r\n"
         "Connection: close\r\n"
         "\r\n"
         "0\r\n\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 11
  ,.headers=
    { { "Date", "Tue, 28 Sep 2010 01:14:13 GMT" }
    , { "Server", "Apache" }
    , { "Cache-Control", "no-cache, must-revalidate" }
    , { "Expires", "Mon, 26 Jul 1997 05:00:00 GMT" }
    , { ".et-Cookie", "PlaxoCS=1274804622353690521; path=/; domain=.plaxo.com" }
    , { "Vary", "Accept-Encoding" }
    , { "_eep-Alive", "timeout=45" }
    , { "_onnection", "Keep-Alive" }
    , { "Transfer-Encoding", "chunked" }
    , { "Content-Type", "text/html" }
    , { "Connection", "close" }
    }
  ,.body= ""
  ,.num_chunks_complete= 1
  ,.chunk_lengths= {}
  }

#define NON_ASCII_IN_STATUS_LINE 10
/* Should handle non-ASCII in status line */
, {.name= "non-ASCII in status line"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 500 Oriëntatieprobleem\r\n"
         "Date: Fri, 5 Nov 2010 23:07:12 GMT+2\r\n"
         "Content-Length: 0\r\n"
         "Connection: close\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 500
  ,.response_status= "Oriëntatieprobleem"
  ,.num_headers= 3
  ,.headers=
    { { "Date", "Fri, 5 Nov 2010 23:07:12 GMT+2" }
    , { "Content-Length", "0" }
    , { "Connection", "close" }
    }
  ,.body= ""
  }

#define HTTP_VERSION_0_9 11
/* Should handle HTTP/0.9 */
, {.name= "http version 0.9"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/0.9 200 OK\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 0
  ,.http_minor= 9
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 0
  ,.headers=
    {}
  ,.body= ""
  }

#define NO_CONTENT_LENGTH_NO_TRANSFER_ENCODING_RESPONSE 12
/* The client should wait for the server's EOF. That is, when neither
 * content-length nor transfer-encoding is specified, the end of body
 * is specified by the EOF.
 */
, {.name= "neither content-length nor transfer-encoding response"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Content-Type: text/plain\r\n"
         "\r\n"
         "hello world"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 1
  ,.headers=
    { { "Content-Type", "text/plain" }
    }
  ,.body= "hello world"
  }

#define NO_BODY_HTTP10_KA_200 13
, {.name= "HTTP/1.0 with keep-alive and EOF-terminated 200 status"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.0 200 OK\r\n"
         "Connection: keep-alive\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 0
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 1
  ,.headers=
    { { "Connection", "keep-alive" }
    }
  ,.body_size= 0
  ,.body= ""
  }

#define NO_BODY_HTTP10_KA_204 14
, {.name= "HTTP/1.0 with keep-alive and a 204 status"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.0 204 No content\r\n"
         "Connection: keep-alive\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 0
  ,.status_code= 204
  ,.response_status= "No content"
  ,.num_headers= 1
  ,.headers=
    { { "Connection", "keep-alive" }
    }
  ,.body_size= 0
  ,.body= ""
  }

#define NO_BODY_HTTP11_KA_200 15
, {.name= "HTTP/1.1 with an EOF-terminated 200 status"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 0
  ,.headers={}
  ,.body_size= 0
  ,.body= ""
  }

#define NO_BODY_HTTP11_KA_204 16
, {.name= "HTTP/1.1 with a 204 status"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 204 No content\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 204
  ,.response_status= "No content"
  ,.num_headers= 0
  ,.headers={}
  ,.body_size= 0
  ,.body= ""
  }

#define NO_BODY_HTTP11_NOKA_204 17
, {.name= "HTTP/1.1 with a 204 status and keep-alive disabled"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 204 No content\r\n"
         "Connection: close\r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 204
  ,.response_status= "No content"
  ,.num_headers= 1
  ,.headers=
    { { "Connection", "close" }
    }
  ,.body_size= 0
  ,.body= ""
  }

#define NO_BODY_HTTP11_KA_CHUNKED_200 18
, {.name= "HTTP/1.1 with chunked endocing and a 200 response"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "0\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 1
  ,.headers=
    { { "Transfer-Encoding", "chunked" }
    }
  ,.body_size= 0
  ,.body= ""
  ,.num_chunks_complete= 1
  }

#if !HTTP_PARSER_STRICT
#define SPACE_IN_FIELD_RES 19
/* Should handle spaces in header fields */
, {.name= "field space"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Server: Microsoft-IIS/6.0\r\n"
         "X-Powered-By: ASP.NET\r\n"
         "en-US Content-Type: text/xml\r\n" /* this is the problem */
         "Content-Type: text/xml\r\n"
         "Content-Length: 16\r\n"
         "Date: Fri, 23 Jul 2010 18:45:38 GMT\r\n"
         "Connection: keep-alive\r\n"
         "\r\n"
         "<xml>hello</xml>" /* fake body */
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 7
  ,.headers=
    { { "Server",  "Microsoft-IIS/6.0" }
    , { "X-Powered-By", "ASP.NET" }
    , { "en-US Content-Type", "text/xml" }
    , { "Content-Type", "text/xml" }
    , { "Content-Length", "16" }
    , { "Date", "Fri, 23 Jul 2010 18:45:38 GMT" }
    , { "Connection", "keep-alive" }
    }
  ,.body= "<xml>hello</xml>"
  }
#endif /* !HTTP_PARSER_STRICT */

#define AMAZON_COM 20
, {.name= "amazon.com"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 301 MovedPermanently\r\n"
         "Date: Wed, 15 May 2013 17:06:33 GMT\r\n"
         "Server: Server\r\n"
         "x-amz-id-1: 0GPHKXSJQ826RK7GZEB2\r\n"
         "p3p: policyref=\"http://www.amazon.com/w3c/p3p.xml\",CP=\"CAO DSP LAW CUR ADM IVAo IVDo CONo OTPo OUR DELi PUBi OTRi BUS PHY ONL UNI PUR FIN COM NAV INT DEM CNT STA HEA PRE LOC GOV OTC \"\r\n"
         "x-amz-id-2: STN69VZxIFSz9YJLbz1GDbxpbjG6Qjmmq5E3DxRhOUw+Et0p4hr7c/Q8qNcx4oAD\r\n"
         "Location: http://www.amazon.com/Dan-Brown/e/B000AP9DSU/ref=s9_pop_gw_al1?_encoding=UTF8&refinementId=618073011&pf_rd_m=ATVPDKIKX0DER&pf_rd_s=center-2&pf_rd_r=0SHYY5BZXN3KR20BNFAY&pf_rd_t=101&pf_rd_p=1263340922&pf_rd_i=507846\r\n"
         "Vary: Accept-Encoding,User-Agent\r\n"
         "Content-Type: text/html; charset=ISO-8859-1\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "1\r\n"
         "\n\r\n"
         "0\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 301
  ,.response_status= "MovedPermanently"
  ,.num_headers= 9
  ,.headers= { { "Date", "Wed, 15 May 2013 17:06:33 GMT" }
             , { "Server", "Server" }
             , { "x-amz-id-1", "0GPHKXSJQ826RK7GZEB2" }
             , { "p3p", "policyref=\"http://www.amazon.com/w3c/p3p.xml\",CP=\"CAO DSP LAW CUR ADM IVAo IVDo CONo OTPo OUR DELi PUBi OTRi BUS PHY ONL UNI PUR FIN COM NAV INT DEM CNT STA HEA PRE LOC GOV OTC \"" }
             , { "x-amz-id-2", "STN69VZxIFSz9YJLbz1GDbxpbjG6Qjmmq5E3DxRhOUw+Et0p4hr7c/Q8qNcx4oAD" }
             , { "Location", "http://www.amazon.com/Dan-Brown/e/B000AP9DSU/ref=s9_pop_gw_al1?_encoding=UTF8&refinementId=618073011&pf_rd_m=ATVPDKIKX0DER&pf_rd_s=center-2&pf_rd_r=0SHYY5BZXN3KR20BNFAY&pf_rd_t=101&pf_rd_p=1263340922&pf_rd_i=507846" }
             , { "Vary", "Accept-Encoding,User-Agent" }
             , { "Content-Type", "text/html; charset=ISO-8859-1" }
             , { "Transfer-Encoding", "chunked" }
             }
  ,.body= "\n"
  ,.num_chunks_complete= 2
  ,.chunk_lengths= { 1 }
  }

#define EMPTY_REASON_PHRASE_AFTER_SPACE 20
, {.name= "empty reason phrase after space"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 \r\n"
         "\r\n"
  ,.should_keep_alive= FALSE
  ,.message_complete_on_eof= TRUE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= ""
  ,.num_headers= 0
  ,.headers= {}
  ,.body= ""
  }

#define CONTENT_LENGTH_X 21
, {.name= "Content-Length-X"
  ,.type= HTTP_RESPONSE
  ,.raw= "HTTP/1.1 200 OK\r\n"
         "Content-Length-X: 0\r\n"
         "Transfer-Encoding: chunked\r\n"
         "\r\n"
         "2\r\n"
         "OK\r\n"
         "0\r\n"
         "\r\n"
  ,.should_keep_alive= TRUE
  ,.message_complete_on_eof= FALSE
  ,.http_major= 1
  ,.http_minor= 1
  ,.status_code= 200
  ,.response_status= "OK"
  ,.num_headers= 2
  ,.headers= { { "Content-Length-X", "0" }
             , { "Transfer-Encoding", "chunked" }
             }
  ,.body= "OK"
  ,.num_chunks_complete= 2
  ,.chunk_lengths= { 2 }
  }

, {.name= NULL } /* sentinel */
};

size_t
strlncpy(char *dst, size_t len, const char *src, size_t n)
{
  size_t slen;
  size_t ncpy;

  slen = strnlen(src, n);

  if (len > 0) {
    ncpy = slen < len ? slen : (len - 1);
    memcpy(dst, src, ncpy);
    dst[ncpy] = '\0';
  }

  assert(len > slen);
  return slen;
}
*/

func callbackString(_ at: UnsafePointer<UInt8>, _ length: Int) -> UnsafeBufferPointer<UInt8> {
    return UnsafeBufferPointer(start: at, count: length)
}

func request_url_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  messages[num_messages].request_url += String(bytes: callbackString(buf, len),
                                               encoding: .utf8)!
  return 0
}

func header_field_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  if (message_results[num_messages].last_header_element != .FIELD) {
    messages[num_messages].num_headers += 1
  }
  
  if messages[num_messages].headers.count == 0 {
    for _ in 0..<MAX_HEADERS {
       messages[num_messages].headers.append([String](repeating: "", count: 2))
    }
  }

  messages[num_messages].headers[messages[num_messages].num_headers-1][0] +=
  String(bytes: callbackString(buf, len), encoding: .utf8)!

  message_results[num_messages].last_header_element = .FIELD

  return 0
}

func header_value_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  messages[num_messages].headers[messages[num_messages].num_headers-1][1] +=
      String(bytes: callbackString(buf, len), encoding: .utf8)!

  message_results[num_messages].last_header_element = .VALUE

  return 0
}

func check_body_is_final ()
{
  if (message_results[num_messages].body_is_final) {
    print("\n\n *** Error http_body_is_final() should return 1 " +
                    "on last on_body callback call " +
                    "but it doesn't! ***\n\n")
    XCTFail()
  }
  message_results[num_messages].body_is_final = parser!.body_is_final()
}

func body_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  messages[num_messages].body += String(bytes: callbackString(buf, len),
                                        encoding: .utf8)!
  message_results[num_messages].body_size += len
  check_body_is_final()
  //print("body_cb: \(messages[num_messages].body)")
  return 0
}

func count_body_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  message_results[num_messages].body_size += len
  check_body_is_final()
  return 0
}

func message_begin_cb () -> Int
{
  message_results[num_messages].message_begin_cb_called = true
  return 0
}

func headers_complete_cb () -> Int
{
  messages[num_messages].method = parser!.method
  //messages[num_messages].status_code = parser!.status_code
  messages[num_messages].http_major = parser!.http_major
  messages[num_messages].http_minor = parser!.http_minor
  message_results[num_messages].headers_complete_cb_called = true
  messages[num_messages].should_keep_alive = parser!.should_keep_alive()
  return 0
}

func message_complete_cb () -> Int
{
  if (messages[num_messages].should_keep_alive != parser!.should_keep_alive())
  {
    print("\n\n *** Error http_should_keep_alive() should have same " +
                    "value in both on_message_complete and on_headers_complete " +
                    "but it doesn't! ***\n\n")
    XCTFail()
  }

  /*if (messages[num_messages].body_size &&
      parser!.body_is_final() &&
      !messages[num_messages].body_is_final)
  {
    print("\n\n *** Error http_body_is_final() should return 1 " +
                    "on last on_body callback call " +
                    "but it doesn't! ***\n\n")
   XCTFail()
  }*/

  message_results[num_messages].message_complete_cb_called = true

  messages[num_messages].message_complete_on_eof = currently_parsing_eof;

  num_messages += 1
  return 0;
}

func response_status_cb (_ buf: UnsafePointer<UInt8>, _ length: Int) -> Int
{
  message_results[num_messages].response_status += String(bytes:
  callbackString(buf, length), encoding: .utf8)!
  return 0
}

func chunk_header_cb () ->Int
{
  let chunk_idx = message_results[num_messages].num_chunks
  message_results[num_messages].num_chunks += 1
  if (chunk_idx < MAX_CHUNKS) {
    message_results[num_messages].chunk_lengths[chunk_idx] = parser!.content_length
  }

  return 0;
}

func chunk_complete_cb () ->Int
{
  /* Here we want to verify that each chunk_header_cb is matched by a
   * chunk_complete_cb, so not only should the total number of calls to
   * both callbacks be the same, but they also should be interleaved
   * properly */
  XCTAssertTrue(message_results[num_messages].num_chunks ==
         message_results[num_messages].num_chunks_complete + 1)

  message_results[num_messages].num_chunks_complete += 1
  return 0
}

/* These dontcall_* callbacks exist so that we can verify that when we're
 * paused, no additional callbacks are invoked */
func dontcall_message_begin_cb () -> Int
{
  print("\n\n*** on_message_begin() called on paused parser ***\n\n");
  XCTFail()
  return 0
}

func dontcall_header_field_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  print("\n\n*** on_header_field() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_header_value_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  print("\n\n*** on_header_value() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_request_url_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  print("\n\n*** on_request_url() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_body_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  print("\n\n*** on_body_cb() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_headers_complete_cb () -> Int
{
  print("\n\n*** on_headers_complete() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_message_complete_cb () -> Int
{
  print("\n\n*** on_message_complete() called on paused parser ***\n\n");
  XCTFail()
  return 0
}

func dontcall_response_status_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  print("\n\n*** on_status() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_chunk_header_cb () -> Int
{
  print("\n\n*** on_chunk_header() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func dontcall_chunk_complete_cb () -> Int
{
  print("\n\n*** on_chunk_complete() called on paused parser ***\n\n")
  XCTFail()
  return 0
}

func settings_dontcall() -> http_parser_delegate {
    return http_parser_delegate(
  on_message_begin: dontcall_message_begin_cb,
  on_url: dontcall_request_url_cb,
  on_status: dontcall_response_status_cb,
  on_header_field: dontcall_header_field_cb,
  on_header_value: dontcall_header_value_cb,
  on_headers_complete: dontcall_headers_complete_cb,
  on_body: dontcall_body_cb,
  on_message_complete: dontcall_message_complete_cb,
  on_chunk_header: dontcall_chunk_header_cb,
  on_chunk_complete: dontcall_chunk_complete_cb)
}

/* These pause_* callbacks always pause the parser and just invoke the regular
 * callback that tracks content. Before returning, we overwrite the parser
 * settings to point to the _dontcall variety so that we can verify that
 * the pause actually did, you know, pause. */
func pause_message_begin_cb () -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return message_begin_cb()
}

func pause_header_field_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return header_field_cb(buf, len)
}

func pause_header_value_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return header_value_cb(buf, len)
}

func pause_request_url_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return request_url_cb(buf, len)
}

func pause_body_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return body_cb(buf, len)
}

func pause_headers_complete_cb () -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return headers_complete_cb()
}

func pause_message_complete_cb () -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return message_complete_cb()
}

func pause_response_status_cb (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return response_status_cb(buf, len)
}

func pause_chunk_header_cb () -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return chunk_header_cb()
}

func pause_chunk_complete_cb () -> Int
{
  parser!.pause(true)
  current_pause_parser = settings_dontcall()
  return chunk_complete_cb()
}

func connect_headers_complete_cb () -> Int
{
  let _ = headers_complete_cb()
  return 1
}

func connect_message_complete_cb () -> Int
{
  messages[num_messages].should_keep_alive = parser!.should_keep_alive()
  return message_complete_cb()
}

func settings_pause() -> http_parser_delegate {
    return http_parser_delegate(
  on_message_begin: pause_message_begin_cb,
  on_url: pause_request_url_cb,
  on_status: pause_response_status_cb,
  on_header_field: pause_header_field_cb,
  on_header_value: pause_header_value_cb,
  on_headers_complete: pause_headers_complete_cb,
  on_body: pause_body_cb,
  on_message_complete: pause_message_complete_cb,
  on_chunk_header: pause_chunk_header_cb,
  on_chunk_complete: pause_chunk_complete_cb)
}

func settings() -> http_parser_delegate {
    return http_parser_delegate(
  on_message_begin: message_begin_cb,
  on_url: request_url_cb,
  on_status: response_status_cb,
  on_header_field: header_field_cb,
  on_header_value: header_value_cb,
  on_headers_complete: headers_complete_cb,
  on_body: body_cb,
  on_message_complete: message_complete_cb,
  on_chunk_header: chunk_header_cb,
  on_chunk_complete: chunk_complete_cb)
}
/*
static http_parser_settings settings_count_body =
  {.on_message_begin = message_begin_cb
  ,.on_url = request_url_cb
  ,.on_status = response_status_cb
  ,.on_header_field = header_field_cb
  ,.on_header_value = header_value_cb
  ,.on_headers_complete = headers_complete_cb
  ,.on_body = count_body_cb
  ,.on_message_complete = message_complete_cb
  ,.on_chunk_header = chunk_header_cb
  ,.on_chunk_complete = chunk_complete_cb
  };

static http_parser_settings settings_connect =
  {.on_message_begin = message_begin_cb
  ,.on_url = request_url_cb
  ,.on_status = response_status_cb
  ,.on_header_field = header_field_cb
  ,.on_header_value = header_value_cb
  ,.on_headers_complete = connect_headers_complete_cb
  ,.on_body = dontcall_body_cb
  ,.on_message_complete = connect_message_complete_cb
  ,.on_chunk_header = chunk_header_cb
  ,.on_chunk_complete = chunk_complete_cb
  };
*/

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
func  settings_null() -> http_parser_delegate {
    return   http_parser_delegate(
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
}


func parser_init (_ type: http_parser_type)
{
  num_messages = 0

  assert(parser == nil)

  parser = http_parser(t: type)

  parser?.reset(type)

  messages = [message](repeating: message(), count: MAX_MESSAGE_TESTS)

}

func parser_free ()
{
  assert(parser != nil)
  parser = nil
}

@discardableResult
func parse (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  currently_parsing_eof = (len == 0)
  parser!.delegate = settings()
  let nparsed = parser!.execute( buf, len)
  return nparsed
}

@discardableResult
func parse (string: String) -> Int
{
  return parse(string, string.utf8.count)
}

/*
size_t parse_count_body (const char *buf, size_t len)
{
  size_t nparsed;
  currently_parsing_eof = (len == 0);
  nparsed = http_parser_execute(parser, &settings_count_body, buf, len);
  return nparsed;
}
*/
func parse_pause (_ buf: UnsafePointer<UInt8>, _ len: Int) -> Int
{
  var nparsed = 0
  let s = settings_pause()

  currently_parsing_eof = (len == 0);
  current_pause_parser = s
  parser!.delegate = current_pause_parser!
  nparsed = parser!.execute( buf, len)
  return nparsed
}
/*
size_t parse_connect (const char *buf, size_t len)
{
  size_t nparsed;
  currently_parsing_eof = (len == 0);
  nparsed = http_parser_execute(parser, &settings_connect, buf, len);
  return nparsed;
}

static inline int
check_str_eq (const struct message *m,
              const char *prop,
              const char *expected,
              const char *found) {
  if ((expected == NULL) != (found == NULL)) {
    printf("\n*** Error: %s in '%s' ***\n\n", prop, m->name);
    printf("expected %s\n", (expected == NULL) ? "NULL" : expected);
    printf("   found %s\n", (found == NULL) ? "NULL" : found);
    return 0;
  }
  if (expected != NULL && 0 != strcmp(expected, found)) {
    printf("\n*** Error: %s in '%s' ***\n\n", prop, m->name);
    printf("expected '%s'\n", expected);
    printf("   found '%s'\n", found);
    return 0;
  }
  return 1;
}

static inline int
check_num_eq (const struct message *m,
              const char *prop,
              int expected,
              int found) {
  if (expected != found) {
    printf("\n*** Error: %s in '%s' ***\n\n", prop, m->name);
    printf("expected %d\n", expected);
    printf("   found %d\n", found);
    return 0;
  }
  return 1;
}

#define MESSAGE_CHECK_STR_EQ(expected, found, prop) \
  if (!check_str_eq(expected, #prop, expected->prop, found->prop)) return 0

#define MESSAGE_CHECK_NUM_EQ(expected, found, prop) \
  if (!check_num_eq(expected, #prop, expected->prop, found->prop)) return 0

#define MESSAGE_CHECK_URL_EQ(u, expected, found, prop, fn)           \
do {                                                                 \
  char ubuf[256];                                                    \
                                                                     \
  if ((u)->field_set & (1 << (fn))) {                                \
    memcpy(ubuf, (found)->request_url + (u)->field_data[(fn)].off,   \
      (u)->field_data[(fn)].len);                                    \
    ubuf[(u)->field_data[(fn)].len] = '\0';                          \
  } else {                                                           \
    ubuf[0] = '\0';                                                  \
  }                                                                  \
                                                                     \
  check_str_eq(expected, #prop, expected->prop, ubuf);               \
} while(0)
*/
func message_eq (_ index: Int, _ connect: Int, _ expected: message) -> Bool
{
  let m = messages[index]
  let r = message_results[index]

  XCTAssertEqual(expected.http_major, m.http_major)
  XCTAssertEqual(expected.http_minor, m.http_minor)

  if (expected.type == .HTTP_REQUEST) {
    XCTAssertEqual(expected.method, m.method)
  } else {
    //XCTAssertEqual(expected.status_code, m.status_code)
    //XCTAssertEqual(expected.response_status, m.response_status)
  }

  if (connect == 0) {
    XCTAssertEqual(expected.should_keep_alive, m.should_keep_alive);
    XCTAssertEqual(expected.should_keep_alive, m.should_keep_alive);
  }

  XCTAssertTrue(r.message_begin_cb_called)
  XCTAssertTrue(r.headers_complete_cb_called)
  XCTAssertTrue(r.message_complete_cb_called)


  XCTAssertEqual(expected.request_url, m.request_url)

  /* Check URL components; we can't do this w/ CONNECT since it doesn't
   * send us a well-formed URL.
   */
  /*if (*m->request_url && m->method != HTTP_CONNECT) {
    struct http_parser_url u;

    if (http_parser_parse_url(m->request_url, strlen(m->request_url), 0, &u)) {
      fprintf(stderr, "\n\n*** failed to parse URL %s ***\n\n",
        m->request_url);
      abort();
    }

    if (expected->host) {
      MESSAGE_CHECK_URL_EQ(&u, expected, m, host, UF_HOST);
    }

    if (expected->userinfo) {
      MESSAGE_CHECK_URL_EQ(&u, expected, m, userinfo, UF_USERINFO);
    }

    m->port = (u.field_set & (1 << UF_PORT)) ?
      u.port : 0;

    MESSAGE_CHECK_URL_EQ(&u, expected, m, query_string, UF_QUERY);
    MESSAGE_CHECK_URL_EQ(&u, expected, m, fragment, UF_FRAGMENT);
    MESSAGE_CHECK_URL_EQ(&u, expected, m, request_path, UF_PATH);
    MESSAGE_CHECK_NUM_EQ(expected, m, port);
  }*/

  if (connect != 0) {
    //XCTAssertEqual(0, m.body_size)
  } /*else if (expected.body_size != 0) {
    XCTAssertEqual(expected.body_size, m.body_size)
  } else {
    XCTAssertEqual(expected.body, m.body)
  }*/

  /*if (connect) {
    XCTAssertEqual(0, m.num_chunks_complete)
  } else {
    XCTAssertTrue(m.num_chunks == m.num_chunks_complete)
    XCTAssertEqual(expected.num_chunks_complete, m.num_chunks_complete)
    for i in 0..<m.num_chunks {
      XCTAssertEqual(expected.chunk_lengths[i], m.chunk_lengths[i])
    }
  }*/

  XCTAssertEqual(expected.num_headers, m.num_headers)

  for i in 0..<m.num_headers {
    XCTAssertEqual(expected.headers[i][0], m.headers[i][0])
    XCTAssertEqual(expected.headers[i][1], m.headers[i][1])
  }

  XCTAssertEqual(expected.upgrade, m.upgrade)

  return true
}
/*
/* Given a sequence of varargs messages, return the number of them that the
 * parser should successfully parse, taking into account that upgraded
 * messages prevent all subsequent messages from being parsed.
 */
size_t
count_parsed_messages(const size_t nmsgs, ...) {
  size_t i;
  va_list ap;

  va_start(ap, nmsgs);

  for (i = 0; i < nmsgs; i++) {
    struct message *m = va_arg(ap, struct message *);

    if (m->upgrade) {
      va_end(ap);
      return i + 1;
    }
  }

  va_end(ap);
  return nmsgs;
}

/* Given a sequence of bytes and the number of these that we were able to
 * parse, verify that upgrade bodies are correct.
 */
void
upgrade_message_fix(char *body, const size_t nread, const size_t nmsgs, ...) {
  va_list ap;
  size_t i;
  size_t off = 0;

  va_start(ap, nmsgs);

  for (i = 0; i < nmsgs; i++) {
    struct message *m = va_arg(ap, struct message *);

    off += strlen(m->raw);

    if (m->upgrade) {
      off -= strlen(m->upgrade);

      /* Check the portion of the response after its specified upgrade */
      if (!check_str_eq(m, "upgrade", body + off, body + nread)) {
        abort();
      }

      /* Fix up the response so that message_eq() will verify the beginning
       * of the upgrade */
      *(body + nread + strlen(m->upgrade)) = '\0';
      messages[num_messages -1 ].upgrade = body + nread;

      va_end(ap);
      return;
    }
  }

  va_end(ap);
  printf("\n\n*** Error: expected a message with upgrade ***\n");

  abort();
}
*/
func print_error (_ raw: String, _ error_location: Int)
{
  print("\n*** \(http_parser.errno_description(HTTP_PARSER_ERRNO(parser))) ***\n\n")

  /*int this_line = 0, char_len = 0;
  size_t i, j, len = strlen(raw), error_location_line = 0;
  for (i = 0; i < len; i++) {
    if (i == error_location) this_line = 1;
    switch (raw[i]) {
      case '\r':
        char_len = 2;
        fprintf(stderr, "\\r");
        break;

      case '\n':
        fprintf(stderr, "\\n\n");

        if (this_line) goto print;

        error_location_line = 0;
        continue;

      default:
        char_len = 1;
        fputc(raw[i], stderr);
        break;
    }
    if (!this_line) error_location_line += char_len;
  }

  fprintf(stderr, "[eof]\n");

 print:
  for (j = 0; j < error_location_line; j++) {
    fputc(' ', stderr);
  }
 */
  print("^\n\nerror location: \(error_location)\n")
}
/*
struct url_test {
  const char *name;
  const char *url;
  int is_connect;
  struct http_parser_url u;
  int rv;
};

const struct url_test url_tests[] =
{ {.name="proxy request"
  ,.url="http://hostname/"
  ,.is_connect=0
  ,.u=
    {.field_set=(1 << UF_SCHEMA) | (1 << UF_HOST) | (1 << UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  7,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 15,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="proxy request with port"
  ,.url="http://hostname:444/"
  ,.is_connect=0
  ,.u=
    {.field_set=(1 << UF_SCHEMA) | (1 << UF_HOST) | (1 << UF_PORT) | (1 << UF_PATH)
    ,.port=444
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  7,  8 } /* UF_HOST */
      ,{ 16,  3 } /* UF_PORT */
      ,{ 19,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="CONNECT request"
  ,.url="hostname:443"
  ,.is_connect=1
  ,.u=
    {.field_set=(1 << UF_HOST) | (1 << UF_PORT)
    ,.port=443
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  0,  8 } /* UF_HOST */
      ,{  9,  3 } /* UF_PORT */
      ,{  0,  0 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="CONNECT request but not connect"
  ,.url="hostname:443"
  ,.is_connect=0
  ,.rv=1
  }

, {.name="proxy ipv6 request"
  ,.url="http://[1:2::3:4]/"
  ,.is_connect=0
  ,.u=
    {.field_set=(1 << UF_SCHEMA) | (1 << UF_HOST) | (1 << UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 17,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="proxy ipv6 request with port"
  ,.url="http://[1:2::3:4]:67/"
  ,.is_connect=0
  ,.u=
    {.field_set=(1 << UF_SCHEMA) | (1 << UF_HOST) | (1 << UF_PORT) | (1 << UF_PATH)
    ,.port=67
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8,  8 } /* UF_HOST */
      ,{ 18,  2 } /* UF_PORT */
      ,{ 20,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="CONNECT ipv6 address"
  ,.url="[1:2::3:4]:443"
  ,.is_connect=1
  ,.u=
    {.field_set=(1 << UF_HOST) | (1 << UF_PORT)
    ,.port=443
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  1,  8 } /* UF_HOST */
      ,{ 11,  3 } /* UF_PORT */
      ,{  0,  0 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="ipv4 in ipv6 address"
  ,.url="http://[2001:0000:0000:0000:0000:0000:1.9.1.1]/"
  ,.is_connect=0
  ,.u=
    {.field_set=(1 << UF_SCHEMA) | (1 << UF_HOST) | (1 << UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8, 37 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 46,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="extra ? in query string"
  ,.url="http://a.tbcdn.cn/p/fp/2010c/??fp-header-min.css,fp-base-min.css,"
  "fp-channel-min.css,fp-product-min.css,fp-mall-min.css,fp-category-min.css,"
  "fp-sub-min.css,fp-gdp4p-min.css,fp-css3-min.css,fp-misc-min.css?t=20101022.css"
  ,.is_connect=0
  ,.u=
    {.field_set=(1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH) | (1<<UF_QUERY)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  7, 10 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 17, 12 } /* UF_PATH */
      ,{ 30,187 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="space URL encoded"
  ,.url="/toto.html?toto=a%20b"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_PATH) | (1<<UF_QUERY)
    ,.port=0
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  0,  0 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{  0, 10 } /* UF_PATH */
      ,{ 11, 10 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }


, {.name="URL fragment"
  ,.url="/toto.html#titi"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_PATH) | (1<<UF_FRAGMENT)
    ,.port=0
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  0,  0 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{  0, 10 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{ 11,  4 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="complex URL fragment"
  ,.url="http://www.webmasterworld.com/r.cgi?f=21&d=8405&url="
    "http://www.example.com/index.html?foo=bar&hello=world#midpage"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH) | (1<<UF_QUERY) |\
      (1<<UF_FRAGMENT)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  7, 22 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 29,  6 } /* UF_PATH */
      ,{ 36, 69 } /* UF_QUERY */
      ,{106,  7 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="complex URL from node js url parser doc"
  ,.url="http://host.com:8080/p/a/t/h?query=string#hash"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PORT) | (1<<UF_PATH) |\
      (1<<UF_QUERY) | (1<<UF_FRAGMENT)
    ,.port=8080
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  7,  8 } /* UF_HOST */
      ,{ 16,  4 } /* UF_PORT */
      ,{ 20,  8 } /* UF_PATH */
      ,{ 29, 12 } /* UF_QUERY */
      ,{ 42,  4 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="complex URL with basic auth from node js url parser doc"
  ,.url="http://a:b@host.com:8080/p/a/t/h?query=string#hash"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PORT) | (1<<UF_PATH) |\
      (1<<UF_QUERY) | (1<<UF_FRAGMENT) | (1<<UF_USERINFO)
    ,.port=8080
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{ 11,  8 } /* UF_HOST */
      ,{ 20,  4 } /* UF_PORT */
      ,{ 24,  8 } /* UF_PATH */
      ,{ 33, 12 } /* UF_QUERY */
      ,{ 46,  4 } /* UF_FRAGMENT */
      ,{  7,  3 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="double @"
  ,.url="http://a:b@@hostname:443/"
  ,.is_connect=0
  ,.rv=1
  }

, {.name="proxy empty host"
  ,.url="http://:443/"
  ,.is_connect=0
  ,.rv=1
  }

, {.name="proxy empty port"
  ,.url="http://hostname:/"
  ,.is_connect=0
  ,.rv=1
  }

, {.name="CONNECT with basic auth"
  ,.url="a:b@hostname:443"
  ,.is_connect=1
  ,.rv=1
  }

, {.name="CONNECT empty host"
  ,.url=":443"
  ,.is_connect=1
  ,.rv=1
  }

, {.name="CONNECT empty port"
  ,.url="hostname:"
  ,.is_connect=1
  ,.rv=1
  }

, {.name="CONNECT with extra bits"
  ,.url="hostname:443/"
  ,.is_connect=1
  ,.rv=1
  }

, {.name="space in URL"
  ,.url="/foo bar/"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy basic auth with space url encoded"
  ,.url="http://a%20:b@host.com/"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH) | (1<<UF_USERINFO)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{ 14,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 22,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  7,  6 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="carriage return in URL"
  ,.url="/foo\rbar/"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy double : in URL"
  ,.url="http://hostname::443/"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy basic auth with double :"
  ,.url="http://a::b@host.com/"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH) | (1<<UF_USERINFO)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{ 12,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 20,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  7,  4 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="line feed in URL"
  ,.url="/foo\nbar/"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy empty basic auth"
  ,.url="http://@hostname/fo"
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 16,  3 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }
, {.name="proxy line feed in hostname"
  ,.url="http://host\name/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy % in hostname"
  ,.url="http://host%name/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy ; in hostname"
  ,.url="http://host;ame/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy basic auth with unreservedchars"
  ,.url="http://a!;-_!=+$@host.com/"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH) | (1<<UF_USERINFO)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{ 17,  8 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 25,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  7,  9 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="proxy only empty basic auth"
  ,.url="http://@/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy only basic auth"
  ,.url="http://toto@/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy emtpy hostname"
  ,.url="http:///fo"
  ,.rv=1 /* s_dead */
  }

, {.name="proxy = in URL"
  ,.url="http://host=ame/fo"
  ,.rv=1 /* s_dead */
  }

, {.name="ipv6 address with Zone ID"
  ,.url="http://[fe80::a%25eth0]/"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8, 14 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 23,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="ipv6 address with Zone ID, but '%' is not percent-encoded"
  ,.url="http://[fe80::a%eth0]/"
  ,.is_connect=0
  ,.u=
    {.field_set= (1<<UF_SCHEMA) | (1<<UF_HOST) | (1<<UF_PATH)
    ,.port=0
    ,.field_data=
      {{  0,  4 } /* UF_SCHEMA */
      ,{  8, 12 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{ 21,  1 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="ipv6 address ending with '%'"
  ,.url="http://[fe80::a%]/"
  ,.rv=1 /* s_dead */
  }

, {.name="ipv6 address with Zone ID including bad character"
  ,.url="http://[fe80::a%$HOME]/"
  ,.rv=1 /* s_dead */
  }

, {.name="just ipv6 Zone ID"
  ,.url="http://[%eth0]/"
  ,.rv=1 /* s_dead */
  }

#if HTTP_PARSER_STRICT

, {.name="tab in URL"
  ,.url="/foo\tbar/"
  ,.rv=1 /* s_dead */
  }

, {.name="form feed in URL"
  ,.url="/foo\fbar/"
  ,.rv=1 /* s_dead */
  }

#else /* !HTTP_PARSER_STRICT */

, {.name="tab in URL"
  ,.url="/foo\tbar/"
  ,.u=
    {.field_set=(1 << UF_PATH)
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  0,  0 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{  0,  9 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }

, {.name="form feed in URL"
  ,.url="/foo\fbar/"
  ,.u=
    {.field_set=(1 << UF_PATH)
    ,.field_data=
      {{  0,  0 } /* UF_SCHEMA */
      ,{  0,  0 } /* UF_HOST */
      ,{  0,  0 } /* UF_PORT */
      ,{  0,  9 } /* UF_PATH */
      ,{  0,  0 } /* UF_QUERY */
      ,{  0,  0 } /* UF_FRAGMENT */
      ,{  0,  0 } /* UF_USERINFO */
      }
    }
  ,.rv=0
  }
#endif
};
*/
func test_method_str ()
{
    "GET".withCString { bytesInt8 in
        http_parser.method_str(.HTTP_GET).utf8Start.withMemoryRebound(to:
        Int8.self, capacity: 3) { getBytes in
          assert(0 == strcmp(bytesInt8, getBytes))
        }
    }
}


public enum goto: Error { case test }

func characters(_ chars: [UInt8], start: Int, length: Int) -> String {
  var bytes = [UInt8]()
  for x in start..<start+length {
    bytes.append(chars[x])
  }
  return String(data: Data(bytes: bytes, count: bytes.count), encoding: .utf8) ?? ""
}

func test_message (_ message: message)
{
  let raw_len:Int = message.raw.utf8.count
  var msg1len:Int = 0
  
  let chars = Array(message.raw.utf8)
  
  while msg1len < raw_len {
    parser_init(message.type)

    var read = 0
    let msg1 = characters(chars, start: 0, length: msg1len)
    let msg2len = raw_len - msg1len
    let msg2 = characters(chars, start: msg1len, length: msg2len)
    do {

    if (msg1len > 0) {
      read = parse(string: msg1)

      if (message.upgrade.isEmpty == false && parser!.upgrade && num_messages > 0) {
        messages[num_messages - 1].upgrade = characters(chars, start: 0, length: read)
        throw goto.test
      }

      if (read != msg1len) {
        print_error(msg1, read);
        abort();
      }
    }


    read = parse(string: msg2)

    if (message.upgrade.isEmpty == false && parser!.upgrade) {
      messages[num_messages - 1].upgrade = characters(chars, start: msg1len, length: read)
      throw goto.test
    }

    if (read != msg2len) {
      print_error(msg2, read)
      abort()
    }

    read = parse(string: "")

    if (read != 0) {
      print_error(message.raw, read)
      abort()
    }
    throw goto.test
    } // end of do

    catch {

    if (num_messages != 1) {
      print("\n*** num_messages != 1 after testing '\(message.name)' ***\n\n");
      abort()
    }

    if(!message_eq(0, 0, message)) { abort() }

    parser_free()
    msg1len += 1

    } // end of catch
  }
}
/*
void
test_message_count_body (const struct message *message)
{
  parser_init(message->type);

  size_t read;
  size_t l = strlen(message->raw);
  size_t i, toread;
  size_t chunk = 4024;

  for (i = 0; i < l; i+= chunk) {
    toread = MIN(l-i, chunk);
    read = parse_count_body(message->raw + i, toread);
    if (read != toread) {
      print_error(message->raw, read);
      abort();
    }
  }


  read = parse_count_body(NULL, 0);
  if (read != 0) {
    print_error(message->raw, read);
    abort();
  }

  if (num_messages != 1) {
    printf("\n*** num_messages != 1 after testing '%s' ***\n\n", message->name);
    abort();
  }

  if(!message_eq(0, 0, message)) abort();

  parser_free();
}
*/
func test_simple (_ buf: String, _ err_expected: http_errno)
{
  parser_init(.HTTP_REQUEST)

  var err: http_errno

  parse(string: buf)
  err = HTTP_PARSER_ERRNO(parser)
  parse(string: "")

  parser_free()

  /* In strict mode, allow us to pass with an unexpected HPE_STRICT as
   * long as the caller isn't expecting success.
   */
  if (err_expected != err && err_expected != .HPE_OK && err != .HPE_STRICT) {
    print("\n*** test_simple expected \(http_parser.errno_name(err_expected)), but saw \(http_parser.errno_name(err)) ***\n\n\\\(buf)")
    abort();
  }
}
/*
void
test_invalid_header_content (int req, const char* str)
{
  http_parser parser;
  http_parser_init(&parser, req ? HTTP_REQUEST : HTTP_RESPONSE);
  size_t parsed;
  const char *buf;
  buf = req ?
    "GET / HTTP/1.1\r\n" :
    "HTTP/1.1 200 OK\r\n";
  parsed = http_parser_execute(&parser, &settings_null, buf, strlen(buf));
  assert(parsed == strlen(buf));

  buf = str;
  size_t buflen = strlen(buf);

  parsed = http_parser_execute(&parser, &settings_null, buf, buflen);
  if (parsed != buflen) {
    assert(HTTP_PARSER_ERRNO(&parser) == HPE_INVALID_HEADER_TOKEN);
    return;
  }

  fprintf(stderr,
          "\n*** Error expected but none in invalid header content test ***\n");
  abort();
}

void
test_invalid_header_field_content_error (int req)
{
  test_invalid_header_content(req, "Foo: F\01ailure");
  test_invalid_header_content(req, "Foo: B\02ar");
}

void
test_invalid_header_field (int req, const char* str)
{
  http_parser parser;
  http_parser_init(&parser, req ? HTTP_REQUEST : HTTP_RESPONSE);
  size_t parsed;
  const char *buf;
  buf = req ?
    "GET / HTTP/1.1\r\n" :
    "HTTP/1.1 200 OK\r\n";
  parsed = http_parser_execute(&parser, &settings_null, buf, strlen(buf));
  assert(parsed == strlen(buf));

  buf = str;
  size_t buflen = strlen(buf);

  parsed = http_parser_execute(&parser, &settings_null, buf, buflen);
  if (parsed != buflen) {
    assert(HTTP_PARSER_ERRNO(&parser) == HPE_INVALID_HEADER_TOKEN);
    return;
  }

  fprintf(stderr,
          "\n*** Error expected but none in invalid header token test ***\n");
  abort();
}

void
test_invalid_header_field_token_error (int req)
{
  test_invalid_header_field(req, "Fo@: Failure");
  test_invalid_header_field(req, "Foo\01\test: Bar");
}

void
test_double_content_length_error (int req)
{
  http_parser parser;
  http_parser_init(&parser, req ? HTTP_REQUEST : HTTP_RESPONSE);
  size_t parsed;
  const char *buf;
  buf = req ?
    "GET / HTTP/1.1\r\n" :
    "HTTP/1.1 200 OK\r\n";
  parsed = http_parser_execute(&parser, &settings_null, buf, strlen(buf));
  assert(parsed == strlen(buf));

  buf = "Content-Length: 0\r\nContent-Length: 1\r\n\r\n";
  size_t buflen = strlen(buf);

  parsed = http_parser_execute(&parser, &settings_null, buf, buflen);
  if (parsed != buflen) {
    assert(HTTP_PARSER_ERRNO(&parser) == HPE_UNEXPECTED_CONTENT_LENGTH);
    return;
  }

  fprintf(stderr,
          "\n*** Error expected but none in double content-length test ***\n");
  abort();
}

void
test_chunked_content_length_error (int req)
{
  http_parser parser;
  http_parser_init(&parser, req ? HTTP_REQUEST : HTTP_RESPONSE);
  size_t parsed;
  const char *buf;
  buf = req ?
    "GET / HTTP/1.1\r\n" :
    "HTTP/1.1 200 OK\r\n";
  parsed = http_parser_execute(&parser, &settings_null, buf, strlen(buf));
  assert(parsed == strlen(buf));

  buf = "Transfer-Encoding: chunked\r\nContent-Length: 1\r\n\r\n";
  size_t buflen = strlen(buf);

  parsed = http_parser_execute(&parser, &settings_null, buf, buflen);
  if (parsed != buflen) {
    assert(HTTP_PARSER_ERRNO(&parser) == HPE_UNEXPECTED_CONTENT_LENGTH);
    return;
  }

  fprintf(stderr,
          "\n*** Error expected but none in chunked content-length test ***\n");
  abort();
}

void
test_header_cr_no_lf_error (int req)
{
  http_parser parser;
  http_parser_init(&parser, req ? HTTP_REQUEST : HTTP_RESPONSE);
  size_t parsed;
  const char *buf;
  buf = req ?
    "GET / HTTP/1.1\r\n" :
    "HTTP/1.1 200 OK\r\n";
  parsed = http_parser_execute(&parser, &settings_null, buf, strlen(buf));
  assert(parsed == strlen(buf));

  buf = "Foo: 1\rBar: 1\r\n\r\n";
  size_t buflen = strlen(buf);

  parsed = http_parser_execute(&parser, &settings_null, buf, buflen);
  if (parsed != buflen) {
    assert(HTTP_PARSER_ERRNO(&parser) == HPE_LF_EXPECTED);
    return;
  }

  fprintf(stderr,
          "\n*** Error expected but none in header whitespace test ***\n");
  abort();
}
*/
func test_header_overflow_error (_ req: http_parser_type)
{
  var parser = http_parser(t: req)
  var parsed = 0
  var buf = req == .HTTP_REQUEST ? "GET / HTTP/1.1\r\n" : "HTTP/1.0 200 OK\r\n";
  parser.delegate = settings_null()
  parsed = parser.execute( buf, Int(strlen(buf)))
  assert(parsed == Int(strlen(buf)))

  buf = "header-key: header-value\r\n"
  let buflen = Int(strlen(buf))

  for _ in 0..<10000 {
    parser.delegate = settings_null()
    parsed = parser.execute(buf, buflen)
    if (parsed != buflen) {
      //fprintf(stderr, "error found on iter %d\n", i);
      assert(parser.http_errno == .HPE_HEADER_OVERFLOW)
      return
    }
  }

  print("\n*** Error expected but none in header overflow test ***\n")
  abort()
}


func test_header_nread_value ()
{
  var parser = http_parser(t: .HTTP_REQUEST)
  var parsed = 0
  let buf = "GET / HTTP/1.1\r\nheader: value\nhdr: value\r\n"
  parser.delegate = settings_null()
  parsed = parser.execute( buf, Int(strlen(buf)))
  XCTAssertEqual(parsed, Int(strlen(buf)))
  // private type
  //assert(parser.nread == strlen(buf))
}


func test_content_length_overflow (_ buf: String, _ buflen: Int, _ expect_ok: Int)
{
  var parser = http_parser(t: .HTTP_RESPONSE)
    parser.delegate = settings_null()
  let _ = parser.execute(buf, buflen);

  if (expect_ok != 0) {
    assert(parser.http_errno == .HPE_OK)
  }
  else {
    assert(parser.http_errno == .HPE_INVALID_CONTENT_LENGTH)
  }
}

func test_header_content_length_overflow_error ()
{
  func X(_ size: UInt) -> String {
    return "HTTP/1.1 200 OK\r\n" +
    "Content-Length: \(size)\r\n" +
    "\r\n"
  }
  let a = X(1844674407370955160)  /* 2^64 / 10 - 1 */
  let b = X(18446744073709551615) /* 2^64-1 */
  //let c = X(18446744073709551616) /* 2^64   */

  test_content_length_overflow(a, Int(strlen(a)), 1) /* expect ok      */
  test_content_length_overflow(b, Int(strlen(b)), 0) /* expect failure */
  //test_content_length_overflow(c, Int(strlen(c)), 0) /* expect failure */
}

func test_chunk_content_length_overflow_error ()
{
  func X(_ size: UInt) -> String {
    return "HTTP/1.1 200 OK\r\n" +
    "Transfer-Encoding: chunked\r\n" +
    "\r\n" +
    "\(size)\r\n" +
    "..."
  }
  let a = X(0xFFFFFFFFFFFFFFE)   /* 2^64 / 16 - 1 */
  let b = X(0xFFFFFFFFFFFFFFFF)  /* 2^64-1 */
  let c = X(10000000000000000) /* 2^64   */

  test_content_length_overflow(a, Int(strlen(a)), 1) /* expect ok      */
  test_content_length_overflow(b, Int(strlen(b)), 0) /* expect failure */
  test_content_length_overflow(c, Int(strlen(c)), 0) /* expect failure */
}

func test_no_overflow_long_body (_ req: http_parser_type, _ length: Int)
{
  var parser = http_parser(t: req)
  var parsed = 0
  let preamble = req == .HTTP_REQUEST ? "POST / HTTP/1.0" : "HTTP/1.0 200 OK"
  let buf1 = "\(preamble)\r\nConnection: Keep-Alive\r\nContent-Length: \(length)\r\n\r\n"
  let buf1len = Int(strlen(buf1))
parser.delegate = settings_null()
  parsed = parser.execute(buf1, buf1len)
  if (parsed != buf1len) {
    XCTFail()
  }

  for _ in 0..<length {
    let foo = "a"
parser.delegate = settings_null()
    parsed = parser.execute(foo, 1)
    if (parsed != 1) {
      XCTFail()
    }
  }

parser.delegate = settings_null()
  parsed = parser.execute(buf1, buf1len)
  if (parsed != buf1len) {
    XCTFail()
  }
  return
}
/*
void
test_multiple3 (const struct message *r1, const struct message *r2, const struct message *r3)
{
  int message_count = count_parsed_messages(3, r1, r2, r3);

  char total[ strlen(r1->raw)
            + strlen(r2->raw)
            + strlen(r3->raw)
            + 1
            ];
  total[0] = '\0';

  strcat(total, r1->raw);
  strcat(total, r2->raw);
  strcat(total, r3->raw);

  parser_init(r1->type);

  size_t read;

  read = parse(total, strlen(total));

  if (parser->upgrade) {
    upgrade_message_fix(total, read, 3, r1, r2, r3);
    goto test;
  }

  if (read != strlen(total)) {
    print_error(total, read);
    abort();
  }

  read = parse(NULL, 0);

  if (read != 0) {
    print_error(total, read);
    abort();
  }

test:

  if (message_count != num_messages) {
    fprintf(stderr, "\n\n*** Parser didn't see 3 messages only %d *** \n", num_messages);
    abort();
  }

  if (!message_eq(0, 0, r1)) abort();
  if (message_count > 1 && !message_eq(1, 0, r2)) abort();
  if (message_count > 2 && !message_eq(2, 0, r3)) abort();

  parser_free();
}

/* SCAN through every possible breaking to make sure the
 * parser can handle getting the content in any chunks that
 * might come from the socket
 */
void
test_scan (const struct message *r1, const struct message *r2, const struct message *r3)
{
  char total[80*1024] = "\0";
  char buf1[80*1024] = "\0";
  char buf2[80*1024] = "\0";
  char buf3[80*1024] = "\0";

  strcat(total, r1->raw);
  strcat(total, r2->raw);
  strcat(total, r3->raw);

  size_t read;

  int total_len = strlen(total);

  int total_ops = 2 * (total_len - 1) * (total_len - 2) / 2;
  int ops = 0 ;

  size_t buf1_len, buf2_len, buf3_len;
  int message_count = count_parsed_messages(3, r1, r2, r3);

  int i,j,type_both;
  for (type_both = 0; type_both < 2; type_both ++ ) {
    for (j = 2; j < total_len; j ++ ) {
      for (i = 1; i < j; i ++ ) {

        if (ops % 1000 == 0)  {
          printf("\b\b\b\b%3.0f%%", 100 * (float)ops /(float)total_ops);
          fflush(stdout);
        }
        ops += 1;

        parser_init(type_both ? HTTP_BOTH : r1->type);

        buf1_len = i;
        strlncpy(buf1, sizeof(buf1), total, buf1_len);
        buf1[buf1_len] = 0;

        buf2_len = j - i;
        strlncpy(buf2, sizeof(buf1), total+i, buf2_len);
        buf2[buf2_len] = 0;

        buf3_len = total_len - j;
        strlncpy(buf3, sizeof(buf1), total+j, buf3_len);
        buf3[buf3_len] = 0;

        read = parse(buf1, buf1_len);

        if (parser->upgrade) goto test;

        if (read != buf1_len) {
          print_error(buf1, read);
          goto error;
        }

        read += parse(buf2, buf2_len);

        if (parser->upgrade) goto test;

        if (read != buf1_len + buf2_len) {
          print_error(buf2, read);
          goto error;
        }

        read += parse(buf3, buf3_len);

        if (parser->upgrade) goto test;

        if (read != buf1_len + buf2_len + buf3_len) {
          print_error(buf3, read);
          goto error;
        }

        parse(NULL, 0);

test:
        if (parser->upgrade) {
          upgrade_message_fix(total, read, 3, r1, r2, r3);
        }

        if (message_count != num_messages) {
          fprintf(stderr, "\n\nParser didn't see %d messages only %d\n",
            message_count, num_messages);
          goto error;
        }

        if (!message_eq(0, 0, r1)) {
          fprintf(stderr, "\n\nError matching messages[0] in test_scan.\n");
          goto error;
        }

        if (message_count > 1 && !message_eq(1, 0, r2)) {
          fprintf(stderr, "\n\nError matching messages[1] in test_scan.\n");
          goto error;
        }

        if (message_count > 2 && !message_eq(2, 0, r3)) {
          fprintf(stderr, "\n\nError matching messages[2] in test_scan.\n");
          goto error;
        }

        parser_free();
      }
    }
  }
  puts("\b\b\b\b100%");
  return;

 error:
  fprintf(stderr, "i=%d  j=%d\n", i, j);
  fprintf(stderr, "buf1 (%u) %s\n\n", (unsigned int)buf1_len, buf1);
  fprintf(stderr, "buf2 (%u) %s\n\n", (unsigned int)buf2_len , buf2);
  fprintf(stderr, "buf3 (%u) %s\n", (unsigned int)buf3_len, buf3);
  abort();
}

// user required to free the result
// string terminated by \0
char *
create_large_chunked_message (int body_size_in_kb, const char* headers)
{
  int i;
  size_t wrote = 0;
  size_t headers_len = strlen(headers);
  size_t bufsize = headers_len + (5+1024+2)*body_size_in_kb + 6;
  char * buf = malloc(bufsize);

  memcpy(buf, headers, headers_len);
  wrote += headers_len;

  for (i = 0; i < body_size_in_kb; i++) {
    // write 1kb chunk into the body.
    memcpy(buf + wrote, "400\r\n", 5);
    wrote += 5;
    memset(buf + wrote, 'C', 1024);
    wrote += 1024;
    strcpy(buf + wrote, "\r\n");
    wrote += 2;
  }

  memcpy(buf + wrote, "0\r\n\r\n", 6);
  wrote += 6;
  assert(wrote == bufsize);

  return buf;
}
*/
/* Verify that we can pause parsing at any of the bytes in the
 * message and still get the result that we're expecting. */
func test_message_pause (_ msg: message)
{
  var buf = msg.raw
  var buflen = Int(strlen(msg.raw))
  var nread = 0
  var buf_count = 0

  let chars = Array(msg.raw.utf8)

  parser_init(msg.type)

  do {
  while(buflen > 0) {
    nread = parse_pause(buf, buflen)

    // We can only set the upgrade buffer once we've gotten our message
    // completion callback.
    if (message_results[0].message_complete_cb_called &&
        !msg.upgrade.isEmpty &&
        parser!.upgrade) {
      messages[0].upgrade = characters(chars, start: buf_count + nread, length: buf_count - nread)
      throw goto.test
    }

    if (nread < buflen) {

      // Not much do to if we failed a strict-mode check
      if (HTTP_PARSER_ERRNO(parser) == .HPE_STRICT) {
        parser_free();
        return;
      }

      XCTAssertEqual (HTTP_PARSER_ERRNO(parser), .HPE_PAUSED)
    }
    buf_count += nread
    buflen -= nread
    buf = characters(chars, start: buf_count, length: buflen)
    parser!.pause(false)
  }

  nread = parse_pause("", 0)
  assert (nread == 0)
  
  throw goto.test
  } // end of do

  catch {
  if (num_messages != 1) {
    print("\n*** num_messages != 1 after testing '\(msg.name)' ***\n\n")
    abort()
  }

  if(!message_eq(0, 0, msg)) { abort() }

  parser_free()
  }
}
/*
/* Verify that body and next message won't be parsed in responses to CONNECT */
void
test_message_connect (const struct message *msg)
{
  char *buf = (char*) msg->raw;
  size_t buflen = strlen(msg->raw);

  parser_init(msg->type);

  parse_connect(buf, buflen);

  if (num_messages != 1) {
    printf("\n*** num_messages != 1 after testing '%s' ***\n\n", msg->name);
    abort();
  }

  if(!message_eq(0, 1, msg)) abort();

  parser_free();
}
*/

class ParserTests: XCTestCase {

  static var allTests : [(String, (ParserTests) -> () throws -> Void)] {
    return [
      ("testMain", testMain)
    ]
  }


func testMain ()
{
  //var parser = http_parser()
  /*int i, j, k;*/

  let version = http_parser.version()
  let major = (version >> 16) & 255;
  let minor = (version >> 8) & 255;
  let patch = version & 255;
  print("http_parser v\(major).\(minor).\(patch) (\(version))")

  //// API
  test_method_str()

  //// NREAD
  test_header_nread_value()

  //// OVERFLOW CONDITIONS

  test_header_overflow_error(.HTTP_REQUEST)
  test_no_overflow_long_body(.HTTP_REQUEST, 1000)
  test_no_overflow_long_body(.HTTP_REQUEST, 100000)

  test_header_overflow_error(.HTTP_RESPONSE)
  test_no_overflow_long_body(.HTTP_RESPONSE, 1000)
  test_no_overflow_long_body(.HTTP_RESPONSE, 100000)

  test_header_content_length_overflow_error()
  //test_chunk_content_length_overflow_error()      // FAILS

  //// HEADER FIELD CONDITIONS
  /*test_double_content_length_error(HTTP_REQUEST);
  test_chunked_content_length_error(HTTP_REQUEST);
  test_header_cr_no_lf_error(HTTP_REQUEST);
  test_invalid_header_field_token_error(HTTP_REQUEST);
  test_invalid_header_field_content_error(HTTP_REQUEST);
  test_double_content_length_error(HTTP_RESPONSE);
  test_chunked_content_length_error(HTTP_RESPONSE);
  test_header_cr_no_lf_error(HTTP_RESPONSE);
  test_invalid_header_field_token_error(HTTP_RESPONSE);
  test_invalid_header_field_content_error(HTTP_RESPONSE);

  //// RESPONSES

  for (i = 0; i < response_count; i++) {
    test_message(&responses[i]);
  }

  for (i = 0; i < response_count; i++) {
    test_message_pause(&responses[i]);
  }

  for (i = 0; i < response_count; i++) {
    test_message_connect(&responses[i]);
  }

  for (i = 0; i < response_count; i++) {
    if (!responses[i].should_keep_alive) continue;
    for (j = 0; j < response_count; j++) {
      if (!responses[j].should_keep_alive) continue;
      for (k = 0; k < response_count; k++) {
        test_multiple3(&responses[i], &responses[j], &responses[k]);
      }
    }
  }

  test_message_count_body(&responses[NO_HEADERS_NO_BODY_404]);
  test_message_count_body(&responses[TRAILING_SPACE_ON_CHUNKED_BODY]);

  // test very large chunked response
  {
    char * msg = create_large_chunked_message(31337,
      "HTTP/1.0 200 OK\r\n"
      "Transfer-Encoding: chunked\r\n"
      "Content-Type: text/plain\r\n"
      "\r\n");
    struct message large_chunked =
      {.name= "large chunked"
      ,.type= HTTP_RESPONSE
      ,.raw= msg
      ,.should_keep_alive= FALSE
      ,.message_complete_on_eof= FALSE
      ,.http_major= 1
      ,.http_minor= 0
      ,.status_code= 200
      ,.response_status= "OK"
      ,.num_headers= 2
      ,.headers=
        { { "Transfer-Encoding", "chunked" }
        , { "Content-Type", "text/plain" }
        }
      ,.body_size= 31337*1024
      ,.num_chunks_complete= 31338
      };
    for (i = 0; i < MAX_CHUNKS; i++) {
      large_chunked.chunk_lengths[i] = 1024;
    }
    test_message_count_body(&large_chunked);
    free(msg);
  }



  printf("response scan 1/2      ");
  test_scan( &responses[TRAILING_SPACE_ON_CHUNKED_BODY]
           , &responses[NO_BODY_HTTP10_KA_204]
           , &responses[NO_REASON_PHRASE]
           );

  printf("response scan 2/2      ");
  test_scan( &responses[BONJOUR_MADAME_FR]
           , &responses[UNDERSTORE_HEADER_KEY]
           , &responses[NO_CARRIAGE_RET]
           );

  puts("responses okay");
*/

  /// REQUESTS

  test_simple("GET / HTP/1.1\r\n\r\n", .HPE_INVALID_VERSION)

  // Extended characters - see nodejs/test/parallel/test-http-headers-obstext.js
  test_simple("GET / HTTP/1.1\r\n" +
              "Test: Düsseldorf\r\n",
              .HPE_OK)

  // Well-formed but incomplete
  test_simple("GET / HTTP/1.1\r\n" +
              "Content-Type: text/plain\r\n" +
              "Content-Length: 6\r\n" +
              "\r\n" +
              "fooba",
              .HPE_OK)

  let all_methods: [String] = [
    "DELETE",
    "GET",
    "HEAD",
    "POST",
    "PUT",
    //"CONNECT", //CONNECT can't be tested like other methods, it's a tunnel
    "OPTIONS",
    "TRACE",
    "COPY",
    "LOCK",
    "MKCOL",
    "MOVE",
    "PROPFIND",
    "PROPPATCH",
    "SEARCH",
    "UNLOCK",
    "BIND",
    "REBIND",
    "UNBIND",
    "ACL",
    "REPORT",
    "MKACTIVITY",
    "CHECKOUT",
    "MERGE",
    "M-SEARCH",
    "NOTIFY",
    "SUBSCRIBE",
    "UNSUBSCRIBE",
    "PATCH",
    "PURGE",
    "MKCALENDAR",
    "LINK",
    "UNLINK",
  ]

  for method in all_methods {
    let buf = "\(method) / HTTP/1.1\r\n\r\n"
    test_simple(buf, .HPE_OK)
  }

  let bad_methods: [String] = [
      "ASDF",
      "C******",
      "COLA",
      "GEM",
      "GETA",
      "M****",
      "MKCOLA",
      "PROPPATCHA",
      "PUN",
      "PX",
      "SA",
      "hello world",
  ]
  for this_method in bad_methods{
    let buf = "\(this_method) / HTTP/1.1\r\n\r\n"
    test_simple(buf, .HPE_INVALID_METHOD)
  }

  // illegal header field name line folding
  test_simple("GET / HTTP/1.1\r\n" +
              "name\r\n" +
              " : value\r\n" +
              "\r\n",
              .HPE_INVALID_HEADER_TOKEN)

  let dumbfuck2 =
    "GET / HTTP/1.1\r\n" +
    "X-SSL-Bullshit:   -----BEGIN CERTIFICATE-----\r\n" +
    "\tMIIFbTCCBFWgAwIBAgICH4cwDQYJKoZIhvcNAQEFBQAwcDELMAkGA1UEBhMCVUsx\r\n" +
    "\tETAPBgNVBAoTCGVTY2llbmNlMRIwEAYDVQQLEwlBdXRob3JpdHkxCzAJBgNVBAMT\r\n" +
    "\tAkNBMS0wKwYJKoZIhvcNAQkBFh5jYS1vcGVyYXRvckBncmlkLXN1cHBvcnQuYWMu\r\n" +
    "\tdWswHhcNMDYwNzI3MTQxMzI4WhcNMDcwNzI3MTQxMzI4WjBbMQswCQYDVQQGEwJV\r\n" +
    "\tSzERMA8GA1UEChMIZVNjaWVuY2UxEzARBgNVBAsTCk1hbmNoZXN0ZXIxCzAJBgNV\r\n" +
    "\tBAcTmrsogriqMWLAk1DMRcwFQYDVQQDEw5taWNoYWVsIHBhcmQYJKoZIhvcNAQEB\r\n" +
    "\tBQADggEPADCCAQoCggEBANPEQBgl1IaKdSS1TbhF3hEXSl72G9J+WC/1R64fAcEF\r\n" +
    "\tW51rEyFYiIeZGx/BVzwXbeBoNUK41OK65sxGuflMo5gLflbwJtHBRIEKAfVVp3YR\r\n" +
    "\tgW7cMA/s/XKgL1GEC7rQw8lIZT8RApukCGqOVHSi/F1SiFlPDxuDfmdiNzL31+sL\r\n" +
    "\t0iwHDdNkGjy5pyBSB8Y79dsSJtCW/iaLB0/n8Sj7HgvvZJ7x0fr+RQjYOUUfrePP\r\n" +
    "\tu2MSpFyf+9BbC/aXgaZuiCvSR+8Snv3xApQY+fULK/xY8h8Ua51iXoQ5jrgu2SqR\r\n" +
    "\twgA7BUi3G8LFzMBl8FRCDYGUDy7M6QaHXx1ZWIPWNKsCAwEAAaOCAiQwggIgMAwG\r\n" +
    "\tA1UdEwEB/wQCMAAwEQYJYIZIAYb4QgHTTPAQDAgWgMA4GA1UdDwEB/wQEAwID6DAs\r\n" +
    "\tBglghkgBhvhCAQ0EHxYdVUsgZS1TY2llbmNlIFVzZXIgQ2VydGlmaWNhdGUwHQYD\r\n" +
    "\tVR0OBBYEFDTt/sf9PeMaZDHkUIldrDYMNTBZMIGaBgNVHSMEgZIwgY+AFAI4qxGj\r\n" +
    "\tloCLDdMVKwiljjDastqooXSkcjBwMQswCQYDVQQGEwJVSzERMA8GA1UEChMIZVNj\r\n" +
    "\taWVuY2UxEjAQBgNVBAsTCUF1dGhvcml0eTELMAkGA1UEAxMCQ0ExLTArBgkqhkiG\r\n" +
    "\t9w0BCQEWHmNhLW9wZXJhdG9yQGdyaWQtc3VwcG9ydC5hYy51a4IBADApBgNVHRIE\r\n" +
    "\tIjAggR5jYS1vcGVyYXRvckBncmlkLXN1cHBvcnQuYWMudWswGQYDVR0gBBIwEDAO\r\n" +
    "\tBgwrBgEEAdkvAQEBAQYwPQYJYIZIAYb4QgEEBDAWLmh0dHA6Ly9jYS5ncmlkLXN1\r\n" +
    "\tcHBvcnQuYWMudmT4sopwqlBWsvcHViL2NybC9jYWNybC5jcmwwPQYJYIZIAYb4QgEDBDAWLmh0\r\n" +
    "\tdHA6Ly9jYS5ncmlkLXN1cHBvcnQuYWMudWsvcHViL2NybC9jYWNybC5jcmwwPwYD\r\n" +
    "\tVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NhLmdyaWQt5hYy51ay9wdWIv\r\n" +
    "\tY3JsL2NhY3JsLmNybDANBgkqhkiG9w0BAQUFAAOCAQEAS/U4iiooBENGW/Hwmmd3\r\n" +
    "\tXCy6Zrt08YjKCzGNjorT98g8uGsqYjSxv/hmi0qlnlHs+k/3Iobc3LjS5AMYr5L8\r\n" +
    "\tUO7OSkgFFlLHQyC9JzPfmLCAugvzEbyv4Olnsr8hbxF1MbKZoQxUZtMVu29wjfXk\r\n" +
    "\thTeApBv7eaKCWpSp7MCbvgzm74izKhu3vlDk9w6qVrxePfGgpKPqfHiOoGhFnbTK\r\n" +
    "\twTC6o2xq5y0qZ03JonF7OJspEd3I5zKY3E+ov7/ZhW6DqT8UFvsAdjvQbXyhV8Eu\r\n" +
    "\tYhixw1aKEPzNjNowuIseVogKOLXxWI5vAi5HgXdS0/ES5gDGsABo4fqovUKlgop3\r\n" +
    "\tRA==\r\n" +
    "\t-----END CERTIFICATE-----\r\n" +
    "\r\n"
  test_simple(dumbfuck2, .HPE_OK)

  let corrupted_connection =
    "GET / HTTP/1.1\r\n" +
    "Host: www.example.com\r\n" +
    "Connection\r\(033)\(065)\(325)eep-Alive\r\n" +
    "Accept-Encoding: gzip\r\n" +
    "\r\n"
  test_simple(corrupted_connection, .HPE_INVALID_HEADER_TOKEN)

  let corrupted_header_name =
    "GET / HTTP/1.1\r\n" +
    "Host: www.example.com\r\n" +
    "X-Some-Header\r\(033)\(065)\(325)eep-Alive\r\n" +
    "Accept-Encoding: gzip\r\n" +
    "\r\n"
  test_simple(corrupted_header_name, .HPE_INVALID_HEADER_TOKEN)

  /* TODO sending junk and large headers gets rejected */

  /* check to make sure our predefined requests are okay */
  for request in requests {
    test_message(request)
  }

  for request in requests {
    test_message_pause(request)
  }
/*
  for i in requests {
    if (!i.should_keep_alive) { continue }
    for j in requests {
      if (!j.should_keep_alive) { continue }
      for k in requests {
        test_multiple3(i, j, k);
      }
    }
  }

  print("request scan 1/4      ");
  test_scan( &requests[GET_NO_HEADERS_NO_BODY]
           , &requests[GET_ONE_HEADER_NO_BODY]
           , &requests[GET_NO_HEADERS_NO_BODY]
           );

  print("request scan 2/4      ");
  test_scan( &requests[POST_CHUNKED_ALL_YOUR_BASE]
           , &requests[POST_IDENTITY_BODY_WORLD]
           , &requests[GET_FUNKY_CONTENT_LENGTH]
           );

  print("request scan 3/4      ");
  test_scan( &requests[TWO_CHUNKS_MULT_ZERO_END]
           , &requests[CHUNKED_W_TRAILING_HEADERS]
           , &requests[CHUNKED_W_BULLSHIT_AFTER_LENGTH]
           );

  print("request scan 4/4      ");
  test_scan( &requests[QUERY_URL_WITH_QUESTION_MARK_GET]
           , &requests[PREFIX_NEWLINE_GET ]
           , &requests[CONNECT_REQUEST]
           );
*/
  print("requests okay")
}

}
