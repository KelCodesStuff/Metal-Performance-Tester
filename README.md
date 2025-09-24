# Metal Performance Tester

A comprehensive tool for testing GPU performance regressions in Metal applications. This tool provides precise GPU performance measurement, statistical analysis, and automated regression detection for Metal-based applications.

## Features

### Core Performance Measurement
- **Precise GPU Timing:** Uses Metal's performance counter sampling API for accurate measurement of GPU execution time, frame time, and draw call timing.
- **Advanced Hardware Counters:** Captures key metrics including stage utilization (vertex, fragment, geometry, compute), memory bandwidth, cache hit/miss rates, memory latency, and total instructions executed.
- **Workload-Aware Analysis:** Intelligently scales and assesses performance impact based on triangle count, resolution, and geometry complexity.
- **Multiple Test Configurations:** Provides pre-defined presets for a range of scenarios, from mobile (720p) to ultra-high resolution (8K) testing.

> For informationon on the [Metal](https://developer.apple.com/documentation/metal) API see the official documentation.

### Statistical Analysis & Regression Detection
- **Robust Statistical Analysis:** Implements [Welch's t-test](https://en.wikipedia.org/wiki/Welch%27s_t-test) for proper statistical analysis of samples with unequal variances, with configurable significance levels.
- **Confidence Intervals:** Calculates 95% confidence intervals for performance differences to quantify the margin of error.
- **Data Quality Assessment:** Automatically rates the quality and reliability of a test run based on its coefficient of variation.
- **Dual Detection Methods:** Supports both statistical significance testing and simple threshold-based regression detection.

### Professional Tooling
- **Comprehensive CLI:** A rich command-line interface with multiple test modes and configuration options, designed for CI/CD integration.
- **Baseline Management:** Advanced baseline creation, storage, and comparison against new test runs.
- **Detailed Reporting:** Generates in-depth reports with statistical summaries and actionable performance insights.
- **Configuration Validation:** Performs built-in validation for test parameters and GPU compatibility to prevent erroneous test runs.

## Upcoming Features

### Dynamic Workload Scaling
- **Automatic GPU Detection:** Intelligently detects M Series GPU performance tiers (M1/M2/M3/M4 base, Pro, Max, Ultra) and adjusts test complexity accordingly.
- **Adaptive Test Configuration:** Automatically scales triangle count, geometry complexity, and resolution based on detected GPU capabilities.
- **Cross-Platform Compatibility:** Ensures meaningful performance measurements across different M Series variants without manual configuration.
- **Smart Workload Optimization:** Prevents trivial workloads on powerful GPUs and overly complex workloads on lower-end GPUs.

**Why This Feature is Needed:**
Currently, the tool uses fixed test configurations that may not be optimal for all GPU performance levels. A test configuration that works well for an M1 base might be too trivial for an M4 Ultra, while a configuration suitable for M4 Ultra might be too demanding for an M1 base. Dynamic Workload Scaling solves this by automatically detecting the GPU's performance tier and generating test configurations that provide meaningful, comparable results across the entire M Series lineup.

## Usage

The Metal Performance Tester provides both Xcode and command-line interfaces for different workflows.

### Xcode Interface (Recommended)

The easiest way to use the tool is through Xcode's scheme selector:

1. **Open Project:** Open `Metal-Performance-Tester.xcodeproj` in Xcode
2. **Select Device:** Choose your target device (My Mac)
3. **Run Baseline:** Select a baseline scheme (e.g., `Baseline-Ultra-High-Res`) and run it to establish performance baseline
4. **Run Test:** Select the corresponding test scheme (e.g., `Test-Ultra-High-Res`) and run it to see analysis results
5. **View Results:** Compare the baseline and test results in the console output

### Command Line Interface

For CI/CD workflows, use the command-line interface:

```bash
# Show help and usage information
Metal-Performance-Tester --help

# Update performance baseline (ultra-high-res configuration)
Metal-Performance-Tester --update-baseline --ultra-high-res

# Run performance test against the baseline (ultra-high-res configuration)
Metal-Performance-Tester --run-test --ultra-high-res
```

> For detailed information about baseline output and interpretation, see the [Baseline Output guide](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Baseline-Output).

## Requirements

### System Requirements
- **macOS:** 15.0 or later
- **Xcode:** 15.0 or later
- **Swift:** 5.0 or later
- **Metal:** 2.0 or later
- **Metal-compatible GPU:** Required for performance counter sampling

## Supported GPUs

### Fully Supported
- **Apple Silicon:** M1, M2, M3, M4 series (all variants)

### Not Supported
- **Apple Discrete GPUs:** Radeon Pro 5000/6000/7000 series (in Mac Pro, iMac Pro, and some MacBook Pro models)
- **Recent Integrated GPUs:** Intel Iris Xe (Intel-based Macs), Apple integrated graphics
- **Pre-Metal GPUs:** GPUs without Metal support
- **GPUs without Counter Sampling:** Older integrated graphics without performance counter support

## Troubleshooting
For troubleshooting see the [Troubleshooting guide](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Troubleshooting).


## License

This project is licensed under the MIT License.
