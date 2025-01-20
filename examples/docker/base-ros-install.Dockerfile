FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y wget xz-utils && apt-get clean
RUN wget -qO- https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar xJv
RUN wget -qO- https://github.com/zig-robotics/zigros/archive/refs/heads/main.tar.gz | tar xzv
RUN cd zigros-main; /zig-linux-x86_64-0.13.0/zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu -Dlinkage=dynamic --summary none  
# Note that this method is not recommended as it builds zigros twice.
# If dynamic builds are going to be fully supported, zigros needs to offer the option to re export the ros installation
RUN wget -qO- https://github.com/zig-robotics/rclcpp_example/archive/refs/heads/main.tar.gz | tar xzv
RUN cd rclcpp_example-main; /zig-linux-x86_64-0.13.0/zig build -Doptimize=ReleaseFast -Dlinkage=dynamic -Dtarget=x86_64-linux-gnu --summary none  

FROM debian:bookworm-slim
COPY --from=0 /zigros-main/zig-out /ros
COPY --from=0 /rclcpp_example-main/zig-out /ros

CMD ["sh", "-c", "LD_LIBRARY_PATH=/ros/lib /ros/bin/node"]
