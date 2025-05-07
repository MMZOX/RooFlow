#!/bin/bash

# Script to find Roo Code's Code mode system prompt content on macOS
# and generate system_prompt.md in the current directory

# Set colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Finding Roo Code's system prompt on macOS        ${NC}"
echo -e "${BLUE}==================================================${NC}"

# Common VSCode extension locations on macOS
EXTENSION_LOCATIONS=(
    "$HOME/.vscode/extensions"
    "$HOME/.vscode-insiders/extensions"
    "$HOME/Library/Application Support/Code/User/extensions"
    "$HOME/Library/Application Support/Code - Insiders/User/extensions"
)

# Function to search for Roo Code extension
find_roocode_extension() {
    local found=false
    local extension_dir=""
    
    echo -e "${YELLOW}Searching for Roo Code extension...${NC}"
    
    for location in "${EXTENSION_LOCATIONS[@]}"; do
        if [ -d "$location" ]; then
            echo -e "Checking ${location}..."
            # Look for directories that might be the Roo Code extension
            find "$location" -maxdepth 1 -type d -name "*roo*" -print0 2>/dev/null | while IFS= read -r -d $'\0' dir; do
                if ! $found; then # Process only if not already found
                    echo -e "  Found potential Roo Code directory: ${dir}"
                    # Verify it's the Roo Code extension by checking package.json
                    if [ -f "${dir}/package.json" ] && grep -q "\"name\".*roo" "${dir}/package.json" 2>/dev/null; then
                        echo -e "${GREEN}  ✓ Confirmed Roo Code extension at: ${dir}${NC}"
                        extension_dir="$dir"
                        found=true
                        # To break out of a while loop piped from find, we can't use 'break' directly to affect the outer loop.
                        # We set 'found' and the outer 'if $found; then break; fi' will handle it.
                        # For the 'while' loop itself, we can stop processing further items from find if needed,
                        # or let it complete if the find command is quick.
                        # In this case, since 'found' is checked outside, this inner loop will effectively stop making changes.
                    fi
                fi
            done
        fi
        
        if $found; then
            break
        fi
    done
    
    if ! $found; then
        # Try a more extensive search if not found in common locations
        echo -e "${YELLOW}Roo Code not found in common locations. Performing deeper search...${NC}"
        
        # Check if mdfind command exists (macOS Spotlight search)
        if command -v mdfind >/dev/null 2>&1; then
            echo "Using Spotlight to search for Roo Code extension..."
            potential_dirs=$(mdfind -name "roocode" -onlyin "$HOME/Library/Application Support" 2>/dev/null)
            
            echo "$potential_dirs" | while IFS= read -r dir; do
                if ! $found; then
                    if [ -d "$dir" ] && [ -f "${dir}/package.json" ] && grep -q "\"name\".*roo" "${dir}/package.json" 2>/dev/null; then
                        echo -e "${GREEN}  ✓ Found Roo Code extension at: ${dir}${NC}"
                        extension_dir="$dir"
                        found=true
                    fi
                fi
            done
        else
            echo "Spotlight search (mdfind) not available. Using find command..."
            potential_dirs=$(find "$HOME/Library/Application Support" -type d -name "*roo*" 2>/dev/null)
            
            echo "$potential_dirs" | while IFS= read -r dir; do
                if ! $found; then
                    if [ -d "$dir" ] && [ -f "${dir}/package.json" ] && grep -q "\"name\".*roo" "${dir}/package.json" 2>/dev/null; then
                        echo -e "${GREEN}  ✓ Found Roo Code extension at: ${dir}${NC}"
                        extension_dir="$dir"
                        found=true
                    fi
                fi
            done
        fi
    fi
    
    echo "$extension_dir"
    return $([ "$found" == true ] && echo 0 || echo 1)
}

