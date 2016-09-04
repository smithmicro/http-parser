/* Based on src/http/ngx_http_parse.c from NGINX copyright Igor Sysoev
 *
 * Additional changes are licensed under the same terms as NGINX and
 * copyright Joyent, Inc. and other Node contributors. All rights reserved.
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

/* Match these versions with the 'C' implementation - https://github.com/nodejs/http-parser */
private let HTTP_PARSER_VERSION_MAJOR = 2
private let HTTP_PARSER_VERSION_MINOR = 7
private let HTTP_PARSER_VERSION_PATCH = 1


/* Maximum header size allowed. This was a macro in the 'C' version
 * however making this a var reduces performance by 15%.
 * Keep this a read only macro for now.
 */
private let HTTP_MAX_HEADER_SIZE = 80*1024

/* Callbacks should return non-zero to indicate an error. The parser will
 * then halt execution.
 *
 * The one exception is on_headers_complete. In a HTTP_RESPONSE parser
 * returning '1' from on_headers_complete will tell the parser that it
 * should not expect a body. This is used when receiving a response to a
 * HEAD request which may contain 'Content-Length' or 'Transfer-Encoding:
 * chunked' headers that indicate the presence of a body.
 *
 * Returning `2` from on_headers_complete will tell parser that it should not
 * expect neither a body nor any further responses on this connection. This is
 * useful for handling responses to a CONNECT request which may not contain
 * `Upgrade` or `Connection: upgrade` headers.
 *
 * http_data_cb does not return data chunks. It will be called arbitrarily
 * many times for each string. E.G. you might get 10 callbacks for "on_url"
 * each providing just a few characters more data.
 */
public protocol http_parser_delegate {
  func on_message_begin() -> Int
  func on_url(at: UnsafePointer<UInt8>, length: Int) -> Int
  func on_status(at: UnsafePointer<UInt8>, length: Int) -> Int
  func on_header_field(at: UnsafePointer<UInt8>, length: Int) -> Int
  func on_header_value(at: UnsafePointer<UInt8>, length: Int) -> Int
  func on_headers_complete() -> Int
  func on_body(at: UnsafePointer<UInt8>, length: Int) -> Int
  func on_message_complete() -> Int
  /* When on_chunk_header is called, the current chunk length is stored
   * in parser.content_length
   */
  func on_chunk_header() -> Int
  func on_chunk_complete() -> Int
}

/* Request Methods */
public enum http_method: Int {
  case HTTP_DELETE = 0
  case HTTP_GET
  case HTTP_HEAD
  case HTTP_POST
  case HTTP_PUT
  /* pathological */
  case HTTP_CONNECT
  case HTTP_OPTIONS
  case HTTP_TRACE
  /* WebDAV */
  case HTTP_COPY
  case HTTP_LOCK
  case HTTP_MKCOL
  case HTTP_MOVE
  case HTTP_PROPFIND
  case HTTP_PROPPATCH
  case HTTP_SEARCH
  case HTTP_UNLOCK
  case HTTP_BIND
  case HTTP_REBIND
  case HTTP_UNBIND
  case HTTP_ACL
  /* subversion */
  case HTTP_REPORT
  case HTTP_MKACTIVITY
  case HTTP_CHECKOUT
  case HTTP_MERGE
  /* upnp */
  case HTTP_MSEARCH
  case HTTP_NOTIFY
  case HTTP_SUBSCRIBE
  case HTTP_UNSUBSCRIBE
  /* RFC-5789 */
  case HTTP_PATCH
  case HTTP_PURGE
  /* CalDAV */
  case HTTP_MKCALENDAR
  /* RFC-2068, section 19.6.1.2 */
  case HTTP_LINK
  case HTTP_UNLINK

  static var count: Int { return http_method.HTTP_UNLINK.rawValue + 1}

  var string: String {
    switch self {
    case .HTTP_DELETE: return "DELETE"
    case .HTTP_GET: return "GET"
    case .HTTP_HEAD: return "HEAD"
    case .HTTP_POST: return "POST"
    case .HTTP_PUT: return "PUT"
    case .HTTP_CONNECT: return "CONNECT"
    case .HTTP_OPTIONS: return "OPTIONS"
    case .HTTP_TRACE: return "TRACE"
    case .HTTP_COPY: return "COPY"
    case .HTTP_LOCK: return "LOCK"
    case .HTTP_MKCOL: return "MKCOL"
    case .HTTP_MOVE: return "MOVE"
    case .HTTP_PROPFIND: return "PROPFIND"
    case .HTTP_PROPPATCH: return "PROPPATCH"
    case .HTTP_SEARCH: return "SEARCH"
    case .HTTP_UNLOCK: return "UNLOCK"
    case .HTTP_BIND: return "BIND"
    case .HTTP_REBIND: return "REBIND"
    case .HTTP_UNBIND: return "UNBIND"
    case .HTTP_ACL: return "ACL"
    case .HTTP_REPORT: return "REPORT"
    case .HTTP_MKACTIVITY: return "MKACTIVITY"
    case .HTTP_CHECKOUT: return "CHECKOUT"
    case .HTTP_MERGE: return "MERGE"
    case .HTTP_MSEARCH: return "MSEARCH"
    case .HTTP_NOTIFY: return "NOTIFY"
    case .HTTP_SUBSCRIBE: return "SUBSCRIBE"
    case .HTTP_UNSUBSCRIBE: return "UNSUBSCRIBE"
    case .HTTP_PATCH: return "PATCH"
    case .HTTP_PURGE: return "PURGE"
    case .HTTP_MKCALENDAR: return "MKCALENDAR"
    case .HTTP_LINK: return "LINK"
    case .HTTP_UNLINK: return "UNLINK"
    }
  }
}

public enum http_parser_type { case HTTP_REQUEST, HTTP_RESPONSE, HTTP_BOTH }

private typealias http_flags = UInt8

/* Flag values for http_parser.flags field */
private let F_CHUNKED: http_flags               = 1 << 0
private let F_CONNECTION_KEEP_ALIVE: http_flags = 1 << 1
private let F_CONNECTION_CLOSE: http_flags      = 1 << 2
private let F_CONNECTION_UPGRADE: http_flags    = 1 << 3
private let F_TRAILING: http_flags              = 1 << 4
private let F_UPGRADE: http_flags               = 1 << 5
private let F_SKIPBODY: http_flags              = 1 << 6
private let F_CONTENTLENGTH: http_flags         = 1 << 7

/* Map for errno-related constants */
public enum http_errno: String, Error {
  case HPE_OK                     // "success"

/* Callback-related errors */
  case HPE_CB_message_begin       // "the on_message_begin callback failed"
  case HPE_CB_url                 // "the on_url callback failed"
  case HPE_CB_header_field        // "the on_header_field callback failed"
  case HPE_CB_header_value        // "the on_header_value callback failed"
  case HPE_CB_headers_complete    // "the on_headers_complete callback failed"
  case HPE_CB_body                // "the on_body callback failed"
  case HPE_CB_message_complete    // "the on_message_complete callback failed"
  case HPE_CB_status              // "the on_status callback failed"
  case HPE_CB_chunk_header        // "the on_chunk_header callback failed"
  case HPE_CB_chunk_complete      // "the on_chunk_complete callback failed"

/* Parsing-related errors */
  case HPE_INVALID_EOF_STATE      // "stream ended at an unexpected time"
  case HPE_HEADER_OVERFLOW        // "too many header bytes seen; overflow detected"
  case HPE_CLOSED_CONNECTION      // "data received after completed connection: close message"
  case HPE_INVALID_VERSION        // "invalid HTTP version"
  case HPE_INVALID_STATUS         // "invalid HTTP status code"
  case HPE_INVALID_METHOD         // "invalid HTTP method"
  case HPE_INVALID_URL            // "invalid URL"
  case HPE_INVALID_HOST           // "invalid host"
  case HPE_INVALID_PORT           // "invalid port"
  case HPE_INVALID_PATH           // "invalid path"
  case HPE_INVALID_QUERY_STRING   // "invalid query string"
  case HPE_INVALID_FRAGMENT       // "invalid fragment"
  case HPE_LF_EXPECTED            // "LF character expected"
  case HPE_INVALID_HEADER_TOKEN   // "invalid character in header"
  case HPE_INVALID_CONTENT_LENGTH // "invalid character in content-length header"
  case HPE_UNEXPECTED_CONTENT_LENGTH  // "unexpected content-length header"
  case HPE_INVALID_CHUNK_SIZE     // "invalid character in chunk size header"
  case HPE_INVALID_CONSTANT       // "invalid constant string"
  case HPE_INVALID_INTERNAL_STATE // "encountered unexpected internal state"
  case HPE_STRICT                 // "strict mode assertion failed"
  case HPE_PAUSED                 // "parser is paused"
  case HPE_UNKNOWN                // "an unknown error occurred"

  var description: String {
    switch self {
    case .HPE_OK:                     return "success"
    case .HPE_CB_message_begin:       return "the on_message_begin callback failed"
    case .HPE_CB_url:                 return "the on_url callback failed"
    case .HPE_CB_header_field:        return "the on_header_field callback failed"
    case .HPE_CB_header_value:        return "the on_header_value callback failed"
    case .HPE_CB_headers_complete:    return "the on_headers_complete callback failed"
    case .HPE_CB_body:                return "the on_body callback failed"
    case .HPE_CB_message_complete:    return "the on_message_complete callback failed"
    case .HPE_CB_status:              return "the on_status callback failed"
    case .HPE_CB_chunk_header:        return "the on_chunk_header callback failed"
    case .HPE_CB_chunk_complete:      return "the on_chunk_complete callback failed"
    case .HPE_INVALID_EOF_STATE:      return "stream ended at an unexpected time"
    case .HPE_HEADER_OVERFLOW:        return "too many header bytes seen; overflow detected"
    case .HPE_CLOSED_CONNECTION:      return "data received after completed connection: close message"
    case .HPE_INVALID_VERSION:        return "invalid HTTP version"
    case .HPE_INVALID_STATUS:         return "invalid HTTP status code"
    case .HPE_INVALID_METHOD:         return "invalid HTTP method"
    case .HPE_INVALID_URL:            return "invalid URL"
    case .HPE_INVALID_HOST:           return "invalid host"
    case .HPE_INVALID_PORT:           return "invalid port"
    case .HPE_INVALID_PATH:           return "invalid path"
    case .HPE_INVALID_QUERY_STRING:   return "invalid query string"
    case .HPE_INVALID_FRAGMENT:       return "invalid fragment"
    case .HPE_LF_EXPECTED:            return "LF character expected"
    case .HPE_INVALID_HEADER_TOKEN:   return "invalid character in header"
    case .HPE_INVALID_CONTENT_LENGTH: return "invalid character in content-length header"
    case .HPE_UNEXPECTED_CONTENT_LENGTH: return "unexpected content-length header"
    case .HPE_INVALID_CHUNK_SIZE:     return "invalid character in chunk size header"
    case .HPE_INVALID_CONSTANT:       return "invalid constant string"
    case .HPE_INVALID_INTERNAL_STATE: return "encountered unexpected internal state"
    case .HPE_STRICT:                 return "strict mode assertion failed"
    case .HPE_PAUSED:                 return "parser is paused"
    case .HPE_UNKNOWN:                return "an unknown error occurred"
    }
  }
}

