ARG ENVIRONMENT_DIRECTORY=/env
ARG JULIA_VERSION=1.8
ARG JULIAUP_INSTALL_PATH=${ENVIRONMENT_DIRECTORY}/juliaup
ARG JULIA_DEPOT_PATH=${JULIAUP_INSTALL_PATH}/.julia

FROM condaforge/mambaforge:latest AS conda
ARG ENVIRONMENT_DIRECTORY

COPY ./robust-planning-project/environment.yml ./environment.yml
RUN mamba env create -p ${ENVIRONMENT_DIRECTORY} --file environment.yml && conda clean -afy


FROM gcc AS with_cpp_compilation_tools
ARG ENVIRONMENT_DIRECTORY
COPY --from=conda ${ENVIRONMENT_DIRECTORY} ${ENVIRONMENT_DIRECTORY}
RUN apt-get update; apt-get install -y \
    gdb \
    libclang-dev \
    doxygen \
    graphviz \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="${ENVIRONMENT_DIRECTORY}:${ENVIRONMENT_DIRECTORY}/bin:${PATH}"

FROM gcc AS with_julia
ARG ENVIRONMENT_DIRECTORY
ARG JULIA_VERSION
ARG JULIAUP_INSTALL_PATH
ARG JULIA_DEPOT_PATH
ENV JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH}

COPY ./robust-planning-project/Project.toml ./Project.toml
COPY ./robust-planning-project/Manifest.toml ./Manifest.toml

# Need to use the /releasepreview version to get access to the -p flag of the juliaup installer
RUN curl -fsSL https://install.julialang.org/releasepreview | sh -s -- \
    --default-channel ${JULIA_VERSION} \
    --path ${JULIAUP_INSTALL_PATH} \
    --background-selfupdate=0 \
    --startup-selfupdate=0 \
    --add-to-path=false --yes \
    && ${JULIAUP_INSTALL_PATH}/bin/julia --project=. -e"using Pkg; Pkg.instantiate(); Pkg.precompile();"

FROM with_cpp_compilation_tools AS build-cTORS
WORKDIR /cTORS
COPY ./robust-planning-project/cTORS /cTORS
RUN mkdir build && python setup.py build

FROM with_cpp_compilation_tools AS final
ARG JULIAUP_INSTALL_PATH
ARG JULIA_DEPOT_PATH
WORKDIR /cTORS
COPY --from=build-cTORS /cTORS /cTORS
RUN python setup.py install

COPY --from=with_julia ${JULIAUP_INSTALL_PATH} ${JULIAUP_INSTALL_PATH}
ENV JULIA_DEPOT_PATH=${JULIA_DEPOT_PATH}

# Explicitly add the julia binary to the path rather than relying on the installer to do it
# so that apptainer can correctly initialize the PATH environment variable
ENV PATH="${JULIAUP_INSTALL_PATH}/bin:${PATH}"
