# Metal Performance Tester  

Metal Performance Tester is a comprehensive tool for testing GPU performance regressions in Metal applications. 

This tool provides precise GPU performance measurement, statistical analysis, and automated regression detection for Metal-based applications.

[![Build and Test](https://github.com/KelCodesStuff/Metal-Performance-Tester/actions/workflows/macos.yml/badge.svg)](https://github.com/KelCodesStuff/Metal-Performance-Tester/actions/workflows/macos.yml)
![Platforms](https://img.shields.io/badge/Platform%20Compatibility-iOS%2016+%20|%20iPadOS%2016+-red?logo=apple&?color=red)

## Features

### Core Performance Measurement
- **Real GPU Performance Counters:** Uses actual Metal performance counter data from GPU hardware for authentic performance measurement.
- **Graphics & Compute Testing:** Separate testing pipelines for graphics rendering and compute workloads with dedicated baseline management.
- **Hardware-Based Metrics:** Captures real GPU metrics including stage utilization, memory bandwidth, cache performance, and instruction counts directly from GPU hardware.
- **Multiple Test Configurations:** Provides pre-defined presets for both graphics and compute scenarios, from low to max complexity testing.

> For information on the [Metal](https://developer.apple.com/documentation/metal) API see the official documentation.

### Statistical Analysis & Regression Detection
- **Robust Statistical Analysis:** Implements [Welch's t-test](https://en.wikipedia.org/wiki/Welch%27s_t-test) for proper statistical analysis of samples with unequal variances, with configurable significance levels.
- **Confidence Intervals:** Calculates 95% confidence intervals for performance differences to quantify the margin of error.
- **Simplified Output:** Clean, focused performance metrics without unnecessary complexity for easier analysis.
- **Dual Detection Methods:** Supports both statistical significance testing and simple threshold-based regression detection.

## Upcoming Features

For the list of upcoming features see [Upcoming Features](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Upcoming-Features).

## Use Cases

For detailed examples of how to use the Metal Performance Tester in practical development scenarios, see [Use Cases](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Use-Cases). 

This document includes uses for:

- **Game Development** - Adding visual effects and performance validation
- **Graphics Programming** - Shader optimization and pipeline analysis  
- **QA Engineering** - Release validation and automated testing


## Installation and Usage

The Metal Performance Tester provides both Xcode and command-line interfaces for different workflows.
> For information on installation and usage, see [Installation and Usage](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Installation-and-Usage).

> For information on graphics baselines, see [Graphics Baseline Output](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Graphics-Baseline-Output).

> For information on the compute baselines, see [Compute Baseline Output](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Compute-Baseline-Output).

## Requirements

### System Requirements
- **macOS:** 15.0 or later
- **Xcode:** 15.0 or later
- **Swift:** 5.0 or later
- **Metal:** 2.0 or later
- **Metal-compatible GPU:** Required for performance counter sampling

## Supported GPUs

### Fully Supported
- **Apple Silicon:** Native Metal performance and compute counter support

| Apple M1 | Apple M2 | Apple M3 | Apple M4 |
|----------|----------|----------|----------|
| Base     | Base     | Base     | Base     |
| Pro      | Pro      | Pro      | Pro      |
| Max      | Max      | Max      | Max      |
| Ultra    | Ultra    | Ultra    |          | 

### Not Supported
- **Apple Discrete GPUs:** Radeon Pro 5000/6000/7000 series (in Mac Pro, iMac Pro, and some MacBook Pro models)
- **Recent Integrated GPUs:** Intel Iris Xe (Intel-based Macs), Apple integrated graphics
- **Pre-Metal GPUs:** GPUs without Metal support
- **GPUs without Counter Sampling:** Older integrated graphics without performance counter support

## Troubleshooting
For troubleshooting see the [Troubleshooting guide](https://github.com/KelCodesStuff/Metal-Performance-Tester/wiki/Troubleshooting).

## License

This project is licensed under the MIT License.
