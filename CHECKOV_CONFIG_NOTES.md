# Checkov Configuration Notes

## Issue Fixed
The original `.checkov.yaml` file contained several configuration keys that were not properly supported by the Checkov version used in GitHub Actions, causing argument parsing errors.

## Error Encountered
```
checkov: error: unrecognized arguments: --severity=HIGH --severity=MEDIUM --severity=LOW --exclude=.git/** --exclude=rendered-templates/** --exclude=packaged-charts/** --suppress={'id': 'CKV_K8S_*', 'file_path': 'templates/tests/**', 'comment': 'Test resources have relaxed security requirements'} --suppress={'id': 'CKV_K8S_15', 'file_path': 'values-nonprod.yaml', 'comment': 'Development environments may use different image pull policies'} --enable-experimental-checks=True
```

## Solution
Simplified the `.checkov.yaml` configuration to use only well-supported keys:

### Removed (problematic keys):
- `severity:` - Not supported in config file format
- `output:` - Should be specified via command line
- `check:` - Conflicts with `skip-check`
- `directory:` - Should be specified via command line
- `exclude:` - Complex patterns cause parsing issues
- `suppress:` - Complex object syntax not supported
- `enable-experimental-checks:` - Boolean parsing issues
- `download-external-modules:` - Not needed for basic scanning

### Kept (working keys):
- `framework:` - Specifies scan frameworks
- `skip-check:` - Skip specific security checks
- `compact:` - Output format control
- `quiet:` - Verbosity control

## Result
- ✅ Checkov now runs without argument parsing errors
- ✅ Essential security checks are still configured
- ✅ Kafka/Strimzi-specific exceptions are preserved
- ✅ CI/CD pipeline functions properly
