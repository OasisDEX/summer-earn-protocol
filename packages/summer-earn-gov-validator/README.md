# Summer Earn Governance Validator

A Next.js application for validating governance proposals for the Summer Earn Protocol.

## Features

- Form for submitting governance proposal data
- Input validation for ETH addresses, values, and calldatas
- Dynamic form fields for multiple targets, values, and calldatas
- Modern UI with SCSS styling

## Getting Started

First, install the dependencies:

```bash
pnpm install
```

Then, run the development server:

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Form Fields

The form accepts the following inputs:

- **Targets**: Array of Ethereum addresses
- **Values**: Array of integer values (in wei)
- **Calldatas**: Array of bytes data
- **Description**: String description of the proposal

## Development

- Built with Next.js 14
- Uses TypeScript for type safety
- Styled with SCSS modules
- Form validation and state management with React hooks 