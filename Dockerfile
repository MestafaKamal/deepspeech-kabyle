FROM nvidia/cuda:10.0-cudnn7-runtime-ubuntu18.04

ARG ds_repo=mozilla/DeepSpeech
ARG ds_branch=f56b07dab4542eecfb72e059079db6c2603cc0ee
ARG ds_sha1=f56b07dab4542eecfb72e059079db6c2603cc0ee
ARG cc_repo=MestafaKamal/CorporaCreator
ARG cc_sha1=73622cf8399f8e634aee2f0e76dacc879226e3ac
ARG kenlm_repo=kpu/kenlm
ARG kenlm_branch=87e85e66c99ceff1fab2500a7c60c01da7315eec

# Model parameters
ARG model_language=kab
ENV MODEL_LANGUAGE=$model_language

# Training hyper-parameters
ARG batch_size=64
ENV BATCH_SIZE=$batch_size

ARG n_hidden=2048
ENV N_HIDDEN=$n_hidden

ARG epochs=30
ENV EPOCHS=$epochs

ARG learning_rate=0.0001
ENV LEARNING_RATE=$learning_rate

ARG dropout=0.3
ENV DROPOUT=$dropout

ARG lm_top_k=500000
ENV LM_TOP_K=500000

ARG lm_alpha=0.0
ENV LM_ALPHA=$lm_alpha

ARG lm_beta=0.0
ENV LM_BETA=$lm_beta

ARG beam_width=500
ENV BEAM_WIDTH=$beam_width

ARG early_stop=1
ENV EARLY_STOP=$early_stop

ARG amp=0
ENV AMP=$amp

# Dataset management
ARG duplicate_sentence_count=1
ENV DUPLICATE_SENTENCE_COUNT=$duplicate_sentence_count

# Should be of the form: lm_alpha_max,lm_beta_max,n_trials
ARG lm_evaluate_range=
ENV LM_EVALUATE_RANGE=$lm_evaluate_range

# Others
ARG english_compatible=0
ENV ENGLISH_COMPATIBLE=$english_compatible

ARG uid=999
ENV UID=$uid

ARG gid=999
ENV GID=$gid

# Make sure we can extract filenames with UTF-8 chars
ENV LANG=C.UTF-8

# Avoid keyboard-configuration step
ENV DEBIAN_FRONTEND noninteractive

ENV HOMEDIR /home/trainer

ENV VIRTUAL_ENV_NAME ds-train
ENV VIRTUAL_ENV $HOMEDIR/$VIRTUAL_ENV_NAME
ENV DS_DIR $HOMEDIR/ds
ENV CC_DIR $HOMEDIR/cc

ENV DS_BRANCH=$ds_branch
ENV DS_SHA1=$ds_sha1

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

RUN groupadd -g $GID trainer && \
    adduser --system --uid $UID --group trainer

RUN echo "trainer ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/trainer && \
    chmod 0440 /etc/sudoers.d/trainer

# Below that point, nothing requires being root
USER trainer

WORKDIR $HOMEDIR

RUN wget -O - https://gitlab.com/libeigen/eigen/-/archive/3.2.8/eigen-3.2.8.tar.bz2 | tar xj


RUN git clone https://github.com/$kenlm_repo.git && cd kenlm && git checkout $kenlm_branch \
    && mkdir -p build \
    && cd build \
    && EIGEN3_ROOT=$HOMEDIR/eigen-eigen-07105f7124f9 cmake .. \
    && make -j

WORKDIR $HOMEDIR

RUN virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV_NAME

ENV PATH=$HOMEDIR/$VIRTUAL_ENV_NAME/bin:$PATH

RUN git clone https://github.com/$ds_repo.git $DS_DIR

WORKDIR $DS_DIR

RUN git checkout $ds_branch

WORKDIR $DS_DIR

RUN pip install --upgrade pip==20.0.2 wheel==0.34.2 setuptools==46.1.3
RUN DS_NOTENSORFLOW=y pip install --upgrade --force-reinstall -e .
RUN pip install --upgrade tensorflow-gpu==1.15.2

RUN TASKCLUSTER_SCHEME="https://community-tc.services.mozilla.com/api/index/v1/task/project.deepspeech.tensorflow.pip.%(branch_name)s.%(arch_string)s/artifacts/public/%(artifact_name)s" python util/taskcluster.py \
	--target="$(pwd)" \
	--artifact="convert_graphdef_memmapped_format" \
	--branch="r1.15" && chmod +x convert_graphdef_memmapped_format

RUN python util/taskcluster.py \
	--target="$(pwd)" \
	--artifact="native_client.tar.xz" && ls -hal generate_scorer_package 

WORKDIR $HOMEDIR

RUN git clone https://github.com/$cc_repo.git $CC_DIR

WORKDIR $CC_DIR

WORKDIR $CC_DIR

# Copy copora patch
COPY --chown=trainer:trainer corpora.patch $CC_DIR

RUN patch -p1 < corpora.patch

# Avoid "error: pandas 1.1.0 is installed but pandas==1.0.5 is required by {'modin'}"
RUN pip install pandas==1.1.2

# error: parso 0.8.0 is installed but parso<0.8.0,>=0.7.0 is required by {'jedi'}
RUN pip install parso==0.7.0

RUN python setup.py install

WORKDIR $HOMEDIR

ENV PATH="$HOMEDIR/kenlm/build/bin/:$PATH"

# Copy now so that docker build can leverage caches
COPY --chown=trainer:trainer run.sh checks.sh corpora.patch package.sh $HOMEDIR/

COPY --chown=trainer:trainer ${MODEL_LANGUAGE}/* $HOMEDIR/${MODEL_LANGUAGE}/

COPY --chown=trainer:trainer ${MODEL_LANGUAGE}/data_kab/* $HOMEDIR/${MODEL_LANGUAGE}/data_kab/

ENTRYPOINT "$HOMEDIR/run.sh"
