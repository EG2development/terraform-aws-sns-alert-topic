# The smallest useful call: a topic encrypted with a key the module creates,
# and one email subscription. The address is a sensitive variable, so it stays
# out of plan output. Examples call the module from the working copy so CI
# validates this repository's code; a real caller pins a Git source
# (README.md, "Usage").

provider "aws" {
  region = var.region
}

module "alerts" {
  source = "../.."

  name = var.name

  subscriptions = {
    oncall = { protocol = "email", endpoint = var.alert_email }
  }
}
