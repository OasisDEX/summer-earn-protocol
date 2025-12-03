import { RaftUpdated } from '../../generated/ConfigManager/ConfigManager'
import { Raft as RaftTemplate } from '../../generated/templates'
import { Raft } from '../../generated/schema'

export function handleRaftUpdated(event: RaftUpdated): void {
  let raft = new Raft(event.params.newRaft.toHex())
  raft.address = event.params.newRaft.toHex()
  raft.save()
  RaftTemplate.create(event.params.newRaft)
}
