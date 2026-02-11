import type { Metadata } from 'next'
import { Manrope } from 'next/font/google'
import './globals.css'
import { Providers } from './providers'

const manrope = Manrope({
  subsets: ['latin'],
  variable: '--font-manrope',
})

export const metadata: Metadata = {
  title: 'Oracle Health Overview | Summer Earn RWA Dashboard',
  description:
    'Real-time monitoring and management of Real-World Asset price oracles. Compare on-chain data with verified off-chain sources.',
  openGraph: {
    title: 'Summer Earn RWA Oracle Dashboard',
    description:
      'Monitor DeFi RWA oracle health and price deviation across Base, Arbitrum, and Ethereum.',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className="light">
      <head>
        <link
          href="https://fonts.googleapis.com/icon?family=Material+Icons+Round"
          rel="stylesheet"
        />
      </head>
      <body className={`${manrope.variable} font-sans antialiased`}>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
