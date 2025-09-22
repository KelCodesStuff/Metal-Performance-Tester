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

**Available Schemes:**
- `Baseline-Low-Res` / `Test-Low-Res` - 720p mobile testing
- `Baseline-Moderate` / `Test-Moderate` - 1080p daily development
- `Baseline-Complex` / `Test-Complex` - 1440p feature development
- `Baseline-High-Res` / `Test-High-Res` - 4K display scaling
- `Baseline-Ultra-High-Res` / `Test-Ultra-High-Res` - 8K extreme testing

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

#### Available Test Configurations

```bash
# Test with specific resolution presets
Metal-Performance-Tracker --run-test --low-res          # 720p, mobile testing
Metal-Performance-Tracker --run-test --moderate         # 1080p, daily development  
Metal-Performance-Tracker --run-test --complex          # 1440p, feature development
Metal-Performance-Tracker --run-test --high-res         # 4K, display scaling
Metal-Performance-Tracker --run-test --ultra-high-res   # 8K, ultra-high resolution
```

#### Command Line Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--help` | Show help information | `--help` |
| `--run-test` | Run performance test against baseline | `--run-test` |
| `--update-baseline` | Create/update performance baseline | `--update-baseline` |
| `--low-res` | 720p mobile testing preset | `--low-res` |
| `--moderate` | 1080p daily development preset | `--moderate` |
| `--complex` | 1440p feature development preset | `--complex` |
| `--high-res` | 4K display scaling preset | `--high-res` |
| `--ultra-high-res` | 8K ultra-high resolution preset | `--ultra-high-res` |

For detailed information about baseline output and interpretation, see the [Baseline Output guide](https://github.com/KelCodesStuff/Metal-Performance-Tracker/wiki/Baseline-Output).

## Building

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

## Test Configurations

The tool includes pre-defined test configurations optimized for different use cases:

| Configuration | Resolution | Triangles | Complexity | Use Case |
|---------------|------------|-----------|------------|----------|
| **Low Resolution** | 1280×720 | 10 | 1/10 | Mobile testing, quick validation |
| **Moderate** | 1920×1080 | 100 | 5/10 | Daily development, CI/CD |
| **Complex** | 2560×1440 | 1,000 | 8/10 | Feature development, stress testing |
| **High Resolution** | 3840×2160 | 2,000 | 8/10 | 4K testing, display scaling |
| **Ultra High Resolution** | 7680×4320 | 4,000 | 10/10 | 8K testing, extreme workloads |

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

### Common Issues

**"Counter sampling not supported"**
- Your GPU doesn't support Metal's performance counter sampling API
- Try on a different machine with a supported GPU (Apple Silicon, modern discrete GPUs)

**"Missing baseline"**
- Run `Metal-Performance-Tracker --update-baseline` first
- Ensure the `Data/` directory is writable

**"Performance varies between runs"**
- This is normal behavior - the tool handles variance through statistical analysis
- Consider thermal throttling, background processes, and system load

**"High-resolution tests fail or crash"**
- Try lower resolution presets (`--moderate` instead of `--high-res`)
- Ensure adequate system memory (16GB+ recommended)
- Use external GPU if testing on MacBook with integrated graphics

## License

This project is licensed under the MIT License - see the LICENSE file for details.