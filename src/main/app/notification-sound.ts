import { existsSync } from 'node:fs'

export function playNotificationSound(
  beep: () => void,
  platform: NodeJS.Platform = process.platform,
  env: NodeJS.ProcessEnv = process.env,
  fsExistsSync = existsSync,
): void {
  if (platform === 'linux' && (env.WSL_DISTRO_NAME || env.WSL_INTEROP || fsExistsSync('/.dockerenv'))) return
  beep()
}
