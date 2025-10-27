export const MESSAGE_TYPES = {
  STATE_READ: 2,
  GENERAL_MESSAGE: 3,
} as const

export type MessageType = (typeof MESSAGE_TYPES)[keyof typeof MESSAGE_TYPES]
