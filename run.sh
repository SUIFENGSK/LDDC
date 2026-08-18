#!/bin/bash
echo "Activating virtual environment..."
WORK_DIR="/volume1/dev/scripts/LDDC"
cd "$WORK_DIR" || { echo "Failed to change directory to $WORK_DIR"; exit 1; }
source .venv/bin/activate

SOURCE_DIR="/volume1/shared/MusicTemp"
echo "Checking for files in shared..."
shared_files=$(find "${SOURCE_DIR:?}" -type f ! -path "*/@eaDir/*" ! -name "@eaDir")
if [ -z "$shared_files" ]; then
    echo "No files found in shared. "
else
    echo "Moving files from shared to music_temp..."
    mkdir -p music_temp
    find "${SOURCE_DIR:?}" -mindepth 1 -maxdepth 1 ! -name '@eaDir' -exec mv {} music_temp/ \;
fi

echo "Checking for files in music_temp..."
music_files=$(find music_temp -type f ! -path "*/@eaDir/*" ! -name "@eaDir")

if [ -z "$music_files" ]; then
    echo "No music files found. Exiting."
    exit 0
fi

echo "Processing music files..."
while IFS= read -r file; do
    filename=$(basename "$file")
    music_name="${filename%.*}"
    echo "Processing: $music_name"
    # Only set LD_LIBRARY_PATH for python command:
    LD_LIBRARY_PATH=~/custom_lib:$LD_LIBRARY_PATH python run.py "$music_name"
done <<< "$music_files"


TARGET_DIR="/volume1/music"
echo "Checking for matching music and lyric files..."

if [ -d "music_temp" ] && [ -d "lyrics_temp" ]; then
    # Create temporary files to store matched pairs
    temp_music_list=$(mktemp)
    temp_lyric_list=$(mktemp)
    temp_unmatched_list=$(mktemp)
    
    # Check each music file for corresponding lyric file
    find music_temp -type f ! -path "*/@eaDir/*" ! -name "@eaDir" | while IFS= read -r music_file; do
        if [ -f "$music_file" ]; then
            music_basename=$(basename "$music_file")
            music_name="${music_basename%.*}"
            
            # Look for corresponding lyric file
            lyric_file=$(find lyrics_temp -name "${music_name}.*" -type f ! -path "*/@eaDir/*" ! -name "@eaDir" | head -1)
            
            if [ -n "$lyric_file" ]; then
                echo "Match found: $music_basename <-> $(basename "$lyric_file")"
                echo "$music_file" >> "$temp_music_list"
                echo "$lyric_file" >> "$temp_lyric_list"
            else
                echo "No lyric file found for: $music_basename"
                echo "$music_basename" >> "$temp_unmatched_list"
            fi
        fi
    done
    
    # Count matching pairs
    match_count=$(wc -l < "$temp_music_list")
    echo "Found $match_count matching pairs"
    
    # Move only matched files
    if [ "$match_count" -gt 0 ]; then
        echo "Moving matched lyric files to $TARGET_DIR..."
        while IFS= read -r lyric_file; do
            mv "$lyric_file" "${TARGET_DIR:?}"/
            chmod 664 "${TARGET_DIR:?}/$(basename "$lyric_file")"
        done < "$temp_lyric_list"
        
        echo "Moving matched music files to $TARGET_DIR..."
        while IFS= read -r music_file; do
            mv "$music_file" "${TARGET_DIR:?}"/
            chmod 664 "${TARGET_DIR:?}/$(basename "$music_file")"
        done < "$temp_music_list"
        
        echo "Moved $match_count matching pairs to $TARGET_DIR"
    else
        echo "No matching pairs found. No files moved."
    fi
    
    # Clean up temporary files and handle unmatched files
    unmatched_count=$(wc -l < "$temp_unmatched_list")
    if [ "$unmatched_count" -gt 0 ]; then
        echo "All operations completed."
        echo "Unmatched files found:"
        while IFS= read -r music_basename; do
            echo "No lyric file found for: $music_basename"
        done < "$temp_unmatched_list"
        rm -f "$temp_music_list" "$temp_lyric_list" "$temp_unmatched_list"
        exit 1
    fi
    rm -f "$temp_music_list" "$temp_lyric_list" "$temp_unmatched_list"
else
    echo "music_temp or lyrics_temp directory not found"
fi

echo "All operations completed."