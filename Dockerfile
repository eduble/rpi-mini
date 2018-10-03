# builder image: generate a base debian directory
# ----------------------------------------------
FROM debian:stretch as builder
RUN apt-get update && apt-get install -y debootstrap && apt-get clean
WORKDIR /root
RUN debootstrap --foreign --no-check-gpg --variant minbase --arch armhf \
                stretch fs http://mirrordirector.raspbian.org/raspbian

# layered image: build on this base debian directory
# --------------------------------------------------
FROM scratch as layered
WORKDIR /
# Copy the subdirectory generated from debootstrap first stage
COPY --from=builder /root/fs .
# We want ARM CPU emulation to work, even if we are running all this
# on the docker hub (automated build) and binfmt_misc is not available.
# So we get the modified qemu built by guys from resin.io.
# This modified qemu is able to catch subprocesses creation and handle
# their CPU emulation, when called with option '-execve'.
# (https://resin.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/)
COPY --from=resin/armv7hf-debian-qemu /usr/bin/qemu-arm-static /usr/bin/
# let docker build process call qemu-arm-static
SHELL ["/usr/bin/qemu-arm-static", "-execve", "/bin/sh", "-c"]
# second stage of debootstrap will try to mount things already mounted,
# do not fail
RUN ln -sf /bin/true /bin/mount
# call second stage of debootstrap
RUN /debootstrap/debootstrap --second-stage
RUN apt-get clean
# update package repositories
ADD sources.list /etc/apt/sources.list
ADD raspi.list /etc/apt/sources.list.d/
# register Raspberry Pi Archive Signing Key
ADD 82B129927FA3303E.pub /tmp/
RUN apt-key add /tmp/82B129927FA3303E.pub
RUN rm /tmp/82B129927FA3303E.pub

# squashed image: compress layered image
# --------------------------------------
# We will squash layers into a clean image.
# First stage of debootstrap have create many files that were actually
# removed by the second stage, so out final image can be made at least twice
# smaller than previous one ("layered").
FROM scratch
COPY --from=layered / /
CMD ["/bin/bash"]
