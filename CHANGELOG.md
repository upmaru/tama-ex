# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-12-19

### Added
- Initial release of TamaEx
- HTTP client wrapper with `Tama.client/1` function
- Structured response handling with `Tama.handle_response/2`
- Support for schema parsing with Ecto-style modules
- Error handling for various HTTP status codes (404, 422, 4xx, 5xx)
- Support for both 200 and 201 success responses
- Built on top of Req HTTP client

### Dependencies
- Ecto ~> 3.13 for schema support
- Req ~> 0.5 for HTTP client functionality

[Unreleased]: https://github.com/upmaru/tama-ex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/upmaru/tama-ex/releases/tag/v0.1.0