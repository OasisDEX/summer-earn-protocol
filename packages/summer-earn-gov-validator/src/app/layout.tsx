import '@/styles/globals.scss'
import { Providers } from '../components/Providers'

export const metadata = {
  title: 'Summer Earn Governance Validator',
  description: 'Validate governance proposals for Summer Earn Protocol',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
