#!/bin/bash

# PopPUNK Database Helper Script
# Downloads and stages PopPUNK GPS database and external clusters file
# Usage: poppunk_db_helper.sh <db_remote_url> <ext_clusters_remote_url> <local_db_dir> <local_ext_dir>

# Addpted from:
# https://github.com/GlobalPneumoSeq/gps-pipeline/blob/master/bin/check-download_poppunk_db.sh

set -euo pipefail

# Function to show usage
usage() {
    echo "Usage: $0 <db_remote_url> <ext_clusters_remote_url> <local_db_dir> <local_ext_dir>"
    echo "Example: $0 https://gps-project.cog.sanger.ac.uk/GPS_v9.tar.gz https://gps-project.cog.sanger.ac.uk/GPS_v9_external_clusters.csv ./db ./ext"
    exit 1
}

# Check arguments
if [ $# -ne 4 ]; then
    usage
fi

DB_REMOTE="$1"
EXT_CLUSTERS_REMOTE="$2"
DB_LOCAL="$3"
EXT_CLUSTERS_LOCAL="$4"

JSON_FILE="metadata.json"

echo "Setting up PopPUNK database..."
echo "Database URL: $DB_REMOTE"
echo "External clusters URL: $EXT_CLUSTERS_REMOTE"
echo "Local database directory: $DB_LOCAL"
echo "Local external clusters directory: $EXT_CLUSTERS_LOCAL"

# Return PopPUNK database name
# Check if all files exist and were obtained from the database at the specific link.
# If not: remove all sub-directories, download, and unzip to database directory, also save metadata to JSON
DB_NAME=$(basename "$DB_REMOTE" .tar.gz)
DB_PATH=${DB_LOCAL}/${DB_NAME}

echo "Database name: $DB_NAME"
echo "Database path: $DB_PATH"

if  [ ! -f "${DB_LOCAL}/${JSON_FILE}" ] || \
    [ ! "$DB_REMOTE" == "$(jq -r .url "${DB_LOCAL}/${JSON_FILE}" 2>/dev/null || echo '')"  ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}.h5" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}.dists.npy" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}.dists.pkl" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}_fit.npz" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}_fit.pkl" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}_graph.gt" ] || \
    [ ! -f "${DB_PATH}/${DB_NAME}_clusters.csv" ]; then
    
    echo "Database not found or incomplete, downloading..."
    rm -rf "${DB_LOCAL}"
    wget "$DB_REMOTE" -O poppunk_db.tar.gz
    mkdir -p "${DB_LOCAL}"
    tar -xzf poppunk_db.tar.gz -C "$DB_LOCAL"
    rm poppunk_db.tar.gz
    
    # Save metadata
    jq -n \
        --arg url "$DB_REMOTE" \
        --arg save_time "$(date +"%Y-%m-%d %H:%M:%S %Z")" \
        '{"url" : $url, "save_time": $save_time}' > "${DB_LOCAL}/${JSON_FILE}"
    
    echo "Database downloaded and extracted successfully"
else
    echo "Database already exists and is up to date"
fi

# Handle external clusters file
EXT_CLUSTERS_CSV=$(basename "$EXT_CLUSTERS_REMOTE")

if  [ ! -f "${EXT_CLUSTERS_LOCAL}/${JSON_FILE}" ] || \
    [ ! "$EXT_CLUSTERS_REMOTE" == "$(jq -r .url "${EXT_CLUSTERS_LOCAL}/${JSON_FILE}" 2>/dev/null || echo '')"  ] || \
    [ ! -f "${EXT_CLUSTERS_LOCAL}/${EXT_CLUSTERS_CSV}" ]; then
    
    echo "External clusters file not found or outdated, downloading..."
    rm -rf "${EXT_CLUSTERS_LOCAL}"
    mkdir -p "${EXT_CLUSTERS_LOCAL}"
    wget "$EXT_CLUSTERS_REMOTE" -O "${EXT_CLUSTERS_LOCAL}/${EXT_CLUSTERS_CSV}"
    
    # Save metadata
    jq -n \
        --arg url "$EXT_CLUSTERS_REMOTE" \
        --arg save_time "$(date +"%Y-%m-%d %H:%M:%S %Z")" \
        '{"url" : $url, "save_time": $save_time}' > "${EXT_CLUSTERS_LOCAL}/${JSON_FILE}"
    
    echo "External clusters file downloaded successfully"
else
    echo "External clusters file already exists and is up to date"
fi

echo "PopPUNK database setup complete!"
echo "Database name: $DB_NAME"
echo "Database path: $DB_PATH"
echo "External clusters file: ${EXT_CLUSTERS_LOCAL}/${EXT_CLUSTERS_CSV}"