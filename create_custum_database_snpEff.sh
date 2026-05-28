#!/bin/bash
: ' The main thing to know is that you have to verify that the gene IDs match between the GFF, CDS.fa, and protein.fa files. 
This was not the case for Plasmodium_falciparumIT.
'
BASEDIR="."

# Define paths and files
SNPEFF_DIR="/home/student/miniconda3/share/snpeff-5.2-1"
REF_GENOME_DIR="${BASEDIR}/data/Reference_Pf_v54"
GENOME_FASTA="PlasmoDB-54_Pfalciparum3D7_Genome.fasta"
ANNOTATION_FILE="PPlasmoDB-54_Pfalciparum3D7_Genome.gff"
CDS_FASTA="PlasmoDB-54_Pfalciparum3D7_Genome_AnnotatedCDSs.fasta"
PROTEIN_FASTA="PlasmoDB-54_Pfalciparum3D7_Genome_AnnotatedProteins.fasta"
GENOME_NAME="Pf8_54_custom_2020_MalariaGen"

# Create the SnpEff directory structure for the custom genome
mkdir -p "${SNPEFF_DIR}/data/${GENOME_NAME}"

# Copy reference genome and annotation files
if ! cp "${REF_GENOME_DIR}/${GENOME_FASTA}" "${SNPEFF_DIR}/data/${GENOME_NAME}/sequences.fa"; then
    echo "Error copying genome FASTA file."
    exit 1
fi

if ! cp "${REF_GENOME_DIR}/${ANNOTATION_FILE}" "${SNPEFF_DIR}/data/${GENOME_NAME}/genes.gff"; then
    echo "Error copying annotation file."
    exit 1
fi

if ! cp "${REF_GENOME_DIR}/${CDS_FASTA}" "${SNPEFF_DIR}/data/${GENOME_NAME}/cds.fa"; then
    echo "Error copying CDS FASTA file."
    exit 1
fi

# Modify protein FASTA headers by removing "-p1"
#sed 's/-p1//g' "${REF_GENOME_DIR}/${PROTEIN_FASTA}" > "${SNPEFF_DIR}/data/${GENOME_NAME}/protein.fa"

# Update the snpEff configuration file
CONFIG_FILE="${SNPEFF_DIR}/snpEff.config"

# Remove any existing entry for the genome
if ! grep -v "^${GENOME_NAME}.genome" "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" || ! mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"; then
    echo "Error updating snpEff configuration file."
    exit 1
fi

# Add the new genome entry
if ! echo "${GENOME_NAME}.genome : Plasmodium falciparum IT" >> "${CONFIG_FILE}"; then
    echo "Error adding genome entry to snpEff configuration file."
    exit 1
fi

echo "Genome entry ${GENOME_NAME} updated in snpEff.config."

# Build the SnpEff database
cd "${SNPEFF_DIR}" || { echo "Failed to navigate to ${SNPEFF_DIR}"; exit 1; }
echo "Building SnpEff database for ${GENOME_NAME}..."
if ! snpEff build -gff3 -v "${GENOME_NAME}"; then
    echo "Error: Failed to create the SnpEff database for ${GENOME_NAME}."
    exit 1
fi

echo "Custom SnpEff database for ${GENOME_NAME} created successfully."
echo "You can now annotate your VCF file using this custom SnpEff database."
