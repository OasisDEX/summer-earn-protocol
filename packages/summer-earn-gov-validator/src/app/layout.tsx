import { Providers } from '../components/Providers'

import '@/styles/globals.scss'

export const metadata = {
  title: 'Summer DAO - Governance Validator',
  description: 'Governance proposals for the Summer Earn Protocol',
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
