# PowerShell Scripts for Compliance Reporting

This repository contains a collection of PowerShell scripts developed during my time at Deloitte, specifically designed for automating and enhancing compliance reporting processes.

## Purpose

The scripts are aimed at improving efficiency in compliance reporting by automating repetitive tasks, ensuring accuracy in data extraction, and standardizing the reporting formats. These scripts were developed to help manage various compliance-related data sources, generate reports, and streamline audits and other compliance checks.


## Script Overview

1. **Azure_Storage.ps1**
   - Extracts compliance-related data from databases and CSV files.
   - Filters and processes data based on predefined compliance criteria.

2. **.ps1**
   - Compiles the extracted data into a formatted report.
   - Outputs the report in various formats such as CSV, Excel, or PDF.

3. **Error_Handling.ps1**
   - Contains error-handling logic to catch and log issues during the extraction or reporting process.
   - Notifies the administrator of any failures via email.

4. **Notification_Sender.ps1**
   - Sends email notifications with the status of the compliance report generation.
   - Provides summary logs or attaches generated reports in the email.

## Usage

To run the scripts, clone this repository and execute the scripts from your PowerShell console. Ensure that any required data sources or configurations are set up before running the scripts.

```bash
git clone https://github.com/Ted123-byte/PowerShell-Scripts.git
cd PowerShell-Scripts
./Data_Extraction.ps1
