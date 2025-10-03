# Docker examples

These dockerfiles are provided as examples to demonstrate and test the zero external dependency goal of ZigROS.
Do not use them for development.

These examples build the [ZigROS example project which brings in ZigROS as a dependency.](../example_node)

To build, run:
```
docker build -t test-zig -f ./alpine.Dockerfile ../../
```
or
```
docker build -t test-zig -f ./debian.Dockerfile ../../
```

The alpine dockerfile demonstrates fully static compilation, the debian dockerfile demonstrates static builds but still using glibc.
