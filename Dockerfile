FROM condaforge/mambaforge:latest AS conda

COPY ./robust-planning-project/environment.yml ./environment.yml
RUN mamba env create -p /env --file environment.yml && conda clean -afy


# CMD conda activate msc-thesis

FROM gcc AS base 
COPY --from=conda /env /env
RUN apt-get update; apt-get install -y \
    gdb \
    libclang-dev \
    doxygen \
    graphviz \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/env:/env/bin:${PATH}"

ENV JULIA_DEPOT_PATH="/env/julia/.julia:${JULIA_DEPOT_PATH}"

# Need to use the /releasepreview version to get access to the -p flag of the juliaup installer
RUN curl -fsSL https://install.julialang.org/releasepreview | sh -s -- \
    --default-channel 1.8 --path /env/julia --background-selfupdate=0 --startup-selfupdate=0 --add-to-path=false --yes

# Explicitly add the julia binary to the path rather than relying on the installer to do it
# so that apptainer can correctly initialize the PATH environment variable
ENV PATH="/env/julia/bin:${PATH}"

FROM base AS build-cTORS
WORKDIR /cTORS
COPY ./robust-planning-project/cTORS /cTORS
RUN mkdir build && python setup.py install
