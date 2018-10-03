FROM debian:stretch as builder
RUN apt-get update && apt-get install -y qemu-user-static debootstrap && apt-get clean
WORKDIR /root
RUN debootstrap --foreign --no-check-gpg --variant minbase --arch armhf stretch fs http://mirrordirector.raspbian.org/raspbian
RUN cp /usr/bin/qemu-arm-static fs/usr/bin

FROM scratch as layered
WORKDIR /
COPY --from=builder /root/fs .
RUN ln -sf /bin/true /bin/mount && \
    /debootstrap/debootstrap --second-stage && \
    apt-get clean
ADD sources.list /etc/apt/sources.list
ADD raspi.list /etc/apt/sources.list.d/
# register Raspberry Pi Archive Signing Key
ADD 82B129927FA3303E.pub /tmp/
RUN apt-key add - < /tmp/82B129927FA3303E.pub && rm /tmp/82B129927FA3303E.pub

# Squash layers into a clean image.
# First stage of debootstrap have create many files that were actually
# removed by the second stage, so out final image can be made at least twice
# smaller than previous one ("layered").
FROM scratch
COPY --from=layered / /
CMD ["/bin/bash"]
