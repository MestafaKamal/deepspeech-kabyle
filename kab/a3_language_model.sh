#!/bin/bash
# created by Mestafa Kamal



set -xe


echo "Create language model"

if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
	OLD_LANG=${LANG}
	export LANG=${LM_ICONV_LOCALE}
fi;


$HOMEDIR/${MODEL_LANGUAGE}/prepare_lm.sh

	if [ ! -f "/mnt/extracted/data/cv_kab/allSentences.txt" ]; then
		echo "Your language's prepare_lm.sh did not produce a allSentences.txt file. Please fix."
		exit 1
	fi;



pushd $HOME/ds/

	if [ ! -f "/mnt/lm/lm.binary" ]; then
			python data/lm/generate_lm.py \
				--input_txt /mnt/extracted/data/cv_kab/allSentences.txt \
				--output_dir /mnt/lm/ \
				--top_k ${LM_TOP_K} \
				--kenlm_bins $HOME/kenlm/build/bin/ \
				--arpa_order 3 \
				--max_arpa_memory "85%" \
				--arpa_prune "0|0|1" \
				--binary_a_bits 255 \
				--binary_q_bits 8 \
				--binary_type trie
	fi;

	./generate_scorer_package \
		--alphabet $HOMEDIR/${MODEL_LANGUAGE}/data_kab/alphabet.txt \
		--lm /mnt/lm/lm.binary \
		--vocab /mnt/lm/vocab-${LM_TOP_K}.txt \
		--package /mnt/lm/kenlm.scorer \
		--default_alpha ${LM_ALPHA} \
		--default_beta ${LM_BETA}

popd


if [ "${ENGLISH_COMPATIBLE}" = "1" ]; then
	export LANG=${OLD_LANG}
fi;
