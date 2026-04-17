app "majisafe-dashboard" {
  build {
    command = "npm install && npm run build"
    env = {
      VITE_API_BASE_URL = "https://majisafe-backend.andasy.dev"
    }
  }
  publish {
    directory = "dist"
  }
}
