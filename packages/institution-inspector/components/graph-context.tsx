'use client'

import { createContext, useContext } from 'react'

export const ChainIdContext = createContext<number>(0)
export const useChainId = () => useContext(ChainIdContext)
