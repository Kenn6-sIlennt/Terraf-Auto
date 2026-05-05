# 🖥️ KVM VM Automation with Terraform

Automated provisioning of KVM virtual machines using Terraform + libvirt provider with interactive Bash script.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![KVM](https://img.shields.io/badge/KVM-QEMU-orange?style=flat)
![Bash](https://img.shields.io/badge/Bash-Script-green?style=flat)

---

## ✨ Features

- 🔄 **Two Modes**: Create new VM from ISO **or** clone existing VM
- 💡 **Interactive CLI**: Guided prompts for all parameters
- ⚙️ **Cloud-Init**: Auto-configure hostname, user, SSH key, packages
- 🌐 **Network Aware**: Auto-detect available KVM networks
- 📦 **Flexible Storage**: Support ISO boot or volume cloning
- 🎯 **RAM in GB**: Simple input (auto-converted to MB for KVM)

---

## 🚀 Quick Start

# 1. Clone repository
git clone https://github.com/Kenn6-sIlennt/Terraform-automation.git
cd Terraform-automation

# 2. Make script executable
chmod +x kvm-auto.sh

# 3. Run the interactive deployer
./kvm-auto.sh

---

## 📊 Example Usage Flow

What do you want to do?
1) Create a new VM from ISO/Image
2) Clone existing VM
Choose one (1/2): 1

- 📁 ISO/Image location: /var/lib/libvirt/images/ubuntu-cloud.img
- 🖥️  VM name prefix: web
- 💾 RAM per VM in GB [2]: 4
- 📦 Storage per VM in GB [20]: 40
- 🌐 Network name [default]: default
- 👤 Username: admin
- 🔒 Password: password
- 🔑 SSH Public Key: ssh-rsa AAAA...

✅ Confirm deployment? (y/n): y

---
## ⚠️ Important Notes

- ISO/Image must support cloud-init for auto-configuration
- Recommended: Ubuntu Cloud Images, Rocky Linux Cloud, Debian Cloud
- Standard installer ISOs will boot to manual setup (no auto-login)
- Source VM should be shut down before cloning
- Use qemu-img to create base images for efficient cloning:
---

## 📋 Prerequisites

```bash
# KVM + Libvirt installed and running
sudo systemctl status libvirtd

# Terraform installed
terraform version

# Required permissions (add user to libvirt group)
sudo usermod -aG libvirt $USER
# → Logout & login again for changes to apply

# Optional: jq for pretty JSON output


sudo apt install jq  # Debian/Ubuntu
sudo dnf install jq  # RHEL/Fedora
