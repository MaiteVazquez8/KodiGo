import type { CapacitorConfig } from '@capacitor/cli'

const config: CapacitorConfig = {
  appId: 'com.kodigo.app',
  appName: 'Kodigo',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
  },
}

export default config
