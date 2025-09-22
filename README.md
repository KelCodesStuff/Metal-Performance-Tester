# Metal Performance Tracker

A comprehensive tool for tracking GPU performance regressions in Metal applications. This tool provides precise GPU performance measurement, statistical analysis, and automated regression detection for Metal-based applications.

## Features

### Core Performance Measurement
- **Precise GPU Timing**: Uses Metal's performance counter sampling API for accurate GPU execution time measurement
- **Advanced Metrics**: Captures stage utilization, memory bandwidth, cache statistics, and instruction counts
- **Workload-Aware Analysis**: Intelligent scaling based on triangle count, resolution, and geometry complexity
- **Multiple Test Configurations**: Pre-defined presets from mobile (720p) to ultra-high resolution (8K) testing

### Statistical Analysis & Regression Detection
- **Robust Statistical Analysis**: Implements Welch's t-test for unequal variances with confidence intervals
- **Quality Assessment**: Automatic quality rating based on coefficient of variation
- **Significance Testing**: Configurable significance levels with proper statistical validation
- **Dual Detection Methods**: Both statistical significance testing and threshold-based regression detection

### Professional Tooling
- **Comprehensive CLI**: Rich command-line interface with multiple test modes and configuration options
- **Baseline Management**: Sophisticated baseline creation, storage, and comparison
- **Detailed Reporting**: Professional-grade reports with statistical analysis and performance insights
- **Configuration Validation**: Built-in validation for test parameters and GPU compatibility

### Advanced Analytics
- **Stage Utilization Metrics**: Vertex, fragment, geometry, and compute shader utilization tracking
- **Memory Performance**: Bandwidth utilization, cache hit rates, and memory latency analysis
- **Performance Impact Assessment**: Automatic categorization of test complexity and GPU impact
- **Trend Analysis**: Historical performance tracking and regression pattern detection


## Usage

The Metal Performance Tracker provides both Xcode and command-line interfaces for different workflows.

### Xcode Interface (Recommended)

The easiest way to use the tool is through Xcode's scheme selector:

1. **Open Project**: Open `Metal-Performance-Tracker.xcodeproj` in Xcode
2. **Select Device**: Choose your target device (My Mac)
3. **Run Baseline**: Select a baseline scheme (e.g., `Baseline-Ultra-High-Res`) and run it to establish performance baseline
4. **Run Test**: Select the corresponding test scheme (e.g., `Test-Ultra-High-Res`) and run it to see analysis results
5. **View Results**: Compare the baseline and test results in the console output

### Command Line Interface

For CI/CD workflows, use the command-line interface:

```bash
# Show help and usage information
Metal-Performance-Tracker --help

# Update performance baseline (ultra-high-res configuration)
Metal-Performance-Tracker --update-baseline --ultra-high-res

# Run performance test against the baseline (ultra-high-res configuration)
Metal-Performance-Tracker --run-test --ultra-high-res
```

For detailed information about baseline output and interpretation, see the [Baseline Output guide](https://github.com/KelCodesStuff/Metal-Performance-Tracker/wiki/Baseline-Output).

## Requirements

### System Requirements
- **macOS**: 10.15 (Catalina) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Metal**: 2.0 or later
- **Metal-compatible GPU**: Required for performance counter sampling

## Performance Measurement

### Performance Metrics

The tool captures comprehensive GPU performance data:

- **Timing Metrics**: GPU execution time, frame time, draw call timing
- **Stage Utilization**: Vertex, fragment, geometry, compute shader utilization percentages
- **Memory Performance**: Bandwidth utilization, cache hit/miss rates, memory latency
- **Instruction Counts**: Total instructions executed, instruction efficiency
- **Quality Ratings**: Automatic assessment of measurement reliability and consistency

## Advanced Features

### Statistical Analysis Engine

The tool includes a sophisticated statistical analysis engine that provides:

- **Welch's t-test**: Proper statistical significance testing for unequal variances
- **Confidence Intervals**: 95% confidence intervals for performance differences
- **Quality Assessment**: Automatic quality rating based on coefficient of variation
- **Multiple Iterations**: Automatic handling of multiple test runs for statistical power
- **Significance Levels**: Configurable significance levels for different use cases

For more information see the [Performance Impact Categories guide](https://github.com/KelCodesStuff/Metal-Performance-Tracker/wiki/Performance-Impact-Categories).

## Supported GPUs

### Fully Supported
- **Apple Silicon**: M1, M2, M3, M4 series (all variants)
- **Apple Discrete GPUs**: Radeon Pro 5000/6000/7000 series (in Mac Pro, iMac Pro, and some MacBook Pro models)
- **Recent Integrated GPUs**: Intel Iris Xe (Intel-based Macs), Apple integrated graphics

### Limited Support
- **Older Discrete GPUs**: Performance may vary
- **Legacy Integrated GPUs**: May not support all counter types

### Not Supported
- **Pre-Metal GPUs**: GPUs without Metal support
- **GPUs without Counter Sampling**: Older integrated graphics without performance counter support

## Troubleshooting
For troubleshooting see the [Troubleshooting guide](https://github.com/KelCodesStuff/Metal-Performance-Tracker/wiki/Troubleshooting).


## License

This project is licensed under the MIT License.