public class http_parser {

private let ULLONG_MAX:UInt64 = 18446744073709551615

private func SET_ERRNO(_ e: http_errno) throws {
  http_errno = e
  throw http_errno
}

private func LIKELY(_ X: Bool) -> Bool { return X }
private func UNLIKELY(_ X: Bool) -> Bool { return X }

/* Set the mark FOR; non-destructive if mark is already set */
private enum http_mark {
  case status, url, header_field, header_value, body
}

private enum http_notify {
  case message_complete, message_begin, chunk_header, chunk_complete
}

private func CALLBACK_NOTIFY(_ p_state: state, _ FOR: http_notify) -> Bool {
  assert(self.http_errno == .HPE_OK)

  self.state = p_state
  switch FOR {
  case .message_complete:
    if let callback = delegate {
      if (callback.on_message_complete() != 0) {
        self.http_errno = .HPE_CB_message_complete
      }
    }
  case .message_begin:
    if let callback = delegate {
      if (callback.on_message_begin() != 0) {
        self.http_errno = .HPE_CB_message_begin
      }
    }
  case .chunk_header:
    if let callback = delegate {
      if (callback.on_message_begin() != 0) {
        self.http_errno = .HPE_CB_chunk_header
      }
    }
  case .chunk_complete:
    if let callback = delegate {
      if (callback.on_chunk_complete() != 0) {
        self.http_errno = .HPE_CB_chunk_complete
      }
    }
  }
  /* We either errored above or got paused; get out */
  if UNLIKELY(http_errno != .HPE_OK) {
    return true
  }
  return false
}

private func CALLBACK_DATA_(_ p_state: state, _ p : UnsafePointer<UInt8>, _ FOR: http_mark, _ LEN: Int) -> Bool {
  assert(self.http_errno == .HPE_OK)

  switch FOR {
  case .status:
    if let mark = status_mark {
      if let callback = delegate {
        self.state = p_state
        if (callback.on_status(at: mark, length: LEN) != 0) {
          self.http_errno = .HPE_CB_status
        }
      }
      status_mark = nil
    }
  case .url:
    if let mark = url_mark {
      if let callback = delegate {
        self.state = p_state
        if (callback.on_url(at: mark, length: LEN) != 0) {
          self.http_errno = .HPE_CB_url
        }
      }
      url_mark = nil
    }
  case .header_field:
    if let mark = header_field_mark {
      if let callback = delegate {
        self.state = p_state
        if (callback.on_header_field(at: mark, length: LEN) != 0) {
          self.http_errno = .HPE_CB_header_field
        }
      }
      header_field_mark = nil
    }
  case .header_value:
    if let mark = header_value_mark {
      if let callback = delegate {
        self.state = p_state
        if (callback.on_header_value(at: mark, length: LEN) != 0) {
          self.http_errno = .HPE_CB_header_value
        }
      }
      header_value_mark = nil
    }
  case .body:
    if let mark = body_mark {
      if let callback = delegate {
        self.state = p_state
        if (callback.on_body(at: mark, length: LEN) != 0) {
          self.http_errno = .HPE_CB_body
        }
      }
      body_mark = nil
    }
  }
  /* We either errored above or got paused; get out */
  if UNLIKELY(http_errno != .HPE_OK) {
    return true
  }
  return false
}

private func CALLBACK_DATA(_ p_state: state, _ p : UnsafePointer<UInt8>, _ FOR: http_mark) -> Bool {
  switch FOR {
  case .status:
    if let mark = status_mark {
      return CALLBACK_DATA_(p_state, p, FOR, p - mark)
    }
  case .url:
    if let mark = url_mark {
      return CALLBACK_DATA_(p_state, p, FOR, p - mark)
    }
  case .header_field:
    if let mark = header_field_mark {
      return CALLBACK_DATA_(p_state, p, FOR, p - mark)
    }
  case .header_value:
    if let mark = header_value_mark {
      return CALLBACK_DATA_(p_state, p, FOR, p - mark)
    }
  case .body:
    if let mark = body_mark {
      return CALLBACK_DATA_(p_state, p, FOR, p - mark)
    }
  }
  return false
}

private var header_field_mark: UnsafePointer<UInt8>? = nil
private var header_value_mark: UnsafePointer<UInt8>? = nil
private var url_mark: UnsafePointer<UInt8>? = nil
private var body_mark: UnsafePointer<UInt8>? = nil
private var status_mark: UnsafePointer<UInt8>? = nil

private func MARK(_ FOR: http_mark, _ p: UnsafePointer<UInt8>?) {
  switch FOR {
  case .status:
    if status_mark == nil {
      status_mark = p
    }
  case .url:
    if url_mark == nil {
      url_mark = p
    }
  case .header_field:
    if header_field_mark == nil {
      header_field_mark = p
    }
  case .header_value:
    if header_value_mark == nil {
      header_value_mark = p
    }
  case .body:
    if body_mark == nil {
      body_mark = p
    }
  }
}

/* Don't allow the total size of the HTTP headers (including the status
 * line) to exceed HTTP_MAX_HEADER_SIZE.  This check is here to protect
 * embedders against denial-of-service attacks where the attacker feeds
 * us a never-ending header that the embedder keeps buffering.
 *
 * This check is arguably the responsibility of embedders but we're doing
 * it on the embedder's behalf because most won't bother and this way we
 * make the web a little safer.  HTTP_MAX_HEADER_SIZE is still far bigger
 * than any reasonable request or response so this should never affect
 * day-to-day operation.
 */

private func COUNT_HEADER_SIZE(_ V: Int) throws {
  nread += V
  if nread > HTTP_MAX_HEADER_SIZE {
    http_errno = .HPE_HEADER_OVERFLOW
    throw http_errno
  }
}

private class func stringToArray(string: String) -> [UInt8] {
  return Array(string.utf8)
}

private let PROXY_CONNECTION = http_parser.stringToArray(string: "proxy-connection")
private let CONNECTION = http_parser.stringToArray(string: "connection")
private let CONTENT_LENGTH = http_parser.stringToArray(string: "content-length")
private let TRANSFER_ENCODING = http_parser.stringToArray(string: "transfer-encoding")
private let UPGRADE = http_parser.stringToArray(string: "upgrade")
private let CHUNKED = http_parser.stringToArray(string: "chunked")
private let KEEP_ALIVE = http_parser.stringToArray(string: "keep-alive")
private let CLOSE = http_parser.stringToArray(string: "close")

var http_method_string_array: [[UInt8]] = []

private func create_method_strings() {
  // build a cached set of method arrays to be used in method_strings
  for method: Int in 0..<http_method.count {
    http_method_string_array.append(http_parser.stringToArray(string: http_method(rawValue: method)!.string))
  }
}

private func method_strings(_ method: http_method) -> [UInt8] {
  assert(http_method.count == http_method_string_array.count)
  return http_method_string_array[method.rawValue]
}


/* Tokens as defined by rfc 2616. Also lowercases them.
 *        token       = 1*<any CHAR except CTLs or separators>
 *     separators     = "(" | ")" | "<" | ">" | "@"
 *                    | "," | ";" | ":" | "\" | <">
 *                    | "/" | "[" | "]" | "?" | "="
 *                    | "{" | "}" | SP | HT
 */
private let tokens: [UInt8] = [
/*   0 nul    1 soh    2 stx    3 etx    4 eot    5 enq    6 ack    7 bel  */
    0,       0,       0,       0,       0,       0,       0,       0,
/*   8 bs     9 ht    10 nl    11 vt    12 np    13 cr    14 so    15 si   */
    0,       0,       0,       0,       0,       0,       0,       0,
/*  16 dle   17 dc1   18 dc2   19 dc3   20 dc4   21 nak   22 syn   23 etb */
    0,       0,       0,       0,       0,       0,       0,       0,
/*  24 can   25 em    26 sub   27 esc   28 fs    29 gs    30 rs    31 us  */
    0,       0,       0,       0,       0,       0,       0,       0,
/*  32 sp    33  !    34  "    35  #    36  $    37  %    38  &    39  '  */
    0,      33,       0,       35,      36,      37,      38,      39,
/*  40  (    41  )    42  *    43  +    44  ,    45  -    46  .    47  /  */
    0,       0,       42,      43,      0,       45,      46,      0,
/*  48  0    49  1    50  2    51  3    52  4    53  5    54  6    55  7  */
    48,      49,      50,      51,      52,      53,      54,      56,
/*  56  8    57  9    58  :    59  ;    60  <    61  =    62  >    63  ?  */
    56,      57,      0,       0,       0,       0,       0,       0,
/*  64  @    65  A    66  B    67  C    68  D    69  E    70  F    71  G  */
    0,       97,      98,      99,      100,     101,     102,     103,
/*  72  H    73  I    74  J    75  K    76  L    77  M    78  N    79  O  */
    104,     105,     106,     107,     108,     109,     110,     111,
/*  80  P    81  Q    82  R    83  S    84  T    85  U    86  V    87  W  */
    112,     113,     114,     115,     116,     117,     118,     119,
/*  88  X    89  Y    90  Z    91  [    92  \    93  ]    94  ^    95  _  */
    120,     121,     122,     0,       0,       0,       94,      95,
/*  96  `    97  a    98  b    99  c   100  d   101  e   102  f   103  g  */
    96,      97,      98,      99,     100,     101,     102,     103,
/* 104  h   105  i   106  j   107  k   108  l   109  m   110  n   111  o  */
    104,    105,     106,     107,     108,     109,     110,     111,
/* 112  p   113  q   114  r   115  s   116  t   117  u   118  v   119  w  */
    112,    113,     114,     115,     116,     117,     118,     119,
/* 120  x   121  y   122  z   123  {   124  |   125  }   126  ~   127 del */
    120,    121,     122,     0,       124,     0,       126,     0 ]


private let unhex: [Int8] =
  [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  , 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,10,11,12,13,14,15,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
  ]


private enum state: Int
{ case s_dead = 1 /* important that this is > 0 */

