# Metal Performance Tracker

A tool for tracking GPU performance regressions in Metal applications. This tool measures GPU counters and compares it against baselines to detect regressions.

## Features

- **Precise GPU Timing**: Uses Metal's performance counter sampling for accurate GPU execution time measurement
- **Baseline Management**: Save and compare performance against established baselines
- **Regression Detection**: Configurable thresholds for detecting performance regressions
- **Cross-Platform**: Works on macOS with Metal-compatible GPUs


## Usage

### Command Line Options

```bash
# Run performance test with default 5% threshold
Metal-Perform-Tracker --run-test

# Run performance test with custom threshold
Metal-Perform-Tracker --run-test --threshold 10.0

# Update performance baseline
Metal-Perform-Tracker --update-baseline

# Show help
Metal-Perform-Tracker --help
```

### Exit Codes

- `0`: Test passed (performance within threshold)
- `1`: Test failed (performance regression detected)
- `2`: Error (missing baseline, unsupported GPU, etc.)

## Building

### Xcode
1. Open `Metal-Perform-Tracker.xcodeproj`
2. Select your target device
3. Build and run (⌘+R)

### Command Line
```bash
xcodebuild -project Metal-Perform-Tracker.xcodeproj -scheme Metal-Perform-Tracker -configuration Debug build
```

## Performance Measurement

The tool measures GPU performance by:
1. **Counter Sampling**: Uses Metal's performance counter sampling API
2. **Timestamp Measurement**: Captures GPU timestamps at draw start/end
3. **Precise Timing**: Converts GPU clock cycles to milliseconds
4. **Regression Detection**: Compares against baseline with configurable thresholds

## Use Cases

- **CI/CD Integration**: Automated performance regression testing
- **Development Workflow**: Catch performance regressions during development
- **Hardware Testing**: Compare performance across different GPUs
- **Optimization Validation**: Verify performance improvements

## Requirements

- **macOS**: 10.15 or later
- **GPU**: Metal-compatible GPU with counter sampling support
- **Xcode**: 12.0 or later (for building)

## Supported GPUs

The tool works with GPUs that support Metal's performance counter sampling:
- Apple Silicon (M1, M2, M3)
- Modern discrete GPUs (NVIDIA RTX, AMD RX series)
- Some integrated GPUs (varies by model)

## Troubleshooting

### "Counter sampling not supported"
- Your GPU doesn't support Metal's performance counter sampling
- Try on a different machine with a supported GPU
- This is common with older integrated GPUs

### "Missing baseline"
- Run with `--update-baseline` first to establish a baseline
- Ensure the Data directory is writable

### Performance varies between runs
- GPU performance can vary due to thermal throttling, background processes, etc.
- Consider running multiple tests and averaging results
- Use appropriate thresholds for your use case

## License

This project is licensed under the MIT License - see the LICENSE file for details.