###############################################################################################
# Before applying this Terraform configuration file, fill out these things below:
# - auth_token - set this to the token you use with Terraform
# - notifications - Ensure this is configured to alert the right people in your organization.
###############################################################################################

provider "signalfx" {
  auth_token = "<<<YOURAUTHTOKEN>>>"
}

###############################################################################################
## Chart Definitions
###############################################################################################
resource "signalfx_time_chart" "AMTS_Usage_Chart" {
  name        = "AMTS - Usage vs Limit"
  description = "This chart shows your usage of Active MTS vs the system limit."
  program_text = <<-EOF
  A = data('sf.org.limit.activeTimeSeries').publish(label='AMTS Limit')
  B = data('sf.org.numActiveTimeSeries').publish(label='AMTS Usage')
  EOF

  viz_options {
    label = "AMTS Limit"
    color = "Yellow"
  }
}

resource "signalfx_time_chart" "MTSM_Usage_Chart" {
  name        = "MTS Creation - Usage vs Limit"
  description = "This chart shows your usage of MTS Creation vs the system limit."
  program_text = <<-EOF
  A = data('sf.org.limit.metricTimeSeriesCreatedPerMinute').publish(label='MTS Creation Limit')
  B = data('sf.org.numMetricTimeSeriesCreated').publish(label='MTS Creations')
  EOF

  viz_options {
    label = "MTS Creation Limit"
    color = "Yellow"
  }
}

resource "signalfx_time_chart" "Detector_Usage_Chart" {
  name        = "Total Detectors - Usage vs Limit"
  description = "This chart shows your usage of Detectors vs the system limit."
  program_text = <<-EOF
  A = data('sf.org.limit.detector').publish(label='Detector Limit')
  B = data('sf.org.num.detector').publish(label='Detectors')
  EOF

  viz_options {
    label = "Detector Limit"
    color = "Yellow"
  }
}

resource "signalfx_time_chart" "aborted_detectors_chart" {
  name        = "Aborted Detectors"
  description = "This chart identifies any detectors that have been aborted because they have too many MTS."

  program_text = <<-EOF
  A = data('sf.org.numDetectorsAborted', rollup='sum').sum(over='5h').publish(label='Aborted Detectors Counter')
  B = data('sf.org.abortedDetectors').publish(label='Aborted Detectors Events')
  EOF
}

resource "signalfx_text_chart" "aborted_detectors_text_chart" {
  name = "What is this dashboard?"
  markdown = <<-EOF
    This dashboard is used to track aborted detectors in your organization.

    Detectors can be aborted for a couple reasons, generally related to the fact that they have more data than can be contained in a single detector. If one does abort, there is an event that helps identify the problematic detector.<br/>
    The event will be shown over there --->

    Please see this [KB Article](https://google.com) for more information about how to resolve this problem and get the detector running again.
  EOF
}

###############################################################################################
## Dashboard Group Definition
###############################################################################################
resource "signalfx_dashboard_group" "system_limits_dashboard_group" {
  name        = "System Limits"
  description = "This groups tracks important system limits to be aware of in your organization."
}

resource "signalfx_dashboard" "detectors_dashboard" {
  name            = "Aborted Detectors"
  dashboard_group = signalfx_dashboard_group.detectors_group.id
  time_range      = "-5h"
  chart {
    chart_id = signalfx_text_chart.aborted_detectors_text_chart.id
    width    = 6
    column   = 0
    row      = 0
  }
  chart {
    chart_id = signalfx_time_chart.aborted_detectors_chart.id
    width    = 6
    column   = 0
    row      = 1
  }
  chart {
    chart_id = signalfx_event_feed_chart.aborted_detectors_event_feed.id
    width    = 6
    height   = 2
    column   = 6
    row      = 0
  }
  event_overlay {
    signal = "sf.org.abortedDetectors"
    color = "magenta"
    line = true
  }
  selected_event_overlay {
    signal = "sf.org.abortedDetectors"
  }
}

resource "signalfx_detector" "aborted_detector" {
  name         = "Detectors Aborted"
  description  = "Triggers when a detector has been aborted because it has too many MTS"
  program_text = <<-EOF
  A = data('sf.org.numDetectorsAborted', rollup='sum').sum(over='5h').publish(label='A')
  B = data('sf.org.abortedDetectors').publish(label='B')
  detect(when(A > threshold(0))).publish('Detector Aborted')
  EOF

  rule {
    description  = "A detector has been aborted."
    severity     = "Critical"
    detect_label = "Detector Aborted"
    # Update notifications with your preferred method here. Email and Slack are shown as examples.
    notifications = ["Email,your-email-address@bar.com"]
    #notifications = ["Slack,credentialId,channel"]
    runbook_url        = signalfx_dashboard.detectors_dashboard.url
    parameterized_body = <<-EOF
   {{#if anomalous}}
    This alert indicates that a detector in your organization has too many MTS and has been aborted. Please
    identify the large detector and split it into multiple smaller detectors to get it running again.<br/>
    Use this dashboard to identify the aborted detector: ${signalfx_dashboard.detectors_dashboard.url}
    
   {{else}}
    Rule "{{{ruleName}}}" in detector "{{{detectorName}}}" cleared at {{timestamp}}.
    Please verify that the aborted detector is running properly now.
   {{/if}}

   {{#if anomalous}}
   {{#if runbookUrl}}Runbook: {{{runbookUrl}}}{{/if}}
   {{#if tip}}Please view the linked KB article for more information.{{{tip}}}{{/if}}
   {{/if}}
   EOF
  }
}