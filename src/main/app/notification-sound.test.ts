import { describe, expect, it, vi } from 'vitest'
import { playNotificationSound } from './notification-sound'

describe('playNotificationSound', () => {
  it.each([
    { WSL_DISTRO_NAME: 'Ubuntu' },
    { WSL_INTEROP: '/run/WSL/123_interop' },
  ])('does not invoke Electron native beep on WSL', (env) => {
    const beep = vi.fn()

    playNotificationSound(beep, 'linux', env)

    expect(beep).not.toHaveBeenCalled()
  })

  it('invokes Electron native beep on native Linux', () => {
    const beep = vi.fn()

    playNotificationSound(beep, 'linux', {}, () => false)

    expect(beep).toHaveBeenCalledOnce()
  })

  it('does not invoke Electron native beep in Docker', () => {
    const beep = vi.fn()

    playNotificationSound(beep, 'linux', {}, () => true)

    expect(beep).not.toHaveBeenCalled()
  })

  it('invokes Electron native beep on macOS', () => {
    const beep = vi.fn()

    playNotificationSound(beep, 'darwin', { WSL_DISTRO_NAME: 'Ubuntu' })

    expect(beep).toHaveBeenCalledOnce()
  })
})
