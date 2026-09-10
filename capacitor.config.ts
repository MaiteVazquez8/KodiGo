import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.codepath.app',
  appName: 'CodePath',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
  },
}

export default config
