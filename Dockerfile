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

RUN curl -fsSL https://install.julialang.org | sh -s -- -y