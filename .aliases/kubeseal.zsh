alias ks="seal-secret"

seal-secret()
{
  local input_file="$1"
  
  if [[ -z "$input_file" ]]; then
    echo "Usage: seal-secret <secret-file>"
    echo "Example: seal-secret my-app.secret.yaml"
    return 1
  fi
  
  if [[ ! -f "$input_file" ]]; then
    echo "Error: File '$input_file' not found"
    return 1
  fi
  
  # Replace .secret. with .sealed. in the filename
  local output_file="${input_file/.secret./.sealed.}"
  
  # If the input file doesn't contain .secret., just add .sealed before the extension
  if [[ "$output_file" == "$input_file" ]]; then
    local extension="${input_file##*.}"
    local basename="${input_file%.*}"
    output_file="${basename}.sealed.${extension}"
  fi
  
  echo "Sealing '$input_file' -> '$output_file'"
  kubeseal --scope cluster-wide -o yaml < "$input_file" > "$output_file"
  
  if [[ $? -eq 0 ]]; then
    echo "Successfully created sealed secret: $output_file"
  else
    echo "Error: Failed to create sealed secret"
    return 1
  fi
}