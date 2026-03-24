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

export interface ProposalMetadata {
  title: string
  displayId: string | null
}

export function extractProposalMetadata(description: string): ProposalMetadata {
  if (!description) return { title: 'Untitled Proposal', displayId: null }

  const lines = description.split('\n')
  for (const line of lines) {
    const trimmedLine = line.trim()
    if (trimmedLine.startsWith('#')) {
      // Remove all leading # and whitespace
      const fullTitle = trimmedLine.replace(/^#+\s*/, '').trim()
      // remove all [ and ]
      const fullTitleWithoutBrackets = fullTitle.replace(/\[|\]/g, '').trim()
      // // remove leading [ and following ]
      // Try to extract an ID pattern like "SIP-2-57" or "123"
      // Look for a pattern at the beginning: alphanumeric characters with optional dashes/dots followed by a colon or space
      // Pattern: start, then 1-15 alphanumeric/dash/dot chars, then (colon OR space), then the rest
      const idMatch = fullTitleWithoutBrackets.match(/^([a-zA-Z0-9-.]+)(?::|\s+)(.*)$/)
      if (idMatch) {
        return { displayId: idMatch[1], title: idMatch[2].trim() }
      }

      // If no clear ID pattern, use the whole thing as title
      return { title: fullTitleWithoutBrackets, displayId: null }
    }
  }

  // Fallback to first line if no # found
  return { title: description.split('\n')[0].slice(0, 100), displayId: null }
}
