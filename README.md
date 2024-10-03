# PowerShell Scripts for Compliance Reporting

This repository contains a collection of PowerShell scripts developed during my time at Deloitte, specifically designed for automating and enhancing compliance reporting processes.

## Purpose

The scripts are aimed at improving efficiency in compliance reporting by automating repetitive tasks, ensuring accuracy in data extraction, and standardizing the reporting formats. These scripts were developed to help manage various compliance-related data sources, generate reports, and streamline audits and other compliance checks.


## Script Overview

1. **AzureStorageAudit.ps1**
   -This script audits the associations between Azure storage accounts and various services (e.g., VMs, App Services, SQL Servers) and collects configuration details related to networking, security, and encryption. The results are exported into an Excel file for reporting purposes

2.**key_vault.ps1**
   -This PowerShell script is designed to audit the compliance of Azure Key Vault configurations with a specific security policy: Ensure Azure Key Vault is not Publicly Accessible


## Usage

To run the scripts, clone this repository and execute the scripts from your PowerShell console. Ensure that any required data sources or configurations are set up before running the scripts.

```bash
git clone https://github.com/Ted123-byte/PowerShell-Scripts.git
cd PowerShell-Scripts
./Data_Extraction.ps1
