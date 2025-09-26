# Changelog

All notable changes to the Metal Performance Tester project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- GitHub Actions workflow for automated releases ([#123](https://github.com/yourusername/Metal-Performance-Tester/issues/123))
- Comprehensive release documentation ([#124](https://github.com/yourusername/Metal-Performance-Tester/issues/124))
- Pre-release testing capabilities ([#125](https://github.com/yourusername/Metal-Performance-Tester/issues/125))

### Changed
- Enhanced release workflow with better build process ([#126](https://github.com/yourusername/Metal-Performance-Tester/pull/126))
- Improved release notes generation ([#127](https://github.com/yourusername/Metal-Performance-Tester/pull/127))

## [1.0.0] - 2024-01-15

[Full Changelog](https://github.com/yourusername/Metal-Performance-Tester/compare/v0.9.0...v1.0.0)

### Added
- Initial release of Metal Performance Tester
- Comprehensive GPU performance regression testing
- Real hardware performance counter support for Apple Silicon, AMD, and Intel GPUs
- Statistical analysis using Welch's t-test for reliable performance comparisons
- Dual testing pipeline for both graphics and compute workloads
- Predefined test configurations (Low, Moderate, Complex, High, Ultra-High)
- Command-line interface with multiple test modes
- Xcode integration with 20+ pre-configured schemes
- Automated baseline creation and regression detection
- Support for multiple GPU vendors and architectures
- Memory bandwidth, cache performance, and stage utilization metrics
- Confidence intervals and quality ratings for performance measurements
- JSON-based data storage for baselines and test results
- Comprehensive documentation and usage examples

### Features
- **Graphics Testing**: Triangle rendering with configurable complexity and resolution
- **Compute Testing**: Compute shader execution with configurable threadgroup sizes
- **Statistical Analysis**: Advanced statistical methods for performance comparison
- **Hardware Metrics**: Real GPU performance counters from Metal API
- **Regression Detection**: Automated detection of performance regressions
- **CI/CD Ready**: Designed for continuous integration workflows

### Technical Details
- **Supported Platforms**: macOS 15.0+
- **Supported GPUs**: Apple Silicon (M1/M2/M3/M4), AMD, Intel
- **Metal Version**: 2.0+
- **Swift Version**: 5.0+
- **Xcode Version**: 15.0+

### Documentation
- Comprehensive README with usage examples
- Detailed baseline output documentation
- Release guide for GitHub distribution
- Troubleshooting and installation instructions

---

## Release Types

- **Major** (X.0.0): Breaking changes or significant new features
- **Minor** (0.X.0): New features, backward compatible
- **Patch** (0.0.X): Bug fixes, backward compatible

## Version History

- [`v1.0.0`](https://github.com/yourusername/Metal-Performance-Tester/releases/tag/v1.0.0) - Initial stable release
- [`v1.0.0-beta.1`](https://github.com/yourusername/Metal-Performance-Tester/releases/tag/v1.0.0-beta.1) - Pre-release for testing
- [`v0.9.0`](https://github.com/yourusername/Metal-Performance-Tester/releases/tag/v0.9.0) - Development version
- [`v0.8.0`](https://github.com/yourusername/Metal-Performance-Tester/releases/tag/v0.8.0) - Early development

## Quick Navigation

- [Latest Release](https://github.com/yourusername/Metal-Performance-Tester/releases/latest)
- [All Releases](https://github.com/yourusername/Metal-Performance-Tester/releases)
- [Compare Versions](https://github.com/yourusername/Metal-Performance-Tester/compare)
