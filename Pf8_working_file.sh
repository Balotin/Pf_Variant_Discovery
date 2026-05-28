cp -r fogang@bioinfo-san.ird.fr:/projects/medium/GATACmalaria/MADBIO/sWGS/Pf_Variants_Discovery/MADBIO_sWGA_PfVariantsDiscovery_output/snp_indels/*.vcf.gz* .

gh repo create PF_VARIANTS_DISCOVERY --public --description "short Variants (SNPs and indels) calling pipeline for Plasmodium falciparum isolates"