  case s_start_req_or_res
  case s_res_or_resp_H
  case s_start_res
  case s_res_H
  case s_res_HT
  case s_res_HTT
  case s_res_HTTP
  case s_res_first_http_major
  case s_res_http_major
  case s_res_first_http_minor
  case s_res_http_minor
  case s_res_first_status_code
  case s_res_status_code
  case s_res_status_start
  case s_res_status
  case s_res_line_almost_done

  case s_start_req

  case s_req_method
  case s_req_spaces_before_url
  case s_req_schema
  case s_req_schema_slash
  case s_req_schema_slash_slash
  case s_req_server_start
  case s_req_server
  case s_req_server_with_at
  case s_req_path
  case s_req_query_string_start
  case s_req_query_string
  case s_req_fragment_start
  case s_req_fragment
  case s_req_http_start
  case s_req_http_H
  case s_req_http_HT
  case s_req_http_HTT
  case s_req_http_HTTP
  case s_req_first_http_major
  case s_req_http_major
  case s_req_first_http_minor
  case s_req_http_minor
  case s_req_line_almost_done

  case s_header_field_start
  case s_header_field
  case s_header_value_discard_ws
  case s_header_value_discard_ws_almost_done
  case s_header_value_discard_lws
  case s_header_value_start
  case s_header_value
  case s_header_value_lws

  case s_header_almost_done

  case s_chunk_size_start
  case s_chunk_size
  case s_chunk_parameters
  case s_chunk_size_almost_done

  case s_headers_almost_done
  case s_headers_done

  /* Important: 's_headers_done' must be the last 'header' state. All
   * states beyond this must be 'body' states. It is used for overflow
   * checking. See the PARSING_HEADER() macro.
   */

  case s_chunk_data
  case s_chunk_data_almost_done
  case s_chunk_data_done

  case s_body_identity
  case s_body_identity_eof

  case s_message_done
}

private func PARSING_HEADER(_ s: state) -> Bool { return s.rawValue <= state.s_headers_done.rawValue }

private  enum header_states: Int
{ case h_general = 0
  case h_C
  case h_CO
  case h_CON

  case h_matching_connection
  case h_matching_proxy_connection
  case h_matching_content_length
  case h_matching_transfer_encoding
  case h_matching_upgrade

  case h_connection
  case h_content_length
  case h_transfer_encoding
  case h_upgrade

  case h_matching_transfer_encoding_chunked
  case h_matching_connection_token_start
  case h_matching_connection_keep_alive
  case h_matching_connection_close
  case h_matching_connection_upgrade
  case h_matching_connection_token

