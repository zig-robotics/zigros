FROM alpine

RUN wget -qO- https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xJv
RUN wget -qO- https://github.com/zig-robotics/rclcpp_example/archive/refs/heads/main.tar.gz | tar xzv
RUN cd rclcpp_example-main; /zig-linux-x86_64-0.13.0/zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl --summary none  

FROM scratch
COPY --from=0 /rclcpp_example-main/zig-out/bin/node /node
CMD ["/node"]
