export function convertRawUrlsToMarkdown(text: string): string {
  const urlRegex = /(https?:\/\/[^\s)\]"'<>]+)/g

  return text.replace(urlRegex, (url, match, offset, fullText) => {
    // Check context to avoid double-wrapping or breaking HTML
    const before = fullText.slice(Math.max(0, offset - 20), offset)

    // Skip if already in markdown link [text](url)
    if (before.includes('](')) {
      return url
    }

    // Skip if in an HTML attribute (src="url", href="url", etc.)
    if (before.includes('="') || before.includes("='")) {
      return url
    }

    return `[${url}](${url})`
  })
}

/**
 * Collapse proposal markdown into a single plain-text snippet for list cards.
 * Keeps prose; drops tables, code fences, and formatting markers.
 */
export function stripMarkdownForPreview(markdown: string): string {
  if (!markdown) return ''

  let text = markdown
    // Fenced code blocks
    .replace(/```[\s\S]*?```/g, ' ')
    // Images ![alt](src)
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    // Links [label](url) → label
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
    // Reference-style links [label][id] → label
    .replace(/\[([^\]]+)\]\[[^\]]*\]/g, '$1')
    // Inline code
    .replace(/`([^`]+)`/g, '$1')
    // Headings
    .replace(/^#{1,6}\s+/gm, '')
    // Bold / italic / strikethrough
    .replace(/(\*\*|__)(.*?)\1/g, '$2')
    .replace(/(\*|_)(.*?)\1/g, '$2')
    .replace(/~~(.*?)~~/g, '$1')
    // Blockquotes
    .replace(/^>\s?/gm, '')
    // Unordered / ordered list markers
    .replace(/^[\t ]*([-*+]|\d+\.)\s+/gm, '')
    // Horizontal rules
    .replace(/^(-{3,}|\*{3,}|_{3,})\s*$/gm, ' ')

  // Drop markdown table rows (multi-pipe lines and |---|---| separators)
  text = text
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim()
      if (!trimmed.includes('|')) return true
      if (/^\|?[\s:-]+\|[\s|:-]*$/.test(trimmed)) return false
      if ((trimmed.match(/\|/g) || []).length >= 2) return false
      return true
    })
    .join(' ')

  return text.replace(/\s+/g, ' ').trim()
}

export interface ProposalMetadata {
  title: string
  displayId: string | null
  cleanDescription: string
}

export function extractProposalMetadata(description: string): ProposalMetadata {
  if (!description) return { title: 'Untitled Proposal', displayId: null, cleanDescription: '' }

  const hasNewLineCharacters = description.includes('\n')
  // Split by newline or ###, then trim each segment
  const rawLines = hasNewLineCharacters ? description.split('\n') : description.split('###')
  const trimmedLines = rawLines.map((l) => l.trim())
  const nonEmptyLinesWithIndices = trimmedLines
    .map((l, idx) => ({ content: l, originalIndex: idx }))
    .filter((item) => item.content !== '')

  let title = 'Untitled Proposal'
  let displayId: string | null = null
  let titleFound = false
  let startIndex = 0

  for (let i = 0; i < nonEmptyLinesWithIndices.length; i++) {
    const { content: trimmedLine, originalIndex } = nonEmptyLinesWithIndices[i]

    // If it's a heading, it's likely the title
    if (trimmedLine.startsWith('#')) {
      // Remove all leading # and whitespace
      const fullTitle = trimmedLine.replace(/^#+\s*/, '').trim()
      // remove all [ and ]
      const fullTitleWithoutBrackets = fullTitle.replace(/\[|\]/g, '').trim()

      const idMatch = fullTitleWithoutBrackets.match(/^([a-zA-Z0-9-.]+)(?::|\s+)(.*)$/)
      if (idMatch) {
        displayId = idMatch[1]
        title = idMatch[2].trim()
      } else {
        title = fullTitleWithoutBrackets
      }
      titleFound = true
      startIndex = originalIndex + 1
      break
    } else if (i === 0) {
      // If the first non-empty line doesn't start with #, but is short, treat it as a potential title
      if (trimmedLine.length < 150) {
        const idMatch = trimmedLine.match(/^([a-zA-Z0-9-.]+)(?::|\s+)(.*)$/)
        if (idMatch) {
          displayId = idMatch[1]
          title = idMatch[2].trim()
          titleFound = true
          startIndex = originalIndex + 1
          break
        }
      }
    }
  }

  // Fallback to first non-empty line if no clear title found
  if (!titleFound && nonEmptyLinesWithIndices.length > 0) {
    const firstNonEmpty = nonEmptyLinesWithIndices[0]
    title = firstNonEmpty.content.slice(0, 100)
    startIndex = firstNonEmpty.originalIndex + 1
  }

  // Construct clean description from the remaining lines of rawLines (preserving empty lines)
  const remainingLines = rawLines.slice(startIndex)
  let cleanDescription = remainingLines
    .join(hasNewLineCharacters ? '\n' : ' ')
    .trim()
    .replace(/^#+\s*/, '') // Remove redundant header from body start (e.g. ### Overview)
    .replace(/^\*\*\*\s*/, '') // Remove horizontal rule separators
    .trim()

  // If cleanDescription is empty (e.g. description was only a title), use original truncated
  if (!cleanDescription) {
    cleanDescription = description.trim()
  }

  return { title, displayId, cleanDescription }
}