  case h_transfer_encoding_chunked
  case h_connection_keep_alive
  case h_connection_close
  case h_connection_upgrade
}


private var type : http_parser_type  /* enum http_parser_type */
private var flags: http_flags        /* F_* values from 'flags' enum; semi-public */
private var state: state             /* enum state from http_parser.c */
private var header_state: header_states /* enum header_state from http_parser.c */
private var index: Int               /* index into current matcher */
private var lenient_http_headers: Bool
private var nread: Int               /* # bytes read in various scenarios */
private var delegate: http_parser_delegate? = nil

public var content_length: UInt64    /* # bytes in body (0 if no Content-Length header) */
public var http_major: UInt16
public var http_minor: UInt16
public var status_code: UInt         /* responses only */
public var method: http_method       /* requests only */
public var http_errno: http_errno

/* true = Upgrade header was present and the parser has exited because of that.
 * false = No upgrade header present.
 * Should be checked when http_parser_execute() returns in addition to
 * error checking.
 */
public var upgrade: Bool


public init(t: http_parser_type = .HTTP_REQUEST) {
  type = t
  self.state = (t == .HTTP_REQUEST ? .s_start_req : (t == .HTTP_RESPONSE ? .s_start_res : .s_start_req_or_res))
  http_errno = .HPE_OK

  flags = 0
  header_state = .h_general
  index = 0
  lenient_http_headers = false
  nread = 0
  content_length = 0
  http_major = 0
  http_minor = 0
  status_code = 0
  method = .HTTP_DELETE
  upgrade = false
  create_method_strings()
}


/* Macros for character classes; depends on strict-mode  */

private let ASCII_NUL: UInt8 = 0            // NULL	(Null character)
private let ASCII_TAB: UInt8 = 9            // HT	(Horizontal Tab)
private let LF: UInt8 = 10                  // LF	(Line feed)
private let ASCII_FF: UInt8 = 11            // FF	(Form feed)
private let CR: UInt8 = 13                  // CR	(Carriage return)

private let ASCII_SPACE: UInt8 = 32         // 		(space)
private let ASCII_EXCLAMATION: UInt8 = 33   // !	(exclamation mark)
private let ASCII_QUOTE: UInt8 = 34         // "	(Quotation mark)
private let ASCII_POUND: UInt8 = 35         // #	(Number sign)
private let ASCII_DOLLAR: UInt8 = 36        // $	(Dollar sign)
private let ASCII_PERCENT: UInt8 = 37       // %	(Percent sign)
private let ASCII_AMPERSAND: UInt8 = 38     // &	(Ampersand)
private let ASCII_APOSTROPHE: UInt8 = 39    // '	(Apostrophe)
private let ASCII_L_PARENTHESES: UInt8 = 40	// (	(round brackets or parentheses)
private let ASCII_R_PARENTHESES: UInt8 = 41	// )	(round brackets or parentheses)
private let ASCII_ASTERISK: UInt8 = 42      // *	(Asterisk)
private let ASCII_PLUS: UInt8 = 43          // +	(Plus sign)
private let ASCII_COMMA: UInt8 = 44         // ,	(Comma)
private let ASCII_HYPHEN: UInt8 = 45        // -	(Hyphen)
private let ASCII_DOT: UInt8 = 46           // .	(Full stop , dot)
private let ASCII_SLASH: UInt8 = 47         // /	(Slash)
private let ASCII_0: UInt8 = 48             // 0	(number zero)
private let ASCII_1: UInt8 = 49             // 1	(number one)
private let ASCII_2: UInt8 = 50             // 2	(number two)
private let ASCII_3: UInt8 = 51             // 3	(number three)
private let ASCII_4: UInt8 = 52             // 4	(number four)
private let ASCII_5: UInt8 = 53             // 5	(number five)
private let ASCII_6: UInt8 = 54             // 6	(number six)
private let ASCII_7: UInt8 = 55             // 7	(number seven)
private let ASCII_8: UInt8 = 56             // 8	(number eight)
private let ASCII_9: UInt8 = 57             // 9	(number nine)
private let ASCII_COLON: UInt8 = 58         // :	(Colon)
private let ASCII_SEMICOLON: UInt8 = 59     // ;	(Semicolon)
private let ASCII_LESS: UInt8 = 60          // <	(Less-than sign )
private let ASCII_EQUAL: UInt8 = 61         // 	=	(Equals sign)
private let ASCII_GREATER: UInt8 = 62       // >	(Greater-than sign ; Inequality)
private let ASCII_QUESTION: UInt8 = 63      // ?	(Question mark)

private let ASCII_AT: UInt8 = 64          	// @	(At sign)
private let ASCII_A: UInt8 = 65             // A	(Capital A )
private let ASCII_B: UInt8 = 66	            // B	(Capital B )
private let ASCII_C: UInt8 = 67	            // C	(Capital C )
private let ASCII_D: UInt8 = 68	            // D	(Capital D )
private let ASCII_E: UInt8 = 69	            // E	(Capital E )
private let ASCII_F: UInt8 = 70	            // F	(Capital F )
private let ASCII_G: UInt8 = 71	            // G	(Capital G )
private let ASCII_H: UInt8 = 72	            // H	(Capital H )
private let ASCII_I: UInt8 = 73	            // I	(Capital I )
private let ASCII_J: UInt8 = 74	            // J	(Capital J )
private let ASCII_K: UInt8 = 75	            // K	(Capital K )
private let ASCII_L: UInt8 = 76	            // L	(Capital L )
private let ASCII_M: UInt8 = 77	            // M	(Capital M )
private let ASCII_N: UInt8 = 78	            // N	(Capital N )
private let ASCII_O: UInt8 = 79	            // O	(Capital O )
private let ASCII_P: UInt8 = 80	            // P	(Capital P )
private let ASCII_Q: UInt8 = 81	            // Q	(Capital Q )
private let ASCII_R: UInt8 = 82	            // R	(Capital R )
private let ASCII_S: UInt8 = 83	            // S	(Capital S )
private let ASCII_T: UInt8 = 84	            // T	(Capital T )
private let ASCII_U: UInt8 = 85	            // U	(Capital U )
private let ASCII_V: UInt8 = 86	            // V	(Capital V )
private let ASCII_W: UInt8 = 87	            // W	(Capital W )
private let ASCII_X: UInt8 = 88	            // X	(Capital X )
private let ASCII_Y: UInt8 = 89	            // Y	(Capital Y )
private let ASCII_Z: UInt8 = 90	            // Z	(Capital Z )
private let ASCII_L_BRACKET: UInt8 = 91     // [	(square brackets or box brackets)
private let ASCII_BACKSLASH: UInt8 = 92     // \	(Backslash)
private let ASCII_R_BRACKET: UInt8 = 93     // ]	(square brackets or box brackets)
private let ASCII_CARET: UInt8 = 94         // ^	(Caret or circumflex accent)
private let ASCII_UNDERSCORE: UInt8 = 95    // _	(underscore , understrike , underbar or low line)

private let ASCII_ACCENT: UInt8 = 96        // `	(Grave accent)
private let ASCII_a: UInt8 = 97             // a	(Lowercase  a )
private let ASCII_b: UInt8 = 98             // b	(Lowercase  b )
private let ASCII_c: UInt8 = 99             // c	(Lowercase  c )
private let ASCII_d: UInt8 = 100            // d	(Lowercase  d )
private let ASCII_e: UInt8 = 101	          // e	(Lowercase  e )
private let ASCII_f: UInt8 = 102	          // f	(Lowercase  f )
private let ASCII_g: UInt8 = 103	          // g	(Lowercase  g )
private let ASCII_h: UInt8 = 104	          // h	(Lowercase  h )
private let ASCII_i: UInt8 = 105	          // i	(Lowercase  i )
private let ASCII_j: UInt8 = 106	          // j	(Lowercase  j )
private let ASCII_k: UInt8 = 107	          // k	(Lowercase  k )
private let ASCII_l: UInt8 = 108	          // l	(Lowercase  l )
private let ASCII_m: UInt8 = 109	          // m	(Lowercase  m )
private let ASCII_n: UInt8 = 110	          // n	(Lowercase  n )
private let ASCII_o: UInt8 = 111	          // o	(Lowercase  o )
private let ASCII_p: UInt8 = 112	          // p	(Lowercase  p )
private let ASCII_q: UInt8 = 113	          // q	(Lowercase  q )
private let ASCII_r: UInt8 = 114	          // r	(Lowercase  r )
private let ASCII_s: UInt8 = 115	          // s	(Lowercase  s )
private let ASCII_t: UInt8 = 116	          // t	(Lowercase  t )
private let ASCII_u: UInt8 = 117	          // u	(Lowercase  u )
private let ASCII_v: UInt8 = 118	          // v	(Lowercase  v )
private let ASCII_w: UInt8 = 119	          // w	(Lowercase  w )
private let ASCII_x: UInt8 = 120	          // x	(Lowercase  x )
private let ASCII_y: UInt8 = 121	          // y	(Lowercase  y )
private let ASCII_z: UInt8 = 122	          // z	(Lowercase  z )
private let ASCII_L_BRACE: UInt8 = 123	    // {	(curly brackets or braces)
private let ASCII_VBAT: UInt8 = 124         // |	(vertical-bar, vbar, vertical line or vertical slash)
private let ASCII_R_BRACE: UInt8 = 125	    // }	(curly brackets or braces)
private let ASCII_TILDE: UInt8 = 126        // ~	(Tilde ; swung dash)


private func LOWER(_ c: UInt8) -> UInt8 {
  return c | 0x20
}

private func IS_ALPHA(_ c: UInt8) -> Bool {
  return (c >= ASCII_a && c <= ASCII_z) || (c >= ASCII_A && c <= ASCII_Z)
}

private func IS_NUM(_ c: UInt8) -> Bool {
  return c >= ASCII_0 && c <= ASCII_9
}

private func IS_ALPHANUM(_ c: UInt8) -> Bool {
  return (c >= ASCII_a && c <= ASCII_z) || (c >= ASCII_A && c <= ASCII_Z) || c >= ASCII_0 && c <= ASCII_9
}

private func IS_HEX(_ c: UInt8) -> Bool {
  return c >= ASCII_0 && c <= ASCII_9 || (c >= ASCII_a && c <= ASCII_f) || (c >= ASCII_A && c <= ASCII_F)
}

private func IS_MARK(_ c: UInt8) -> Bool {
  return ((c) == ASCII_HYPHEN || (c) == ASCII_UNDERSCORE || (c) == ASCII_DOT ||
        (c) == ASCII_EXCLAMATION || (c) == ASCII_TILDE || (c) == ASCII_ASTERISK || (c) == ASCII_APOSTROPHE || (c) == ASCII_L_PARENTHESES ||
        (c) == ASCII_R_PARENTHESES)
}

private func IS_USERINFO_CHAR(_ c: UInt8) -> Bool {
  return (IS_ALPHANUM(c) || IS_MARK(c) || (c) == ASCII_PERCENT ||
        (c) == ASCII_SEMICOLON || (c) == ASCII_COLON || (c) == ASCII_AMPERSAND || (c) == ASCII_EQUAL || (c) == ASCII_PLUS ||
        (c) == ASCII_DOLLAR || (c) == ASCII_COMMA)
}

private func IS_URL_CHAR(_ c: UInt8) -> Bool {
  return c >= ASCII_EXCLAMATION && c <= ASCII_TILDE && c != ASCII_QUESTION && c != ASCII_POUND
}

private func IS_HOST_CHAR(_ c: UInt8) -> Bool {
  return IS_ALPHANUM(c) || c == ASCII_DOT || c == ASCII_HYPHEN
}

/**
 * Verify that a char is a valid visible (printable) US-ASCII
 * character or %x80-FF
 **/
private func IS_HEADER_CHAR(_ ch: UInt8) -> Bool {
  return (ch == CR || ch == LF || ch == 9 || (ch > 31 && ch != 127))
}

private func STRICT_TOKEN(_ c: UInt8) -> UInt8 {
  return tokens[Int(c)]
}

private func TOKEN(_ c: UInt8) -> UInt8 {
  return tokens[Int(c)]
}

private func STRICT_CHECK(_ cond: Bool) throws {
  if (cond) {
    http_errno = .HPE_STRICT
    throw http_errno
  }
}

private func NEW_MESSAGE() -> state {
  return (should_keep_alive() ? (self.type == .HTTP_REQUEST ? .s_start_req : .s_start_res) : .s_dead)
}


/* Our URL parser.
 *
 * This is designed to be shared by http_parser_execute() for URL validation,
 * hence it has a state transition + byte-for-byte interface. In addition, it
 * is meant to be embedded in http_parser_parse_url(), which does the dirty
 * work of turning state transitions URL components for its API.
 *
 * This function should only be invoked with non-space characters. It is
 * assumed that the caller cares about (and can detect) the transition between
 * URL and non-URL states by looking for these.
 */
private func parse_url_char(_ s: state, _ ch: UInt8) -> state
{
  if (ch == ASCII_SPACE || ch == CR || ch == LF) {
    return .s_dead
  }

  if (ch == ASCII_TAB || ch == ASCII_FF) {
    return .s_dead
  }

  switch (s) {
    case .s_req_spaces_before_url:
      /* Proxied requests are followed by scheme of an absolute URI (alpha).
       * All methods except CONNECT are followed by '/' or '*'.
       */

      if (ch == ASCII_SLASH || ch == ASCII_ASTERISK) {
        return .s_req_path
      }

      if (IS_ALPHA(ch)) {
        return .s_req_schema
      }

      break

    case .s_req_schema:
      if (IS_ALPHA(ch)) {
        return s
      }

      if (ch == ASCII_COLON) {
        return .s_req_schema_slash
      }

      break

    case .s_req_schema_slash:
      if (ch == ASCII_SLASH) {
        return .s_req_schema_slash_slash
      }

      break

    case .s_req_schema_slash_slash:
      if (ch == ASCII_SLASH) {
        return .s_req_server_start
      }

      break

    case .s_req_server_with_at:
      if (ch == ASCII_AT) {
        return .s_dead
      }

      fallthrough
      /* FALLTHROUGH */
    case .s_req_server_start,
         .s_req_server:
      if (ch == ASCII_SLASH) {
        return .s_req_path
      }

      if (ch == ASCII_QUESTION) {
        return .s_req_query_string_start
      }

      if (ch == ASCII_AT) {
        return .s_req_server_with_at
      }

      if (IS_USERINFO_CHAR(ch) || ch == ASCII_L_BRACKET || ch == ASCII_R_BRACKET) {
        return .s_req_server
      }

      break

    case .s_req_path:
      if (IS_URL_CHAR(ch)) {
        return s
      }

      switch (ch) {
        case ASCII_QUESTION:
          return .s_req_query_string_start

        case ASCII_POUND:
          return .s_req_fragment_start

        default:
          break
      }

      break

    case .s_req_query_string_start,
         .s_req_query_string:
      if (IS_URL_CHAR(ch)) {
        return .s_req_query_string
      }

      switch (ch) {
        case ASCII_QUESTION:
          /* allow extra '?' in query string */
          return .s_req_query_string

        case ASCII_POUND:
          return .s_req_fragment_start

        default:
          break
      }

      break

    case .s_req_fragment_start:
      if (IS_URL_CHAR(ch)) {
        return .s_req_fragment
      }

      switch (ch) {
        case ASCII_QUESTION:
          return .s_req_fragment

        case ASCII_POUND:
          return s

        default:
          break
      }

      break

    case .s_req_fragment:
      if (IS_URL_CHAR(ch)) {
        return s
      }

      switch (ch) {
        case ASCII_QUESTION, ASCII_POUND:
          return s
        default:
          break

      }

      break

    default:
      break
  }

  /* We should never fall out of the switch above unless there's an error */
  return .s_dead
}


/* Executes the parser. Returns number of parsed bytes. Sets
 * `parser->http_errno` on error. */
public func execute (_ settings: http_parser_delegate,
              _ data: UnsafePointer<UInt8>,
              _ len: Int) -> Int
{
  var c, ch: UInt8
  var unhex_val: Int8 = 0
  var p: UnsafePointer<UInt8> = data
  var p_state = self.state
  let lenient = self.lenient_http_headers

  delegate = settings

  /* We're in an error state. Don't bother doing anything. */
  if (self.http_errno != .HPE_OK) {
    return 0
  }

  if (len == 0) {
    switch (p_state) {
      case .s_body_identity_eof:
        /* Use of CALLBACK_NOTIFY() here would erroneously return 1 byte read if
         * we got paused.
         */
        if CALLBACK_NOTIFY(p_state, .message_complete) { return p - data } // CALLBACK_NOTIFY_NOADVANCE
        return 0

      case .s_dead,
           .s_start_req_or_res,
           .s_start_res,
           .s_start_req:
        return 0

      default:
        self.http_errno = .HPE_INVALID_EOF_STATE
        return 1
    }
  }


  if (p_state == .s_header_field) {
    header_field_mark = data
  }
  if (p_state == .s_header_value) {
    header_value_mark = data
  }
  switch (p_state) {
  case .s_req_path,
       .s_req_schema,
       .s_req_schema_slash,
       .s_req_schema_slash_slash,
       .s_req_server_start,
       .s_req_server,
       .s_req_server_with_at,
       .s_req_query_string_start,
       .s_req_query_string,
       .s_req_fragment_start,
       .s_req_fragment:
    url_mark = data
    break
  case .s_res_status:
    status_mark = data
    break
  default:
    break
  }

  p = data
  do {
  while (p != data + len) {
    ch = p[0]

    if (PARSING_HEADER(p_state)) {
      try COUNT_HEADER_SIZE(1)
    }

    switch (p_state) {

      case .s_dead:
        /* this state is used after a 'Connection: close' message
         * the parser will error out if it reads another message
         */
        if (LIKELY(ch == CR || ch == LF)) {
          break
        }

        try SET_ERRNO(.HPE_CLOSED_CONNECTION)

      case .s_start_req_or_res:
        if (ch == CR || ch == LF) {
          break
        }
        self.flags = 0
        self.content_length = ULLONG_MAX

        if (ch == ASCII_H) {
          p_state = .s_res_or_resp_H

          if CALLBACK_NOTIFY(p_state, .message_begin) { return  p - data + 1 }
        } else {
          self.type = .HTTP_REQUEST
          p_state = .s_start_req
          continue
        }

        break

      case .s_res_or_resp_H:
        if (ch == ASCII_T) {
          self.type = .HTTP_RESPONSE
          p_state = .s_res_HT
        } else {
          if (UNLIKELY(ch != ASCII_E)) {
            try SET_ERRNO(.HPE_INVALID_CONSTANT)
          }

          self.type = .HTTP_REQUEST
          self.method = .HTTP_HEAD
          self.index = 2
          p_state = .s_req_method
        }
        break

      case .s_start_res:
        self.flags = 0
        self.content_length = ULLONG_MAX

        switch (ch) {
          case ASCII_H:
            p_state = .s_res_H
            break

          case CR,
               LF:
            break

          default:
            try SET_ERRNO(.HPE_INVALID_CONSTANT)
        }

        if CALLBACK_NOTIFY(p_state, .message_begin) { return  p - data + 1 }
        break

      case .s_res_H:
        try STRICT_CHECK(ch != ASCII_T)
        p_state = .s_res_HT
        break

      case .s_res_HT:
        try STRICT_CHECK(ch != ASCII_T)
        p_state = .s_res_HTT
        break

      case .s_res_HTT:
        try STRICT_CHECK(ch != ASCII_P)
        p_state = .s_res_HTTP
        break

      case .s_res_HTTP:
        try STRICT_CHECK(ch != ASCII_SLASH)
        p_state = .s_res_first_http_major
        break

      case .s_res_first_http_major:
        if (UNLIKELY(ch < ASCII_0 || ch > ASCII_9)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_major = UInt16(ch) - UInt16(ASCII_0)
        p_state = .s_res_http_major
        break

      /* major HTTP version or dot */
      case .s_res_http_major:
        if (ch == ASCII_DOT) {
          p_state = .s_res_first_http_minor
          break
        }

        if (!IS_NUM(ch)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_major *= 10
        self.http_major += UInt16(ch) - UInt16(ASCII_0)

        if (UNLIKELY(self.http_major > 999)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        break

      /* first digit of minor HTTP version */
      case .s_res_first_http_minor:
        if (UNLIKELY(!IS_NUM(ch))) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_minor = UInt16(ch) - UInt16(ASCII_0)
        p_state = .s_res_http_minor
        break

      /* minor HTTP version or end of request line */
      case .s_res_http_minor:
        if (ch == ASCII_SPACE) {
          p_state = .s_res_first_status_code
          break
        }

        if (UNLIKELY(!IS_NUM(ch))) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_minor *= 10
        self.http_minor += UInt16(ch) - UInt16(ASCII_0)

        if (UNLIKELY(self.http_minor > 999)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        break


      case .s_res_first_status_code:
        if (!IS_NUM(ch)) {
          if (ch == ASCII_SPACE) {
            break
          }

          try SET_ERRNO(.HPE_INVALID_STATUS)
        }
        self.status_code = UInt(ch) - UInt(ASCII_0)
        p_state = .s_res_status_code
        break

      case .s_res_status_code:
        if (!IS_NUM(ch)) {
          switch (ch) {
            case ASCII_SPACE:
              p_state = .s_res_status_start
              break
            case CR:
              p_state = .s_res_line_almost_done
              break
            case LF:
              p_state = .s_header_field_start
              break
            default:
              try SET_ERRNO(.HPE_INVALID_STATUS)
          }
          break
        }

        self.status_code *= 10
        self.status_code += UInt(ch) - UInt(ASCII_0)

        if (UNLIKELY(self.status_code > 999)) {
          try SET_ERRNO(.HPE_INVALID_STATUS)
        }

        break

      case .s_res_status_start:
        if (ch == CR) {
          p_state = .s_res_line_almost_done
          break
        }

        if (ch == LF) {
          p_state = .s_header_field_start
          break
        }

        MARK(.status, p)
        p_state = .s_res_status
        self.index = 0
        break


      case .s_res_status:
        if (ch == CR) {
          p_state = .s_res_line_almost_done
          if CALLBACK_DATA(p_state, p, .status) { return p - data + 1 }
          break
        }

        if (ch == LF) {
          p_state = .s_header_field_start
          if CALLBACK_DATA(p_state, p, .status) { return p - data + 1 }
          break
        }

        break

      case .s_res_line_almost_done:
        try STRICT_CHECK(ch != LF)
        p_state = .s_header_field_start
        break

      case .s_start_req:
        if (ch == CR || ch == LF) {
          break
        }
        self.flags = 0
        self.content_length = ULLONG_MAX

        if (UNLIKELY(!IS_ALPHA(ch))) {
          try SET_ERRNO(.HPE_INVALID_METHOD)
        }

        self.method = .HTTP_DELETE
        self.index = 1
        switch (ch) {
          case ASCII_A: self.method = .HTTP_ACL; break
          case ASCII_B: self.method = .HTTP_BIND; break
          case ASCII_C: self.method = .HTTP_CONNECT; /* or COPY, CHECKOUT */ break
          case ASCII_D: self.method = .HTTP_DELETE; break
          case ASCII_G: self.method = .HTTP_GET; break
          case ASCII_H: self.method = .HTTP_HEAD; break
          case ASCII_L: self.method = .HTTP_LOCK; /* or LINK */ break
          case ASCII_M: self.method = .HTTP_MKCOL; /* or MOVE, MKACTIVITY, MERGE, M-SEARCH, MKCALENDAR */ break
          case ASCII_N: self.method = .HTTP_NOTIFY; break
          case ASCII_O: self.method = .HTTP_OPTIONS; break
          case ASCII_P: self.method = .HTTP_POST
            /* or PROPFIND|PROPPATCH|PUT|PATCH|PURGE */
            break
          case ASCII_R: self.method = .HTTP_REPORT; /* or REBIND */ break
          case ASCII_S: self.method = .HTTP_SUBSCRIBE; /* or SEARCH */ break
          case ASCII_T: self.method = .HTTP_TRACE; break
          case ASCII_U: self.method = .HTTP_UNLOCK; /* or UNSUBSCRIBE, UNBIND, UNLINK */ break
          default:
            try SET_ERRNO(.HPE_INVALID_METHOD)
        }
        p_state = .s_req_method

        if CALLBACK_NOTIFY(p_state, .message_begin) { return  p - data + 1 }

        break

      case .s_req_method:
        if (UNLIKELY(ch == ASCII_NUL)) {
          try SET_ERRNO(.HPE_INVALID_METHOD)
        }

        let matcher = method_strings(self.method)
        if (self.index == matcher.count) {
            if ch == ASCII_SPACE {
                p_state = .s_req_spaces_before_url
            }
            else {
                // required new state for Swift since we don't have NULL terminated 'C' strings
                try SET_ERRNO(.HPE_INVALID_METHOD)
            }
        } else if (ch == matcher[self.index]) {
          /* nada */
        } else if (IS_ALPHA(ch)) {
          switch (self.method.rawValue << 16 | self.index << 8 | Int(ch)) {

          case (http_method.HTTP_POST.rawValue << 16 |      1 << 8 | Int(ASCII_U)): self.method = .HTTP_PUT
          case (http_method.HTTP_POST.rawValue << 16 |      1 << 8 | Int(ASCII_A)): self.method = .HTTP_PATCH
          case (http_method.HTTP_CONNECT.rawValue << 16 |   1 << 8 | Int(ASCII_H)): self.method = .HTTP_CHECKOUT
          case (http_method.HTTP_CONNECT.rawValue << 16 |   2 << 8 | Int(ASCII_P)): self.method = .HTTP_COPY
          case (http_method.HTTP_MKCOL.rawValue << 16 |     1 << 8 | Int(ASCII_O)): self.method = .HTTP_MOVE
          case (http_method.HTTP_MKCOL.rawValue << 16 |     1 << 8 | Int(ASCII_E)): self.method = .HTTP_MERGE
          case (http_method.HTTP_MKCOL.rawValue << 16 |     2 << 8 | Int(ASCII_A)): self.method = .HTTP_MKACTIVITY
          case (http_method.HTTP_MKCOL.rawValue << 16 |     3 << 8 | Int(ASCII_A)): self.method = .HTTP_MKCALENDAR
          case (http_method.HTTP_SUBSCRIBE.rawValue << 16 | 1 << 8 | Int(ASCII_E)): self.method = .HTTP_SEARCH
          case (http_method.HTTP_REPORT.rawValue << 16 |    2 << 8 | Int(ASCII_B)): self.method = .HTTP_REBIND
          case (http_method.HTTP_POST.rawValue << 16 |      1 << 8 | Int(ASCII_R)): self.method = .HTTP_PROPFIND
          case (http_method.HTTP_PROPFIND.rawValue << 16 |  4 << 8 | Int(ASCII_P)): self.method = .HTTP_PROPPATCH
          case (http_method.HTTP_PUT.rawValue << 16 |       2 << 8 | Int(ASCII_R)): self.method = .HTTP_PURGE
          case (http_method.HTTP_LOCK.rawValue << 16 |      1 << 8 | Int(ASCII_I)): self.method = .HTTP_LINK
          case (http_method.HTTP_UNLOCK.rawValue << 16 |    2 << 8 | Int(ASCII_S)): self.method = .HTTP_UNSUBSCRIBE
          case (http_method.HTTP_UNLOCK.rawValue << 16 |    2 << 8 | Int(ASCII_B)): self.method = .HTTP_UNBIND
          case (http_method.HTTP_UNLOCK.rawValue << 16 |    3 << 8 | Int(ASCII_I)): self.method = .HTTP_UNLINK
          default:
            try SET_ERRNO(.HPE_INVALID_METHOD)
          }
        } else if (ch == ASCII_HYPHEN &&
                   self.index == 1 &&
                   self.method == .HTTP_MKCOL) {
            self.method = .HTTP_MSEARCH;
        } else {
          try SET_ERRNO(.HPE_INVALID_METHOD)
        }

        self.index += 1
        break

      case .s_req_spaces_before_url:
        if (ch == ASCII_SPACE) { break }

        MARK(.url, p)
        if (self.method == .HTTP_CONNECT) {
          p_state = .s_req_server_start
        }

        p_state = parse_url_char(p_state, ch)
        if (UNLIKELY(p_state == .s_dead)) {
          try SET_ERRNO(.HPE_INVALID_URL)
        }

        break

      case .s_req_schema,
           .s_req_schema_slash,
           .s_req_schema_slash_slash,
           .s_req_server_start:
        switch (ch) {
          /* No whitespace allowed here */
          case ASCII_SPACE,
               CR,
               LF:
            try SET_ERRNO(.HPE_INVALID_URL)
          default:
            p_state = parse_url_char(p_state, ch)
            if (UNLIKELY(p_state == .s_dead)) {
              try SET_ERRNO(.HPE_INVALID_URL)
            }
        }

        break

      case .s_req_server,
           .s_req_server_with_at,
           .s_req_path,
           .s_req_query_string_start,
           .s_req_query_string,
           .s_req_fragment_start,
           .s_req_fragment:

        switch (ch) {
          case ASCII_SPACE:
            p_state = .s_req_http_start
            if CALLBACK_DATA(p_state, p, .url) { return p - data + 1 }
            break
          case CR,
               LF:
            self.http_major = 0
            self.http_minor = 9
            p_state = (ch == CR) ?
              .s_req_line_almost_done :
              .s_header_field_start
            if CALLBACK_DATA(p_state, p, .url) { return p - data + 1 }
            break
          default:
            p_state = parse_url_char(p_state, ch)
            if (UNLIKELY(p_state == .s_dead)) {
              try SET_ERRNO(.HPE_INVALID_URL)
            }
        }
        break

      case .s_req_http_start:
        switch (ch) {
          case ASCII_H:
            p_state = .s_req_http_H
            break
          case ASCII_SPACE:
            break
          default:
            try SET_ERRNO(.HPE_INVALID_CONSTANT)
        }
        break

      case .s_req_http_H:
        try STRICT_CHECK(ch != ASCII_T)
        p_state = .s_req_http_HT
        break

      case .s_req_http_HT:
        try STRICT_CHECK(ch != ASCII_T)
        p_state = .s_req_http_HTT
        break

      case .s_req_http_HTT:
        try STRICT_CHECK(ch != ASCII_P)
        p_state = .s_req_http_HTTP
        break

      case .s_req_http_HTTP:
        try STRICT_CHECK(ch != ASCII_SLASH)
        p_state = .s_req_first_http_major
        break

      /* first digit of major HTTP version */
      case .s_req_first_http_major:
        if (UNLIKELY(ch < ASCII_1 || ch > ASCII_9)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_major = UInt16(ch) - UInt16(ASCII_0)
        p_state = .s_req_http_major
        break

      /* major HTTP version or dot */
      case .s_req_http_major:
        if (ch == ASCII_DOT) {
          p_state = .s_req_first_http_minor
          break
        }

        if (UNLIKELY(!IS_NUM(ch))) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_major *= 10
        self.http_major += UInt16(ch) - UInt16(ASCII_0)

        if (UNLIKELY(self.http_major > 999)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        break

      /* first digit of minor HTTP version */
      case .s_req_first_http_minor:
        if (UNLIKELY(!IS_NUM(ch))) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_minor = UInt16(ch) - UInt16(ASCII_0)
        p_state = .s_req_http_minor
        break

      /* minor HTTP version or end of request line */
      case .s_req_http_minor:
        if (ch == CR) {
          p_state = .s_req_line_almost_done
          break
        }

        if (ch == LF) {
          p_state = .s_header_field_start
          break
        }

        /* XXX allow spaces after digit? */

        if (UNLIKELY(!IS_NUM(ch))) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        self.http_minor *= 10
        self.http_minor += UInt16(ch) - UInt16(ASCII_0)

        if (UNLIKELY(self.http_minor > 999)) {
          try SET_ERRNO(.HPE_INVALID_VERSION)
        }

        break

      /* end of request line */
      case .s_req_line_almost_done:
        if (UNLIKELY(ch != LF)) {
          try SET_ERRNO(.HPE_LF_EXPECTED)
        }

        p_state = .s_header_field_start
        break

      case .s_header_field_start:
        if (ch == CR) {
          p_state = .s_headers_almost_done
          break
        }

        if (ch == LF) {
          /* they might be just sending \n instead of \r\n so this would be
           * the second \n to denote the end of headers*/
          p_state = .s_headers_almost_done
          continue
        }

        c = TOKEN(ch)

        if (UNLIKELY(c == ASCII_NUL)) {
          try SET_ERRNO(.HPE_INVALID_HEADER_TOKEN)
        }

        MARK(.header_field, p)

        self.index = 0
        p_state = .s_header_field

        switch (c) {
          case ASCII_c:
            self.header_state = .h_C
            break

          case ASCII_p:
            self.header_state = .h_matching_proxy_connection
            break

          case ASCII_t:
            self.header_state = .h_matching_transfer_encoding
            break

          case ASCII_u:
            self.header_state = .h_matching_upgrade
            break

          default:
            self.header_state = .h_general
            break
        }
        break

      case .s_header_field:
        let start: UnsafePointer<UInt8> = p

        while (p != data + len) {
          ch = p[0]
          c = TOKEN(ch)

          if (c == ASCII_NUL) {
            break
          }

          switch (self.header_state) {
            case .h_general:
              break

            case .h_C:
              self.index += 1
              self.header_state = (c == ASCII_o ? .h_CO : .h_general)
              break

            case .h_CO:
              self.index += 1
              self.header_state = (c == ASCII_n ? .h_CON : .h_general)
              break

            case .h_CON:
              self.index += 1
              switch (c) {
                case ASCII_n:
                  self.header_state = .h_matching_connection
                  break
                case ASCII_t:
                  self.header_state = .h_matching_content_length
                  break
                default:
                  self.header_state = .h_general
                  break
              }
              break

            /* connection */

            case .h_matching_connection:
              self.index += 1
              if (self.index > CONNECTION.count
                  || c != CONNECTION[self.index]) {
                self.header_state = .h_general
              } else if (self.index == CONNECTION.count) {
                self.header_state = .h_connection
              }
              break

            /* proxy-connection */

            case .h_matching_proxy_connection:
              self.index += 1
              if (self.index > PROXY_CONNECTION.count
                  || c != PROXY_CONNECTION[self.index]) {
                self.header_state = .h_general
              } else if (self.index == PROXY_CONNECTION.count - 1) {
                self.header_state = .h_connection
              }
              break

            /* content-length */

            case .h_matching_content_length:
              self.index += 1
              if (self.index > CONTENT_LENGTH.count
                  || c != CONTENT_LENGTH[self.index]) {
                self.header_state = .h_general
              } else if (self.index == CONTENT_LENGTH.count - 1) {
                self.header_state = .h_content_length
              }
              break

            /* transfer-encoding */

            case .h_matching_transfer_encoding:
              self.index += 1
              if (self.index > TRANSFER_ENCODING.count
                  || c != TRANSFER_ENCODING[self.index]) {
                self.header_state = .h_general
              } else if (self.index == TRANSFER_ENCODING.count - 1) {
                self.header_state = .h_transfer_encoding
              }
              break

            /* upgrade */

            case .h_matching_upgrade:
              self.index += 1
              if (self.index > UPGRADE.count
                  || c != UPGRADE[self.index]) {
                self.header_state = .h_general
              } else if (self.index == UPGRADE.count - 1) {
                self.header_state = .h_upgrade
              }
              break

            case .h_connection,
                 .h_content_length,
                 .h_transfer_encoding,
                 .h_upgrade:
              if (ch != ASCII_SPACE) { self.header_state = .h_general }
              break

            default:
              assert(false, "Unknown header_state")
              break
          }
          p += 1
        }

        try COUNT_HEADER_SIZE(p - start)

        if (p == data + len) {
          p -= 1
          break
        }

        if (ch == ASCII_COLON) {
          p_state = .s_header_value_discard_ws
          if CALLBACK_DATA(p_state, p, .header_field) { return p - data + 1 }
          break
        }

        try SET_ERRNO(.HPE_INVALID_HEADER_TOKEN)

      case .s_header_value_discard_ws:
        if (ch == ASCII_SPACE || ch == ASCII_TAB) { break }

        if (ch == CR) {
          p_state = .s_header_value_discard_ws_almost_done
          break
        }

        if (ch == LF) {
          p_state = .s_header_value_discard_lws
          break
        }

        fallthrough
        /* FALLTHROUGH */

      case .s_header_value_start:
        MARK(.header_value, p)

        p_state = .s_header_value
        self.index = 0

        c = LOWER(ch)

        switch (self.header_state) {
          case .h_upgrade:
            self.flags |= F_UPGRADE
            self.header_state = .h_general
            break

          case .h_transfer_encoding:
            /* looking for 'Transfer-Encoding: chunked' */
            if (ASCII_c == c) {
              self.header_state = .h_matching_transfer_encoding_chunked
            } else {
              self.header_state = .h_general
            }
            break

          case .h_content_length:
            if (UNLIKELY(!IS_NUM(ch))) {
              try SET_ERRNO(.HPE_INVALID_CONTENT_LENGTH)
            }

            if ((self.flags & F_CONTENTLENGTH) != 0) {
                try SET_ERRNO(.HPE_UNEXPECTED_CONTENT_LENGTH)
            }

            self.flags |= F_CONTENTLENGTH
            self.content_length = UInt64(ch) - UInt64(ASCII_0)
            break

          case .h_connection:
            /* looking for 'Connection: keep-alive' */
            if (c == ASCII_k) {
              self.header_state = .h_matching_connection_keep_alive
            /* looking for 'Connection: close' */
            } else if (c == ASCII_c) {
              self.header_state = .h_matching_connection_close
            } else if (c == ASCII_u) {
              self.header_state = .h_matching_connection_upgrade
            } else {
              self.header_state = .h_matching_connection_token
            }
            break

          /* Multi-value `Connection` header */
          case .h_matching_connection_token_start:
            break

          default:
            self.header_state = .h_general
            break
        }
        break

      case .s_header_value:
        let start: UnsafePointer<UInt8> = p
        var h_state = self.header_state
        var continueParse = false
        while (p != data + len) {
          ch = p[0]
          if (ch == CR) {
            p_state = .s_header_almost_done
            self.header_state = h_state
            if CALLBACK_DATA(p_state, p, .header_value) { return p - data + 1 }
            break
          }

          if (ch == LF) {
            p_state = .s_header_almost_done
            try COUNT_HEADER_SIZE(p - start)
            self.header_state = h_state
            if CALLBACK_DATA(p_state, p, .header_value) { return p - data } // CALLBACK_DATA_NOADVANCE
            // a continue here breaks out of the local while loop and not the master
            continueParse = true
            break
          }

          if (!lenient && !IS_HEADER_CHAR(ch)) {
            try SET_ERRNO(.HPE_INVALID_HEADER_TOKEN)
          }
          c = LOWER(ch)

          switch (h_state) {
            case .h_general:
              var limit: Int = data + len - p

              limit = min(limit, HTTP_MAX_HEADER_SIZE)
              // TODO
              let p_cr = memchr(p, 13, limit) // 13=CR
              let p_lf = memchr(p, 10, limit) // 10=LF
              if (p_cr != nil) {
                if (p_lf != nil && p_cr! >= p_lf!) {
                  p = UnsafePointer<UInt8>(p_lf!.assumingMemoryBound(to: UInt8.self))
                } else {
                  p = UnsafePointer<UInt8>(p_cr!.assumingMemoryBound(to: UInt8.self))
                }
              } else if (UNLIKELY(p_lf != nil)) {
                p = UnsafePointer<UInt8>(p_lf!.assumingMemoryBound(to: UInt8.self))
              } else {
                p = data + len
              }
              p -= 1

              break

            case .h_connection,
                 .h_transfer_encoding:
              assert(false, "Shouldn't get here.")
              break

            case .h_content_length:
              var t: UInt64 = 0

              if (ch == ASCII_SPACE) { break }

              if (UNLIKELY(!IS_NUM(ch))) {
                self.header_state = h_state
                try SET_ERRNO(.HPE_INVALID_CONTENT_LENGTH)
              }

              t = self.content_length
              t *= 10
              t += UInt64(ch) - UInt64(ASCII_0)

              /* Overflow? Test against a conservative limit for simplicity. */
              if (UNLIKELY((ULLONG_MAX - 10) / 10 < self.content_length)) {
                self.header_state = h_state
                try SET_ERRNO(.HPE_INVALID_CONTENT_LENGTH)
              }

              self.content_length = t
              break

            /* Transfer-Encoding: chunked */
            case .h_matching_transfer_encoding_chunked:
              self.index += 1
              if (self.index > CHUNKED.count
                  || c != CHUNKED[self.index]) {
                h_state = .h_general
              } else if (self.index == CHUNKED.count - 1) {
                h_state = .h_transfer_encoding_chunked
              }
              break

            case .h_matching_connection_token_start:
              /* looking for 'Connection: keep-alive' */
              if (c == ASCII_k) {
                h_state = .h_matching_connection_keep_alive
              /* looking for 'Connection: close' */
              } else if (c == ASCII_c) {
                h_state = .h_matching_connection_close
              } else if (c == ASCII_u) {
                h_state = .h_matching_connection_upgrade
              } else if (STRICT_TOKEN(c) != 0) {
                h_state = .h_matching_connection_token
              } else if (c == ASCII_SPACE || c == ASCII_TAB) {
                /* Skip lws */
              } else {
                h_state = .h_general
              }
              break

            /* looking for 'Connection: keep-alive' */
            case .h_matching_connection_keep_alive:
              self.index += 1
              if (self.index > KEEP_ALIVE.count
                  || c != KEEP_ALIVE[self.index]) {
                h_state = .h_matching_connection_token
              } else if (self.index == KEEP_ALIVE.count - 1) {
                h_state = .h_connection_keep_alive
              }
              break

            /* looking for 'Connection: close' */
            case .h_matching_connection_close:
              self.index += 1
              if (self.index > CLOSE.count || c != CLOSE[self.index]) {
                h_state = .h_matching_connection_token
              } else if (self.index == CLOSE.count - 1) {
                h_state = .h_connection_close
              }
              break

            /* looking for 'Connection: upgrade' */
            case .h_matching_connection_upgrade:
              self.index += 1
              if (self.index > UPGRADE.count ||
                  c != UPGRADE[self.index]) {
                h_state = .h_matching_connection_token
              } else if (self.index == UPGRADE.count - 1) {
                h_state = .h_connection_upgrade
              }
              break

            case .h_matching_connection_token:
              if (ch == ASCII_COMMA) {
                h_state = .h_matching_connection_token_start
                self.index = 0
              }
              break

            case .h_transfer_encoding_chunked:
              if (ch != ASCII_SPACE) { h_state = .h_general }
              break

            case .h_connection_keep_alive,
                 .h_connection_close,
                 .h_connection_upgrade:
              if (ch == ASCII_COMMA) {
                if (h_state == .h_connection_keep_alive) {
                  self.flags |= F_CONNECTION_KEEP_ALIVE
                } else if (h_state == .h_connection_close) {
                  self.flags |= F_CONNECTION_CLOSE
                } else if (h_state == .h_connection_upgrade) {
                  self.flags |= F_CONNECTION_UPGRADE
                }
                h_state = .h_matching_connection_token_start
                self.index = 0
              } else if (ch != ASCII_SPACE) {
                h_state = .h_matching_connection_token
              }
              break

            default:
              p_state = .s_header_value
              h_state = .h_general
              break
          }
          p += 1
        }
        if continueParse {
            continue
        }
        self.header_state = h_state

        try COUNT_HEADER_SIZE(p - start)

        if (p == data + len) {
          p -= 1
        }
        break

      case .s_header_almost_done:
        if (UNLIKELY(ch != LF)) {
          try SET_ERRNO(.HPE_LF_EXPECTED)
        }
        p_state = .s_header_value_lws
        break

      case .s_header_value_lws:
        if (ch == ASCII_SPACE || ch == ASCII_TAB) {
          p_state = .s_header_value_start
          continue
        }

        /* finished the header */
        switch (self.header_state) {
          case .h_connection_keep_alive:
            self.flags |= F_CONNECTION_KEEP_ALIVE
            break
          case .h_connection_close:
            self.flags |= F_CONNECTION_CLOSE
            break
          case .h_transfer_encoding_chunked:
            self.flags |= F_CHUNKED
            break
          case .h_connection_upgrade:
            self.flags |= F_CONNECTION_UPGRADE
            break
          default:
            break
        }

        p_state = .s_header_field_start
        continue

      case .s_header_value_discard_ws_almost_done:
        try STRICT_CHECK(ch != LF)
        p_state = .s_header_value_discard_lws
        break

      case .s_header_value_discard_lws:
        if (ch == ASCII_SPACE || ch == ASCII_TAB) {
          p_state = .s_header_value_discard_ws
          break
        } else {
          switch (self.header_state) {
            case .h_connection_keep_alive:
              self.flags |= F_CONNECTION_KEEP_ALIVE
              break
            case .h_connection_close:
              self.flags |= F_CONNECTION_CLOSE
              break
            case .h_connection_upgrade:
              self.flags |= F_CONNECTION_UPGRADE
              break
            case .h_transfer_encoding_chunked:
              self.flags |= F_CHUNKED
              break
            default:
              break
          }

          /* header value was empty */
          MARK(.header_value, p)
          p_state = .s_header_field_start
          if CALLBACK_DATA(p_state, p, .header_value) { return p - data } // CALLBACK_DATA_NOADVANCE
          continue
        }

      case .s_headers_almost_done:
        try STRICT_CHECK(ch != LF)

        if (self.flags & F_TRAILING) != 0 {
          /* End of a chunked request */
          p_state = .s_message_done
          if CALLBACK_NOTIFY(p_state, .chunk_complete) { return p - data } // CALLBACK_NOTIFY_NOADVANCE
          continue
        }

        /* Cannot use chunked encoding and a content-length header together
           per the HTTP specification. */
        if (((self.flags & F_CHUNKED) != 0) &&
            ((self.flags & F_CONTENTLENGTH) != 0)) {
          try SET_ERRNO(.HPE_UNEXPECTED_CONTENT_LENGTH)
        }

        p_state = .s_headers_done

        /* Set this here so that on_headers_complete() callbacks can see it */
        self.upgrade =
          ((self.flags & F_UPGRADE | F_CONNECTION_UPGRADE) ==
            (F_UPGRADE | F_CONNECTION_UPGRADE) ||
           self.method == .HTTP_CONNECT)

        /* Here we call the headers_complete callback. This is somewhat
         * different than other callbacks because if the user returns 1, we
         * will interpret that as saying that this message has no body. This
         * is needed for the annoying case of recieving a response to a HEAD
         * request.
         *
         * We'd like to use CALLBACK_NOTIFY_NOADVANCE() here but we cannot, so
         * we have to simulate it by handling a change in errno below.
         */
        if (delegate != nil) {
          switch (delegate!.on_headers_complete()) {
            case 0:
              break

            case 2:
              self.upgrade = true
              fallthrough

            case 1:
              self.flags |= F_SKIPBODY
              break

            default:
              try SET_ERRNO(.HPE_CB_headers_complete)
              self.state = p_state
              return(p - data) /* Error */
          }
        }

        if (self.http_errno != .HPE_OK) {
          self.state = p_state
          return(p - data)

        }

        continue

      case .s_headers_done:
        var hasBody = false
        try STRICT_CHECK(ch != LF)

        self.nread = 0

        hasBody = (self.flags & F_CHUNKED) != 0 ||
          (self.content_length > 0 && self.content_length != ULLONG_MAX)
        if (self.upgrade && (self.method == .HTTP_CONNECT ||
                                (self.flags & F_SKIPBODY) != 0 || !hasBody)) {
          /* Exit, the rest of the message is in a different protocol. */
          p_state = NEW_MESSAGE()
          if CALLBACK_NOTIFY(p_state, .message_complete) { return  p - data + 1 }
          self.state = p_state
          return((p - data) + 1)
        }

        if (self.flags & F_SKIPBODY) != 0 {
          p_state = NEW_MESSAGE()
          if CALLBACK_NOTIFY(p_state, .message_complete) { return  p - data + 1 }
        } else if (self.flags & F_CHUNKED != 0) {
          /* chunked encoding - ignore Content-Length header */
          p_state = .s_chunk_size_start
        } else {
          if (self.content_length == 0) {
            /* Content-Length header given but zero: Content-Length: 0\r\n */
            p_state = NEW_MESSAGE()
            if CALLBACK_NOTIFY(p_state, .message_complete) { return  p - data + 1 }
          } else if (self.content_length != ULLONG_MAX) {
            /* Content-Length header given and non-zero */
            p_state = .s_body_identity
          } else {
            if (!http_message_needs_eof()) {
              /* Assume content-length 0 - read the next */
              p_state = NEW_MESSAGE()
              if CALLBACK_NOTIFY(p_state, .message_complete) { return  p - data + 1 }
            } else {
              /* Read body until EOF */
              p_state = .s_body_identity_eof
            }
          }
        }

        break

      case .s_body_identity:
        let to_read: UInt64 = min(self.content_length,
                               UInt64((data + len) - p))

        assert(self.content_length != 0
            && self.content_length != ULLONG_MAX)

        /* The difference between advancing content_length and p is because
         * the latter will automaticaly advance on the next loop iteration.
         * Further, if content_length ends up at 0, we want to see the last
         * byte again for our message complete callback.
         */
        MARK(.body, p)
        self.content_length -= to_read
        p += Int(to_read - 1)

        if (self.content_length == 0) {
          p_state = .s_message_done

          /* Mimic CALLBACK_DATA_NOADVANCE() but with one extra byte.
           *
           * The alternative to doing this is to wait for the next byte to
           * trigger the data callback, just as in every other case. The
           * problem with this is that this makes it difficult for the test
           * harness to distinguish between complete-on-EOF and
           * complete-on-length. It's not clear that this distinction is
           * important for applications, but let's keep it for now.
           */
          if CALLBACK_DATA_(p_state, p, .body, p - body_mark! + 1) { return p - data }
          continue
        }

        break

      /* read until EOF */
      case .s_body_identity_eof:
        MARK(.body, p)
        p = data + len - 1

        break

      case .s_message_done:
        p_state = NEW_MESSAGE()
        if CALLBACK_NOTIFY(p_state, .message_complete) { return  p - data + 1 }
        if (self.upgrade) {
          /* Exit, the rest of the message is in a different protocol. */
          self.state = p_state
          return((p - data) + 1)
        }
        break

      case .s_chunk_size_start:
        assert(self.nread == 1)
        assert((self.flags & F_CHUNKED) != 0)

        unhex_val = unhex[Int(ch)]
        if (UNLIKELY(unhex_val == -1)) {
          try SET_ERRNO(.HPE_INVALID_CHUNK_SIZE)
        }

        self.content_length = UInt64(unhex_val)
        p_state = .s_chunk_size
        break

      case .s_chunk_size:
        var t: UInt64 = 0

        assert((self.flags & F_CHUNKED) != 0)

        if (ch == CR) {
          p_state = .s_chunk_size_almost_done
          break
        }

        unhex_val = unhex[Int(ch)]

        if (unhex_val == -1) {
          if (ch == ASCII_SEMICOLON || ch == ASCII_SPACE) {
            p_state = .s_chunk_parameters
            break
          }

          try SET_ERRNO(.HPE_INVALID_CHUNK_SIZE)
        }

        t = self.content_length
        t *= 16
        t += UInt64(unhex_val)

        /* Overflow? Test against a conservative limit for simplicity. */
        if (UNLIKELY((ULLONG_MAX - 16) / 16 < self.content_length)) {
          try SET_ERRNO(.HPE_INVALID_CONTENT_LENGTH)
        }

        self.content_length = t
        break

      case .s_chunk_parameters:
        assert((self.flags & F_CHUNKED) != 0)
        /* just ignore this shit. TODO check for overflow */
        if (ch == CR) {
          p_state = .s_chunk_size_almost_done
          break
        }
        break

      case .s_chunk_size_almost_done:
        assert((self.flags & F_CHUNKED) != 0)
        try STRICT_CHECK(ch != LF)

        self.nread = 0

        if (self.content_length == 0) {
          self.flags |= F_TRAILING
          p_state = .s_header_field_start
        } else {
          p_state = .s_chunk_data
        }
        if CALLBACK_NOTIFY(p_state, .chunk_header) { return  p - data + 1 }
        break

      case .s_chunk_data:
        let to_read: UInt64 = min(self.content_length,
                               UInt64((data + len) - p))

        assert((self.flags & F_CHUNKED) != 0)
        assert(self.content_length != 0
            && self.content_length != ULLONG_MAX)

        /* See the explanation in s_body_identity for why the content
         * length and data pointers are managed this way.
         */
        MARK(.body, p)
        self.content_length -= to_read
        p += Int(to_read - 1)

        if (self.content_length == 0) {
          p_state = .s_chunk_data_almost_done
        }

        break

      case .s_chunk_data_almost_done:
        assert((self.flags & F_CHUNKED) != 0)
        assert(self.content_length == 0)
        try STRICT_CHECK(ch != CR)
        p_state = .s_chunk_data_done
        if CALLBACK_DATA(p_state, p, .body) { return p - data + 1 }
        break

      case .s_chunk_data_done:
        assert((self.flags & F_CHUNKED) != 0)
        try STRICT_CHECK(ch != LF)
        self.nread = 0
        p_state = .s_chunk_size_start
        if CALLBACK_NOTIFY(p_state, .chunk_complete) { return  p - data + 1 }
        break

      // not needed since Swift will warn us of any unhandled state
      /*default:
        assert(false, "unhandled state")
        try SET_ERRNO(.HPE_INVALID_INTERNAL_STATE)*/
    }

    p += 1
  }

  /* Run callbacks for any marks that we have leftover after we ran our of
   * bytes. There should be at most one of these set, so it's OK to invoke
   * them in series (unset marks will not result in callbacks).
   *
   * We use the NOADVANCE() variety of callbacks here because 'p' has already
   * overflowed 'data' and this allows us to correct for the off-by-one that
   * we'd otherwise have (since CALLBACK_DATA() is meant to be run with a 'p'
   * value that's in-bounds).
   */

  assert(((header_field_mark != nil ? 1 : 0) +
          (header_value_mark != nil ? 1 : 0) +
          (url_mark != nil ? 1 : 0)  +
          (body_mark != nil ? 1 : 0) +
          (status_mark != nil ? 1 : 0)) <= 1)

  if CALLBACK_DATA(p_state, p, .header_field) { return p - data } // CALLBACK_DATA_NOADVANCE
  if CALLBACK_DATA(p_state, p, .header_value) { return p - data } // CALLBACK_DATA_NOADVANCE
  if CALLBACK_DATA(p_state, p, .url) { return p - data } // CALLBACK_DATA_NOADVANCE
  if CALLBACK_DATA(p_state, p, .body) { return p - data } // CALLBACK_DATA_NOADVANCE
  if CALLBACK_DATA(p_state, p, .status) { return p - data } // CALLBACK_DATA_NOADVANCE

  self.state = p_state
  return(len)

  } // end of do
  catch {
    if (self.http_errno == .HPE_OK) {
      self.http_errno = .HPE_UNKNOWN
    }
    self.state = p_state
    return(p - data)
  }
}


/* Does the parser need to see an EOF to find the end of the message? */
private func http_message_needs_eof() -> Bool
{
  if (self.type == .HTTP_REQUEST) {
    return false
  }

  /* See RFC 2616 section 4.4 */
  if (self.status_code / 100 == 1 || /* 1xx e.g. Continue */
      self.status_code == 204 ||     /* No Content */
      self.status_code == 304 ||     /* Not Modified */
      (self.flags & F_SKIPBODY) != 0) {     /* response to a HEAD request */
    return false
  }

  if ((self.flags & F_CHUNKED) != 0 || self.content_length != ULLONG_MAX) {
    return false
  }

  return true
}


/* If should_keep_alive() in the on_headers_complete or
 * on_message_complete callback returns 0, then this should be
 * the last message on the connection.
 * If you are the server, respond with the "Connection: close" header.
 * If you are the client, close the connection.
 */
public func should_keep_alive() -> Bool
{
  if (self.http_major > 0 && self.http_minor > 0) {
    /* HTTP/1.1 */
    if ((self.flags & F_CONNECTION_CLOSE) != 0) {
      return false
    }
  } else {
    /* HTTP/1.0 or earlier */
    if ((self.flags & F_CONNECTION_KEEP_ALIVE) != 0) {
      return false
    }
  }

  return !http_message_needs_eof()
}


/* Returns a string version of the HTTP method. */
public func method_str(_ m: http_method) -> String
{
  return m.string
}


public func reset(_ t: http_parser_type)
{
  type = t
  self.state = (t == .HTTP_REQUEST ? .s_start_req : (t == .HTTP_RESPONSE ? .s_start_res : .s_start_req_or_res))
  http_errno = .HPE_OK

  flags = 0
  header_state = .h_general
  index = 0
  lenient_http_headers = false
  nread = 0
  content_length = 0
  http_major = 0
  http_minor = 0
  status_code = 0
  method = .HTTP_DELETE
  upgrade = false
}


/* Return a string name of the given error */
public class func errno_name(_ err: http_errno) -> String {
  return err.rawValue
}

/* Return a string description of the given error */
public class func errno_description(_ err: http_errno) -> String {
  return err.description
}

/* Pause or un-pause the parser; a nonzero value pauses */
public func pause(_ paused: Bool) {
  /* Users should only be pausing/unpausing a parser that is not in an error
   * state. In non-debug builds, there's not much that we can do about this
   * other than ignore it.
   */
  if (self.http_errno == .HPE_OK ||
      self.http_errno == .HPE_PAUSED) {
    self.http_errno = (paused ? .HPE_PAUSED : .HPE_OK)
  } else {
    assert(false, "Attempting to pause parser in error state")
  }
}

/* Checks if this is the final chunk of the body. */
public func body_is_final() -> Bool {
    return self.state == .s_message_done
}

/* Returns the library version. Bits 16-23 contain the major version number,
 * bits 8-15 the minor version number and bits 0-7 the patch level.
 * Usage example:
 *
 *   let version = http_parser.version()
 *   let major = (version >> 16) & 255
 *   let minor = (version >> 8) & 255
 *   let patch = version & 255
 *   print("http_parser v\(major).\(minor).\(patch)")
 */
public class func version() -> UInt {
  return UInt(HTTP_PARSER_VERSION_MAJOR << 16 +
         HTTP_PARSER_VERSION_MINOR << 8 +
         HTTP_PARSER_VERSION_PATCH)
}

} // end of class http_parser
