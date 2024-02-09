variable "enable_telemetry" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see https://aka.ms/avm/telemetryinfo.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
}


variable "tags" {
  type = map(any)
  default = {
    environment = "dev"
    purpose     = "terraform example testing"
  }
}

