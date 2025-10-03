FROM alpine

RUN wget -qO- https://ziglang.org/download/0.15.1/zig-x86_64-linux-0.15.1.tar.xz | tar xJv
COPY ./ /zigros
RUN cd zigros/examples/example_node; /zig-x86_64-linux-0.15.1/zig build -Doptimize=ReleaseFast -Dtarget=native-native-musl --summary none  

FROM scratch
COPY --from=0 /zigros/examples/example_node/zig-out/bin/node /node
CMD ["/node"]
