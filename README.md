# True Markets VM Automation – Linux + Terraform + Ansible

## Requirements

To use this project, ensure the following are in place:

- You must have Programtic Access to Cloud Account on AWS
- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.5 or later
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- Git client
- A Linux-based control host (Terraform Host)

---

## Overview

This project delivers **end-to-end infrastructure automation** by combining Terraform and Ansible. With a single `terraform apply`, it:

- Provisions AWS Resources; VC, subnets, Networking, Security Groups, EC2
- Configures each VM with a **dedicated Ansible user (`tmadmin`)**
- **Injects SSH public keys and passwords** via cloud-init
- **Generates a dynamic Ansible inventory** with VM IPs
- Triggers Ansible to apply **post-provisioning tasks** such as:
  - Installing system packages (e.g., Apache, Cockpit)
  - Setting hostnames and other OS-level configurations

This architecture enables **reproducible, zero-touch VM deployment**—ideal for testbeds, dev environments, and scalable infrastructure rollouts.

---

## How It Works

1. **Terraform** authenticates to Proxmox using the provided API token.
2. It clones a predefined **Rocky 9.6 cloud-init template**.
3. VMs are named, sized, and configured with:
   - Static IPs
   - SSH key injection
   - A `tmadmin` user with `sudo` access
4. A **null resource** in Terraform generates `inventory.yml` with VM IPs.
5. Another **null resource** waits for VM boot (~5 minutes) then runs Ansible.
6. **Ansible** logs in using SSH and applies all configuration tasks; install basic linux required packaged; cockpid and open firewall to allow cockpid traffic.

This process is fully orchestrated. No manual intervention required.

---

##  Usage Guide

###  Clone the Repository on Your Terraform Host

    git clone https://github.com/legendmbah/true_markets_th.git
    cd true_markets_th/terraform

### Configure Your Variables in terraform.tfvars

    proxmox_api_url     = "https://your-proxmox-host:8006/api2/json"
    proxmox_token_id    = "terraform@pam!api-token"
    proxmox_token_secret = "your_proxmox_api_token_secret"

### Initailize terraform to Download Provider Plugins

    terraform init

### Execute a dry Run to see what resources will be created

    terraform plan

### Apply and Deploy

    terraform apply --auto-approve

**This will prompt for number of servers to be deployed and;** 

- Provision specified number of Linux VMs via AWS API
- Assign IPs and configure cloud-init
- Generate an Ansible inventory from successfully deployed VM IPs 
- Wait 5 minutes for stabilization
- Trigger the Ansible playbook to configure the VMs