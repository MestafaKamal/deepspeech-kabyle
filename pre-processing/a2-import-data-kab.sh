#!/bin/sh
# created by Mestafa Kamal

# This script launches the tsv cleaing program and imports the vocal corpus

source tmp/deepspeech-kab-venv/bin/activate




# clean the TSVs
# Replace not alllowed letters
# Replace apostroph
# import_cv2 with alphabet filter


# alphabet.txt contains the allowed letters in the wavs' transcipts. 
# Numbers are not allowed due to the non-possibility to transcript them into kabyle yet.


DeepSpeech/bin/import_cv2.py --filter_alphabet data-kab/alphabet.txt ./kab/

