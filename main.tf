terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

variable "libvirt_uri" {
  description = "URI koneksi Libvirt/KVM"
  type        = string
  default     = "qemu:///system"
}

variable "vm_count" {
  description = "Jumlah VM yang akan dibuat"
  type        = number
}

variable "vm_name_prefix" {
  description = "Prefix nama VM (contoh: web, db, worker)"
  type        = string
}

# 👇 DIUBAH: Input sekarang dalam GB
variable "ram_gb" {
  description = "Jumlah RAM per VM (dalam GB)"
  type        = number
  validation {
    condition     = var.ram_gb >= 1
    error_message = "RAM minimal 1 GB."
  }
}

variable "disk_size_gb" {
  description = "Ukuran storage per VM (dalam GB)"
  type        = number
}

variable "os_source_type" {
  description = "Sumber OS: 'iso' atau 'clone'"
  type        = string
  validation {
    condition     = contains(["iso", "clone"], var.os_source_type)
    error_message = "os_source_type harus 'iso' atau 'clone'."
  }
}

variable "iso_path" {
  description = "Path lengkap ke file ISO (jika os_source_type = iso)"
  type        = string
  default     = ""
}

variable "clone_base_volume" {
  description = "Nama volume base yang akan di-clone (jika os_source_type = clone)"
  type        = string
  default     = ""
}

variable "network_name" {
  description = "Nama virtual network KVM yang akan digunakan"
  type        = string
}

variable "cloudinit_username" {
  description = "Username default untuk VM"
  type        = string
}

variable "cloudinit_password" {
  description = "Password untuk user"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH Public Key untuk akses VM"
  type        = string
  default     = ""
}

resource "libvirt_cloudinit_disk" "cloudinit" {
  count = var.vm_count
  name  = "${var.vm_name_prefix}-${count.index + 1}-cloudinit.iso"
  
  user_data = yamlencode({
    version      = "cloud-config"
    hostname     = "${var.vm_name_prefix}-${count.index + 1}"
    users = [
      {
        name  = var.cloudinit_username
        sudo  = ["ALL=(ALL) NOPASSWD:ALL"]
        shell = "/bin/bash"
        passwd = var.cloudinit_password != "" ? var.cloudinit_password : null
        ssh_authorized_keys = var.ssh_public_key != "" ? [var.ssh_public_key] : null
        chpasswd = { expire = false }
      }
    ]
    packages     = ["qemu-guest-agent", "cloud-init"]
  })
}

resource "libvirt_volume" "vm_disk" {
  count  = var.vm_count
  name   = "${var.vm_name_prefix}-${count.index + 1}.qcow2"
  pool   = "default"
  size   = var.disk_size_gb * 1073741824
  format = "qcow2"

  source = var.os_source_type == "iso" ? var.iso_path : null
  base_volume_name = var.os_source_type == "clone" ? var.clone_base_volume : null
}

resource "libvirt_domain" "vm" {
  count  = var.vm_count
  name   = "${var.vm_name_prefix}-${count.index + 1}"
  
  # 👇 Konversi otomatis GB -> MB (KVM membutuhkan satuan MB)
  memory = var.ram_gb * 1024
  vcpu   = 2

  network_interface {
    network_name = var.network_name
  }

  disk {
    volume_id = libvirt_volume.vm_disk[count.index].id
  }

  cloudinit = libvirt_cloudinit_disk.cloudinit[count.index].id

  console {
    type        = "pty"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

output "vm_names" {
  value = [for d in libvirt_domain.vm : d.name]
}

output "vm_ips" {
  value = {
    for idx, d in libvirt_domain.vm : d.name => d.network_interface[0].addresses
  }
}