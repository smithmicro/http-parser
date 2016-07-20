HTTP Parser - Swift 3
===========

This is a parser for HTTP messages written in Swift 3. It parses both requests and
responses. The parser is designed to be used in performance HTTP
applications. It does not make any allocations, it does not
buffer data and it can be interrupted at anytime.

This project was forked and ported from the 'C' [http-parser](https://github.com/nodejs/http-parser) project.

Features:

  * No dependencies
  * Handles persistent streams (keep-alive)
  * Decodes chunked encoding
  * Upgrade support
  * Defends against buffer overflow attacks

The parser extracts the following information from HTTP messages:

  * Header fields and values
  * Content-Length
  * Request method
  * Response status code
  * Transfer-Encoding
  * HTTP version
  * Request URL
  * Message body


Swift Objectives
-----

  * Leverage the existing 'C' logic from http-parser
  * Allow for http-parser.c changes to be easily ported in the future.  As such:
    * Intentionally not adopting Swift naming guidelines
    * Keep all variable and function names the same
      * Only change public API's to be object oriented
    * Leave unnecessary markup in place such as:
      * End of case 'break'
      * Parenthesis in if statements


Performance
-----

The Swift version is currently 1.4 times slower than the 'C' version.  However
the library is processing over 500,000 requests per second which should meet the requirements of most performance Swift applications.

Tests run with Release mode on a MacBook Air (MacBookAir6,2):
* http-parser - 'C' - 782K req/sec
* HTTPParser - Swift - 566K req/sec

Although all memory allocations have been optimized out there still are several retain/release calls which could be optimized.  It would be ideal for an expert in the Xcode Instruments Time Profiler to review the library.


API Changes
-----

| http-parser                 | HTTPParser      |
|-----------------------------|---------------|
| struct http_parser          | class http_parser |
| struct http_parser_settings | protocol http_parser_delegate |
| http_parser_version()       | version() |
| http_parser_init()          | reset() |
| http_parser_settings_init() | _Use protocol above_ |
| http_parser_execute()       | execute() |
| http_should_keep_alive()    | should_keep_alive() |
| http_method_str()           | method_str() |
| http_errno_name()           | errno_name() |
| http_errno_description()    | errno_description() |
| http_parser_pause()         | pause() |
| http_body_is_final()        | body_is_final() |
| http_parser_url_init()      | _Not ported - see below_ |
| http_parser_parse_url()     | _Not ported - see below_ |


Testing
-----
macOS
* Install Xcode 8 Beta 2
* Set Command Line Tools in Preferences/Locations to Xcode 8.0
* run 'swift build --clean'
* run 'swift build'
* run 'swift test'

Linux
* Install Docker for Mac v1.12
* run 'docker-compose up'


To Do
-----
* Finish porting unit tests (test.swift)
* Further Xcode Instruments Time Profiler review
* Port recent http-parser changes (i.e. version 2.7.1)
* Support Xcode Profiling via 'swift package generate-xcodeproj'


URL Parsing
-----
The URL parsing code from http-parser was not ported since Swift 3 applications can rely on the native NSURL/URL class in Foundation.
