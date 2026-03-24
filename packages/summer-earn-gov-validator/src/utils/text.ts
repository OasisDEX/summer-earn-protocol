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
  cleanDescription: string
}

export function extractProposalMetadata(description: string): ProposalMetadata {
  if (!description) return { title: 'Untitled Proposal', displayId: null, cleanDescription: '' }

  const hasNewLineCharacters = description.includes('\n')
  // Split by newline or ###, then trim each segment
  const rawLines = hasNewLineCharacters ? description.split('\n') : description.split('###')
  const lines = rawLines.map((l) => l.trim()).filter(Boolean)

  let title = 'Untitled Proposal'
  let displayId: string | null = null
  let titleFound = false
  let startIndex = 0

  for (let i = 0; i < lines.length; i++) {
    const trimmedLine = lines[i]

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
      startIndex = i + 1
      break
    } else if (i === 0) {
      // If the first line doesn't start with #, but is short, treat it as a potential title
      if (trimmedLine.length < 150) {
        const idMatch = trimmedLine.match(/^([a-zA-Z0-9-.]+)(?::|\s+)(.*)$/)
        if (idMatch) {
          displayId = idMatch[1]
          title = idMatch[2].trim()
          titleFound = true
          startIndex = i + 1
          break
        }
      }
    }
  }

  // Fallback to first line if no clear title found
  if (!titleFound && lines.length > 0) {
    title = lines[0].slice(0, 100)
    startIndex = 1
  }

  // Construct clean description from the remaining lines
  const remainingLines = lines.slice(startIndex)
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
