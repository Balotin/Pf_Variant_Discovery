#!/bin/bash

# Pf3D7 reference genome
cd "$REFGENOME_DIR" || { echo "ERROR: Cannot cd to $REFGENOME_DIR"; exit 1; }

# Check if reference genome exists
if [ ! -f "$REFGENOME" ]; then
    echo "ERROR: Reference genome $REFGENOME not found in $REFGENOME_DIR"
    exit 1
fi

# Index with BWA (for read alignment)
echo "Running bwa index..."
$BWA index "$REFGENOME" || { echo "bwa index failed"; exit 1; }

# Index with samtools (for random access)
echo "Running samtools faidx..."
$SAMTOOLS faidx "$REFGENOME" || { echo "samtools faidx failed"; exit 1; }

# Create dictionary for GATK
echo "Running GATK CreateSequenceDictionary..."
$GATK CreateSequenceDictionary -R "$REFGENOME" -O "${REFGENOME%.fasta}.dict" || { echo "GATK failed"; exit 1; }

echo "Indexing complete!"

# Return to base directory
cd "$BASEDIR" || { echo "WARNING: Could not return to $BASEDIR"; exit 1; }

echo "All done! Current directory: $(pwd)"