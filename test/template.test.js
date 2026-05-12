import { describe, it, expect } from 'vitest'
import { Template } from '../index.js'

describe('Template', () => {
  it('renders empty string without variables', () => {
    expect(new Template('').render()).toBe('')
  })

  it('renders plain text without variables', () => {
    expect(new Template('foo').render()).toBe('foo')
  })

  it('evaluates ERB-style expressions', () => {
    expect(new Template('<%= 2 + 2 %>').render()).toBe('4')
  })

  it('renders empty string with unused variables', () => {
    expect(new Template('').render({ x: 42 })).toBe('')
  })

  it('renders named variable locals', () => {
    expect(new Template('<%= x %>').render({ x: 42 })).toBe('42')
  })
})