# Function to find and extract the system prompt for Code mode
extract_system_prompt() {
    local extension_dir="$1"
    local output_file="system_prompt.md"
    local found=false
    
    echo -e "${YELLOW}Searching for Code mode system prompt...${NC}"
    
    # Common locations for system prompts within the extension
    potential_locations=(
        "${extension_dir}/dist"
        "${extension_dir}/out"
        "${extension_dir}/resources"
        "${extension_dir}/assets"
        "${extension_dir}"
    )
    
    # Files that might contain the system prompt
    potential_files=(
        "system_prompt.md"
        "code_prompt.md"
        "system-prompt.md"
        "code-prompt.md"
        "prompts/code.md"
        "prompts/system.md"
    )
    
    # First try direct file matches
    for location in "${potential_locations[@]}"; do
        if [ -d "$location" ]; then
            for file in "${potential_files[@]}"; do
                if [ -f "${location}/${file}" ]; then
                    echo -e "${GREEN}  ✓ Found system prompt file: ${location}/${file}${NC}"
                    cp "${location}/${file}" "$output_file"
                    found=true
                    # To break out of nested loops when inside a pipe, 'found' flag handles outer loop.
                    # For the 'while' loop, this will stop further processing in this iteration.
                    # The outer loop checks 'found' to break.
                    break # Breaks the inner 'for file' loop
                    # The 'break 2' equivalent is handled by the 'if $found; then break; fi' in the outer loop.
                fi
            done
            if $found; then break; fi
        fi
    done
    
    # If not found, try searching for JSON files that might contain the prompt
    if ! $found; then
        echo "Direct prompt file not found. Searching in JSON configuration files..."
        
        for location in "${potential_locations[@]}"; do
            if [ -d "$location" ]; then
                # Find all JSON files
                find "$location" -type f -name "*.json" -print0 2>/dev/null | while IFS= read -r -d $'\0' json_file; do
                    if $found; then continue; fi # Skip if already found

                    # Check if file contains "system" and "prompt" keywords
                    if grep -q "system.*prompt\|prompt.*system\|code.*mode" "$json_file" 2>/dev/null; then
                        echo -e "  Potential config file found: ${json_file}"
                        
                        # Try to extract the system prompt using jq if available
                        if command -v jq >/dev/null 2>&1; then
                            # Try various JSON paths that might contain the prompt
                            for path_jq in '.systemPrompt' '.modes.code.prompt' '.modes.code.systemPrompt' '.prompts.code' '.prompts.system'; do
                                prompt=$(jq -r "$path_jq" "$json_file" 2>/dev/null)
                                if [ "$prompt" != "null" ] && [ "$prompt" != "" ]; then
                                    echo -e "${GREEN}  ✓ Extracted system prompt using jq from: ${json_file}${NC}"
                                    echo "$prompt" > "$output_file"
                                    found=true
                                    break # Break from path_jq loop
                                fi
                            done
                            if $found; then continue; fi # Continue to next json_file if found
                        else # This 'else' corresponds to 'if command -v jq'
                            echo "jq not found. Using grep for basic extraction..."
                            # Basic extraction using grep
                            # Create a temporary file for grep output
                            temp_grep_output=$(mktemp)
                            if grep -E -A 100 -B 100 'system.*prompt|code.*mode' "$json_file" > "$temp_grep_output" 2>/dev/null; then
                                if [ -s "$temp_grep_output" ]; then
                                    echo -e "${YELLOW}  Found potential system prompt content in: ${json_file}${NC}"
                                    echo -e "${YELLOW}  Saving raw content to ${output_file}_raw for manual extraction${NC}"
                                    # Ensure the raw output file is distinct if multiple JSONs are processed by grep
                                    raw_output_file_name="${output_file}_${json_file//\//_}_raw"
                                    cp "$temp_grep_output" "$raw_output_file_name"
                                    # Consider not setting 'found=true' here as it's a raw dump
                                    # and we might find a better match later.
                                    # Or, if this is acceptable, then found=true and break.
                                    # For now, let's assume a raw dump is a "find" but less ideal.
                                    # found=true # Uncomment if this should stop further searching
                                fi
                            fi
                            rm -f "$temp_grep_output"
                        fi # This 'fi' closes 'if command -v jq'
                    fi # This 'fi' closes 'if grep -q "system.*prompt..."'
                    if $found; then break; fi # Break from the while loop for json_files if a definitive prompt was found by jq
                done # This 'done' closes the 'while IFS= read -r -d $'\0' json_file' loop
            fi
        done
    fi

    # If not found by previous methods, try mdfind with persona string
    if ! $found; then
        echo -e "${YELLOW}Prompt not found by other methods. Trying mdfind with persona string...${NC}"
        if command -v mdfind >/dev/null 2>&1; then
            # Define the persona string to search for
            # Ensure this string exactly matches what you expect in the prompt files.
            # Shell quoting can be tricky with complex strings. Using a variable can help.
            persona_string="You are Roo, a highly skilled software engineer with extensive knowledge in many programming languages, frameworks, design patterns, and best practices."
            
            # Search in the user's VSCode application support directory for .md files containing the persona string
            # The user's feedback indicated files were in $HOME/Library/Application Support/Code/User/History/...
            # We'll search within $HOME/Library/Application Support/Code/User for .md files
            echo "Searching for .md files containing the persona string in $HOME/Library/Application Support/Code/User..."
            
            # mdfind can be slow if the query is too broad or the scope too large.
            # We'll take the first .md file found.
            # The query 'kMDItemTextContent = "..."' is for exact phrase.
            # Simpler: mdfind -onlyin <path> "text" | grep '\.md$' | head -n 1
            
            # Using the simpler approach based on user feedback:
            # mdfind -onlyin "$HOME/Library/Application Support/Code/User" "$persona_string"
            # The above command will list files containing the string. We then need to filter for .md and take the first.
            
            # It's safer to find all files with the string and then check if they are .md
            # and exist, then take the first one.
            
            # Using a more precise mdfind query for .md files containing the text.
            # Note: kMDItemTextContent might require the Spotlight index to be up-to-date and comprehensive.
            # A simpler mdfind and then grep might be more reliable if kMDItemTextContent is problematic.
            # Let's try the user's approach of searching for the string and then filtering.
            
            # Store results in an array to handle spaces in filenames
            # Initialize an empty array
            potential_prompt_files=()
            # Populate the array using a while loop, compatible with older bash versions
            while IFS= read -r line; do
                potential_prompt_files+=("$line")
            done < <(mdfind -onlyin "$HOME/Library/Application Support/Code/User" "$persona_string" 2>/dev/null)

            if [ ${#potential_prompt_files[@]} -gt 0 ]; then
                for prompt_file_path in "${potential_prompt_files[@]}"; do
                    # Check if it's an .md file and actually exists
                    if [[ "$prompt_file_path" == *.md ]] && [ -f "$prompt_file_path" ]; then
                        echo -e "${GREEN}  ✓ Found potential system prompt via mdfind (persona string): ${prompt_file_path}${NC}"
                        cp "$prompt_file_path" "$output_file"
                        found=true
                        break # Found one, exit loop
                    fi
                done
            else
                echo -e "${YELLOW}  mdfind found no files containing the persona string.${NC}"
            fi
        else
            echo -e "${RED}mdfind command not found. Skipping persona string search.${NC}"
        fi
    fi
    
    # Check if we found and saved the system prompt
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        echo -e "${GREEN}Successfully saved system prompt to ${output_file}${NC}"
        echo -e "${BLUE}==================================================${NC}"
        echo -e "${BLUE}  System prompt saved to: ${output_file}          ${NC}"
        echo -e "${BLUE}==================================================${NC}"
        return 0
    else
        echo -e "${RED}Could not find or extract the system prompt.${NC}"
        echo -e "${YELLOW}You may need to manually locate and copy the system prompt.${NC}"
        echo -e "${YELLOW}Try checking the VSCode settings for Roo Code or use the 'Copy system prompt to clipboard' feature in the extension.${NC}"
        return 1
    fi
}

# Main execution
extension_dir=$(find_roocode_extension)

if [ -n "$extension_dir" ]; then
    extract_system_prompt "$extension_dir"
else
    echo -e "${RED}Could not find Roo Code extension.${NC}"
    echo -e "${YELLOW}Please ensure Roo Code is installed in your VSCode.${NC}"
    echo -e "${YELLOW}Alternatively, use the 'Copy system prompt to clipboard' feature in the Roo Code extension settings.${NC}"
    exit 1
fi

exit 0
