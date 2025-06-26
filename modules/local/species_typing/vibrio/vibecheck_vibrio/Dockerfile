FROM docker.io/watronfire/vibecheck:2025.02.24

# Install ps tool (procps package)
# This works for most Debian/Ubuntu based images
# Quick build using wave-cli: wave -f ./Dockerfile
RUN micromamba install -y -n base conda-forge::procps-ng
