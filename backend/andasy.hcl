# MajiSafe backend — Andasy deployment config
# Docs: https://docs.andasy.io

app_name = "majisafe-backend"

app {
  env = {}

  port           = 3000
  primary_region = "kgl"

  compute {
    cpu      = 1
    memory   = 512
    cpu_kind = "shared"
  }

  process {
    name = "majisafe-backend"
  }

  storage {
    name        = "majisafe-data"
    destination = "/data"
  }
}
