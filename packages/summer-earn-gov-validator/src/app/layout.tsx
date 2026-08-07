import type { Metadata } from 'next'

import { Providers } from '../components/Providers'

import '@/styles/globals.scss'

export const metadata: Metadata = {
  title: 'Summer.fi DAO | Governance Validator',
  description: 'Participate in the Lazy Summer DAO. Validate, review, and vote on governance proposals shaping the future of the Summer Earn Protocol.',
  openGraph: {
    title: 'Summer.fi DAO | Governance Validator',
    description: 'Participate in the Lazy Summer DAO. Validate, review, and vote on governance proposals shaping the future of the Summer Earn Protocol.',
    url: 'https://vote.summer.fi',
    siteName: 'Summer.fi DAO',
    images: [
      {
        url: 'https://summer.fi/img/branding/dot-dark.svg',
        width: 1200,
        height: 630,
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Summer.fi DAO | Governance Validator',
    description: 'Participate in the Lazy Summer DAO. Validate, review, and vote on governance proposals shaping the future of the Summer Earn Protocol.',
    creator: '@summerfinance_',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <head>
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined:wght,FILL@100..700,0..1&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="bg-background text-on-surface font-body min-h-screen">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
