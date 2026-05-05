#!/bin/bash
set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  KVM VM Deployer (Terraform + Libvirt)  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Step: Choose mode
echo -e "${YELLOW}What do you want to do?${NC}"
echo "1) Create a new VM from ISO/Image"
echo "2) Clone existing VM"
read -p "Choose one (1/2): " CREATE_MODE

if [[ "$CREATE_MODE" != "1" && "$CREATE_MODE" != "2" ]]; then
    echo -e "${RED}❌ Invalid input. Script cancelled.${NC}"
    exit 1
fi

# ─────────────────────────────────────────
# PATH 1: Create New VM from ISO
# ─────────────────────────────────────────
if [[ "$CREATE_MODE" == "1" ]]; then
    echo ""
    echo -e "${GREEN}=== Mode: Create New VM from ISO ===${NC}"
    
    read -p "📁 ISO/Image location (e.g., /var/lib/libvirt/images/ubuntu.iso): " ISO_PATH
    
    # Validate ISO file
    if [[ ! -f "$ISO_PATH" ]]; then
        echo -e "${RED}❌ ISO file not found: $ISO_PATH${NC}"
        exit 1
    fi
    
    # Format for libvirt provider
    if [[ "$ISO_PATH" != file://* ]]; then
        ISO_PATH="file://$ISO_PATH"
    fi
    
    read -p "🖥️  VM name prefix (e.g., web, db, app): " VM_PREFIX
    read -p "💾 RAM per VM in GB (e.g., 2, 4, 8) [2]: " RAM_GB; RAM_GB=${RAM_GB:-2}
    read -p "📦 Storage per VM in GB (e.g., 20, 40, 100) [20]: " DISK_GB; DISK_GB=${DISK_GB:-20}
    
    echo ""
    echo -e "${YELLOW}Available networks:${NC}"
    virsh net-list --name 2>/dev/null || echo "  - default"
    read -p "🌐 Network name [default]: " NET_NAME; NET_NAME=${NET_NAME:-default}
    
    read -p "👤 Username for VM: " VM_USER
    read -p "🔒 Password for VM (leave empty for SSH key): " VM_PASS
    echo ""
    read -p "🔑 SSH Public Key (optional, paste or leave empty): " VM_SSH
    
    OS_SOURCE="iso"
    CLONE_VOL=""
    VM_COUNT=1

# ─────────────────────────────────────────
# PATH 2: Clone Existing VM
# ─────────────────────────────────────────
elif [[ "$CREATE_MODE" == "2" ]]; then
    echo ""
    echo -e "${GREEN}=== Mode: Clone Existing VM ===${NC}"
    
    echo ""
    echo -e "${YELLOW}Available VMs to clone:${NC}"
    virsh list --all --name
    
    read -p "📋 Source VM name: " SOURCE_VM_NAME
    read -p "🆕 New VM name prefix: " VM_PREFIX
    
    # Find source volume
    echo -e "${YELLOW}Searching for source VM volume...${NC}"
    SOURCE_VOL=$(virsh domblklist "$SOURCE_VM_NAME" 2>/dev/null | grep -E '\.qcow2|\.raw' | head -1 | awk '{print $2}')
    
    if [[ -z "$SOURCE_VOL" ]]; then
        echo -e "${RED}❌ Volume for VM '$SOURCE_VM_NAME' not found.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Source volume found: $SOURCE_VOL${NC}"
    
    # Get source VM properties
    SOURCE_RAM=$(virsh dominfo "$SOURCE_VM_NAME" 2>/dev/null | grep "Max memory" | awk '{print $3}')
    SOURCE_RAM_GB=$((SOURCE_RAM / 1024))
    
    echo ""
    echo -e "${YELLOW}Source VM properties:${NC}"
    echo "  - RAM: ${SOURCE_RAM_GB} GB"
    echo "  - Volume: $SOURCE_VOL"
    
    read -p "💾 Use same RAM (${SOURCE_RAM_GB} GB)? (y/n) [y]: " USE_SAME_RAM
    if [[ "$USE_SAME_RAM" != "n" && "$USE_SAME_RAM" != "N" ]]; then
        RAM_GB=$SOURCE_RAM_GB
    else
        read -p "💾 New RAM in GB: " RAM_GB
    fi
    
    read -p "📦 Storage in GB (0 = same as source) [0]: " DISK_GB; DISK_GB=${DISK_GB:-0}
    
    echo ""
    echo -e "${YELLOW}Available networks:${NC}"
    virsh net-list --name 2>/dev/null || echo "  - default"
    read -p "🌐 Network name [default]: " NET_NAME; NET_NAME=${NET_NAME:-default}
    
    read -p "👤 Username for VM: " VM_USER
    read -p "🔒 Password for VM: " VM_PASS
    read -p "🔑 SSH Public Key (optional): " VM_SSH
    
    OS_SOURCE="clone"
    ISO_PATH=""
    CLONE_VOL="$SOURCE_VOL"
    VM_COUNT=1
fi

# ─────────────────────────────────────────
# Validation
# ─────────────────────────────────────────
if [[ -z "$VM_PREFIX" || -z "$VM_USER" || -z "$NET_NAME" ]]; then
    echo -e "${RED}❌ Required fields cannot be empty!${NC}"
    exit 1
fi

# ─────────────────────────────────────────
# Generate terraform.tfvars
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}📝 Generating terraform.tfvars...${NC}"

cat > terraform.tfvars <<EOF
vm_count           = $VM_COUNT
vm_name_prefix     = "$VM_PREFIX"
ram_gb             = $RAM_GB
disk_size_gb       = $DISK_GB
os_source_type     = "$OS_SOURCE"
iso_path           = "$ISO_PATH"
clone_base_volume  = "$CLONE_VOL"
network_name       = "$NET_NAME"
cloudinit_username = "$VM_USER"
cloudinit_password = "$VM_PASS"
ssh_public_key     = "$VM_SSH"
EOF

echo -e "${GREEN}✓ terraform.tfvars created successfully${NC}"
echo ""

# ─────────────────────────────────────────
# Terraform Execution
# ─────────────────────────────────────────
echo -e "${BLUE}🚀 Initializing Terraform...${NC}"
terraform init -input=false

echo ""
echo -e "${BLUE}📋 Creating deployment plan...${NC}"
terraform plan -out=tfplan -input=false

echo ""
read -p "✅ Confirm deployment? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${YELLOW}❌ Deployment cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🔨 Creating VM(s)...${NC}"
terraform apply -input=false tfplan

# ─────────────────────────────────────────
# Post-Deployment Output
# ─────────────────────────────────────────
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}🎉 VM(s) Created Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "VM Name: ${VM_PREFIX}-1"
echo ""
echo -e "${YELLOW}📍 Get IP Address:${NC}"
echo "  terraform output vm_ips"
echo ""
echo -e "${YELLOW}🔐 Connect via SSH:${NC}"
echo "  ssh ${VM_USER}@<IP_ADDRESS>"
echo ""
echo -e "${YELLOW}🗑️  Destroy VM(s):${NC}"
echo "  terraform destroy"
echo ""