import '@/styles/globals.scss'

export const metadata = {
  title: 'Summer Earn Governance Validator',
  description: 'Validate governance proposals for Summer Earn Protocol',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
