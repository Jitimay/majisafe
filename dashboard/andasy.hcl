# MajiSafe Dashboard — Andasy deployment config

app_name = "majisafe-dashboard"

app {
  env = {}

  port           = 80
  primary_region = "kgl"

  compute {
    cpu      = 1
    memory   = 256
    cpu_kind = "shared"
  }

  process {
    name = "majisafe-dashboard"
  }
}
