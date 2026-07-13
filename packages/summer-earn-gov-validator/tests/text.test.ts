import { convertRawUrlsToMarkdown, extractProposalMetadata } from '@/utils/text'

describe('convertRawUrlsToMarkdown', () => {
  it('wraps a bare URL into a markdown link', () => {
    expect(convertRawUrlsToMarkdown('see https://example.com here')).toBe(
      'see [https://example.com](https://example.com) here',
    )
  })

  it('wraps multiple URLs independently', () => {
    const input = 'one https://a.com two https://b.com end'
    expect(convertRawUrlsToMarkdown(input)).toBe(
      'one [https://a.com](https://a.com) two [https://b.com](https://b.com) end',
    )
  })

  it('does not double-wrap a URL already inside a markdown link', () => {
    const input = '[click](https://example.com)'
    expect(convertRawUrlsToMarkdown(input)).toBe(input)
  })

  it('does not wrap URLs inside double-quoted HTML attributes', () => {
    const input = '<a href="https://example.com">x</a>'
    expect(convertRawUrlsToMarkdown(input)).toBe(input)
  })

  it('does not wrap URLs inside single-quoted HTML attributes', () => {
    const input = "<img src='https://example.com/x.png'>"
    expect(convertRawUrlsToMarkdown(input)).toBe(input)
  })

  it('returns the input unchanged when there are no URLs', () => {
    expect(convertRawUrlsToMarkdown('plain text, no links here.')).toBe(
      'plain text, no links here.',
    )
  })

  it('handles http (not just https)', () => {
    expect(convertRawUrlsToMarkdown('see http://example.com')).toBe(
      'see [http://example.com](http://example.com)',
    )
  })
})

describe('extractProposalMetadata', () => {
  it('returns the fallback metadata for an empty description', () => {
    expect(extractProposalMetadata('')).toEqual({
      title: 'Untitled Proposal',
      displayId: null,
      cleanDescription: '',
    })
  })

  it('extracts title and displayId from a markdown heading "SIP-123: Title"', () => {
    const desc = '# SIP-123: Add new fleet\n\nBody paragraph.'
    expect(extractProposalMetadata(desc)).toEqual({
      title: 'Add new fleet',
      displayId: 'SIP-123',
      cleanDescription: 'Body paragraph.',
    })
  })

  it('extracts title from a markdown heading without displayId', () => {
    // The regex /^([a-zA-Z0-9-.]+)(?::|\s+)(.*)$/ matches "Hello" as id and "world" as title
    // when the heading text is "Hello world" — so displayId is set to the first word.
    const desc = '# Hello world\n\nA description.'
    const result = extractProposalMetadata(desc)
    expect(result.displayId).toBe('Hello')
    expect(result.title).toBe('world')
    expect(result.cleanDescription).toBe('A description.')
  })

  it('strips surrounding brackets from the heading', () => {
    const desc = '# [SIP-9]: Bracketed title\n\nBody.'
    const result = extractProposalMetadata(desc)
    expect(result.displayId).toBe('SIP-9')
    expect(result.title).toBe('Bracketed title')
  })

  it('treats a short first line as a title when there is no heading', () => {
    const desc = 'SIP-7: Untitled hub action\n\nBody.'
    const result = extractProposalMetadata(desc)
    expect(result.displayId).toBe('SIP-7')
    expect(result.title).toBe('Untitled hub action')
    expect(result.cleanDescription).toBe('Body.')
  })

  it('falls back to truncated first line when the first line is too long and not a heading', () => {
    const longLine = 'x'.repeat(200)
    const desc = `${longLine}\nbody`
    const result = extractProposalMetadata(desc)
    expect(result.title.length).toBe(100)
    expect(result.title).toBe('x'.repeat(100))
    expect(result.displayId).toBeNull()
  })

  it("splits on '###' when the description has no newlines", () => {
    const desc = '# SIP-1: Inline title ### body chunk'
    const result = extractProposalMetadata(desc)
    expect(result.displayId).toBe('SIP-1')
    expect(result.title).toBe('Inline title')
    expect(result.cleanDescription).toBe('body chunk')
  })

  it('uses the original description as cleanDescription when only a title is present', () => {
    // No newlines → splits on "###"; the regex matches "Title" as displayId and "only" as title.
    // cleanDescription falls back to description.trim() because remainingLines is empty.
    const desc = '# Title only'
    const result = extractProposalMetadata(desc)
    expect(result.displayId).toBe('Title')
    expect(result.title).toBe('only')
    expect(result.cleanDescription).toBe(desc.trim())
  })

  it('removes a leading "***" horizontal-rule separator from cleanDescription', () => {
    const desc = '# Title\n\n*** A body line.'
    const result = extractProposalMetadata(desc)
    expect(result.cleanDescription.startsWith('***')).toBe(false)
  })

  it('preserves empty lines/newlines in the cleanDescription', () => {
    const desc = '# Title\n\nLine 1\n\nLine 2'
    const result = extractProposalMetadata(desc)
    expect(result.cleanDescription).toBe('Line 1\n\nLine 2')
  })

  it('keeps empty lines around tables and separators', () => {
    const desc = '# Title\n\nParagraph before separator.\n\n---\n\n### Section 2\n\nParagraph text.'
    const result = extractProposalMetadata(desc)
    expect(result.cleanDescription).toBe(
      'Paragraph before separator.\n\n---\n\n### Section 2\n\nParagraph text.',
    )
  })
})
