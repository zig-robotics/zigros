FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y wget xz-utils && apt-get clean
RUN wget -qO- https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar xJv
RUN wget -qO- https://github.com/zig-robotics/rclcpp_example/archive/refs/heads/main.tar.gz | tar xzv
RUN cd rclcpp_example-main; /zig-linux-x86_64-0.14.0/zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu --summary none  

FROM debian:bookworm-slim
COPY --from=0 /rclcpp_example-main/zig-out/bin/node /node
CMD ["/node"]
