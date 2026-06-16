## [Unreleased]

## [0.1.0] - 2026-06-16

### Added

- Initial release of pgoutput-source-adapter.
- CDC::Core source adapter implementation.
- Normalization of decoded pgoutput Insert events into CDC::Core::ChangeEvent.
- Normalization of decoded pgoutput Update events into CDC::Core::ChangeEvent.
- Normalization of decoded pgoutput Delete events into CDC::Core::ChangeEvent.
- Normalization of transaction boundaries into CDC::Core::TransactionEnvelope.
- Configurable primary key resolution.
- Configurable metadata generation.
- Namespace compatibility aliases.

### Documentation

- Expanded YARD documentation.
- Added architecture and usage examples.
- Improved API documentation coverage.
- Added descriptions for public YARD tags.

### Quality

- Added comprehensive unit tests.
- Added SimpleCov line and branch coverage reporting.
- Added Steep type checking support.
- Added RuboCop integration.

### Coverage

- Line Coverage: 97.62%
- Branch Coverage: 91.18%