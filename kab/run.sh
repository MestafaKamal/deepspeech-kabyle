#!/bin/sh
# created by Mestafa Kamal

set -xe

export PATH=$(dirname "$0"):$PATH

env

${MODEL_LANGUAGE}/pre_processing/a2_import_data_kab.sh

${MODEL_LANGUAGE}/a3_language_model.sh

${MODEL_LANGUAGE}/train.sh