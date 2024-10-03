# PowerShell Scripts for Compliance Reporting

This repository contains a collection of PowerShell scripts developed during my time at Deloitte, specifically designed for automating and enhancing compliance reporting processes.

## Purpose

The scripts are aimed at improving efficiency in compliance reporting by automating repetitive tasks, ensuring accuracy in data extraction, and standardizing the reporting formats. These scripts were developed to help manage various compliance-related data sources, generate reports, and streamline audits and other compliance checks.

## Features

- **Automated Data Extraction:** Scripts designed to extract relevant data from multiple sources such as databases, CSV files, and system logs.
- **Report Generation:** Automated generation of reports in standardized formats such as CSV, Excel, and PDF, tailored for compliance reviews.
- **Error Handling:** Robust error handling mechanisms to ensure the scripts can handle unexpected inputs and continue processing or log errors.
- **Notifications:** Integrated with email notification systems to send alerts or summaries upon the successful or unsuccessful completion of tasks.
- **Modular Design:** Each script is modular and can be easily adapted or extended to suit different compliance requirements.

## Script Overview

1. **Data_Extraction.ps1**
   - Extracts compliance-related data from databases and CSV files.
   - Filters and processes data based on predefined compliance criteria.

2. **Report_Generation.ps1**
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
