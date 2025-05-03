# Start from a base image (Ubuntu + Miniconda)
FROM continuumio/miniconda3:latest

# Install system dependencies including AWS CLI v2
RUN apt-get update && apt-get install -y \
    wget \
    bzip2 \
    zlib1g-dev \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (required for Nextflow AWS Batch)
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws && \
    aws --version

# Set up conda channels
RUN conda config --add channels defaults && \
    conda config --add channels bioconda && \
    conda config --add channels conda-forge && \
    conda config --set channel_priority strict

# Install bioinformatics packages
RUN conda install -y \
    fastqc \
    trimmomatic \
    bwa \
    samtools \
    bcftools \
    && conda clean -afy

