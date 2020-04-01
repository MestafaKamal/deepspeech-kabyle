FROM nvidia/cuda:10.0-cudnn7-runtime-ubuntu18.04

ARG ds_repo=MestafaKamal/DeepSpeech
ARG kenlm_repo=kpu/kenlm
ARG kenlm_branch=2ad7cb56924cd3c6811c604973f592cb5ef604eb

ARG model_language=kab

ARG batch_size=96
ARG n_hidden=2048
ARG epochs=75
ARG learning_rate=0.001
ARG dropout=0.05
ARG lm_alpha=0.65
ARG lm_beta=1.45
ARG beam_width=500
ARG early_stop=1

ARG english_compatible=0

# Make sure we can extract filenames with UTF-8 chars
ENV LANG=C.UTF-8

# Avoid keyboard-configuration step
ENV DEBIAN_FRONTEND noninteractive

ENV HOMEDIR /home/trainer
ENV DATADIR /mnt

ENV VIRTUAL_ENV_NAME ds-train
ENV VIRTUAL_ENV $HOMEDIR/$VIRTUAL_ENV_NAME
ENV DS_DIR $HOMEDIR/ds

ENV DS_BRANCH=$ds_branch
ENV DS_SHA1=$ds_sha1

ENV MODEL_LANGUAGE=$model_language

ENV BATCH_SIZE=$batch_size
ENV N_HIDDEN=$n_hidden
ENV EPOCHS=$epochs
ENV LEARNING_RATE=$learning_rate
ENV DROPOUT=$dropout
ENV LM_ALPHA=$lm_alpha
ENV LM_BETA=$lm_beta
ENV BEAM_WIDTH=$beam_width

ENV ENGLISH_COMPATIBLE=$english_compatible

ENV EARLY_STOP=$early_stop

ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN env

# Get basic packages
RUN apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    ca-certificates \
    cmake \
    libboost-all-dev \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    pkg-config \
    g++ \
    virtualenv \
    unzip \
    pixz \
    sox \
    sudo \
    libsox-fmt-all \
    locales locales-all \
    xz-utils

RUN groupadd -g 999 trainer && \
    adduser --system --uid 999 --group trainer

RUN echo "trainer ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/trainer && \
    chmod 0440 /etc/sudoers.d/trainer

# Below that point, nothing requires being root
USER trainer

WORKDIR $HOMEDIR

RUN wget -O - https://bitbucket.org/eigen/eigen/get/3.2.8.tar.bz2 | tar xj

RUN git clone https://github.com/$kenlm_repo.git && cd kenlm && git checkout $kenlm_branch \
    && mkdir -p build \
    && cd build \
    && EIGEN3_ROOT=$HOMEDIR/eigen-eigen-07105f7124f9 cmake .. \
    && make -j

WORKDIR $HOMEDIR

RUN virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV_NAME

RUN git clone https://github.com/$ds_repo.git $DS_DIR

WORKDIR $DS_DIR

RUN cat requirements.txt | sed -e 's/^tensorflow/tensorflow-gpu/g' | pip install -r /dev/stdin

RUN pip install `python util/taskcluster.py --decoder`

RUN python3 util/taskcluster.py --target native_client/

WORKDIR $HOMEDIR

ENV PATH="$HOMEDIR/kenlm/build/bin/:$PATH"

# Copy now so that docker build can leverage caches
COPY --chown=trainer:trainer run.sh counter.py $HOMEDIR/


COPY --chown=trainer:trainer ${MODEL_LANGUAGE}/*.sh $HOMEDIR/${MODEL_LANGUAGE}/

COPY --chown=trainer:trainer ${MODEL_LANGUAGE}/Python/*.py $HOMEDIR/${MODEL_LANGUAGE}/Python/

COPY --chown=trainer:trainer ${MODEL_LANGUAGE}/data_kab/alphabet.txt $HOMEDIR/${MODEL_LANGUAGE}/data_kab/

ENTRYPOINT "$HOMEDIR/run.sh"