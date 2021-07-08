# Splunk Observability - System Limits
Use this Terraform repo to deploy the a dashboard group and detectors into your org to monitor your usage of system limits.
## Before you get started
Update the main.tf file with your authtoken and desired notification settings.
> auth_token = "<<<YOURTOKENHERE>>>" <br/>
> notifications = ["Email,your-email-address@bar.com"]