#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    #"package-1"
    #"package-2"

    # Required for ipadapter
    "insightface"
)

NODES=(
    #"https://github.com/ltdrdata/ComfyUI-Manager"
    #"https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus"
)

WORKFLOWS=(
    "https://raw.githubusercontent.com/vast-ai/base-image/comfyui-lora-provisioning/derivatives/pytorch/derivatives/comfyui/workflows/lora_single.json"
    "https://raw.githubusercontent.com/vast-ai/base-image/comfyui-lora-provisioning/derivatives/pytorch/derivatives/comfyui/workflows/lora_multiple.json"
)

CLIP_MODELS=(
    # None
)

CLIP_VISION_MODELS=(
    ("https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors")
    ("https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/image_encoder/model.safetensors" "CLIP-ViT-bigG-14-laion2B-39B-b160k.safetensors")
    # ("https://huggingface.co/Kwai-Kolors/Kolors-IP-Adapter-Plus/resolve/main/image_encoder/pytorch_model.bin" "clip-vit-large-patch14-336.bin")
)

UNET_MODELS=(
    # None
)

VAE_MODELS=(
    # None
)

LORA_MODELS=(
    # Furry
    "https://civitai.com/api/download/models/1780880?type=Model&format=SafeTensor"
)

CHECKPOINT_MODELS=(
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0_0.9vae.safetensors?download=true"
    "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0_0.9vae.safetensors?download=true"
    # Anime
    "https://civitai.com/api/download/models/372033?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

IPADAPTER_MODELS=(
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid_sdxl.bin?download=true" # SDXL base FaceID
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin?download=true" # SDXL plus v2
    "https://huggingface.co/h94/IP-Adapter-FaceID/resolve/main/ip-adapter-faceid-portrait_sdxl.bin?download=true" # SDXL text prompt style transfer
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages

    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"

    provisioning_get_files_and_rename \
        "${COMFYUI_DIR}/models/clip_vision" \
        "${CLIP_VISION_MODELS[@]}"

    provisioning_get_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"

    ipadapter_dir="${COMFYUI_DIR}/models/ipadapter"
    mkdir -p "${ipadapter_dir}"
    provisioning_get_files \
        "${ipadapter_dir}" \
        "${IPADAPTER_MODELS[@]}"

    workflows_dir="${COMFYUI_DIR}/user/default/workflows"
    mkdir -p "${workflows_dir}"
    provisioning_get_files \
        "${workflows_dir}" \
        "${WORKFLOWS[@]}"

    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s file(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

function provisioning_download_and_rename() {
    local url="$1"
    local target_dir="$2"
    local filename="$3"
    local chunk_size="${4:-4M}"

    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    local full_path="${target_dir}/${filename}"

    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="$chunk_size" -O "$full_path" "$url"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="$chunk_size" -O "$full_path" "$url"
    fi
}

function provisioning_get_files_and_rename() {
    if [[ -z $2 ]]; then return 1; fi

    local dir="$1"
    mkdir -p "$dir"
    shift
    local arr=("$@")
    printf "Downloading %s file(s) with custom names to %s...\n" "${#arr[@]}" "$dir"

    for tuple in "${arr[@]}"; do
        # Parse the tuple: extract URL and filename
        local url=$(echo "$tuple" | sed -n 's/.*("\([^"]*\)".*/\1/p')
        local filename=$(echo "$tuple" | sed -n 's/.*"\([^"]*\)".*/\1/p')

        if [[ -n "$url" && -n "$filename" ]]; then
            printf "Downloading: %s -> %s\n" "$url" "$filename"
            provisioning_download_and_rename "$url" "$dir" "$filename"
            printf "\n"
        else
            printf "Warning: Could not parse tuple: %s\n" "$tuple"
        fi
    done
}

if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi
