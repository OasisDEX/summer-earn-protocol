// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IAccessControlErrors {
    error CallerIsNotGovernor(address caller);
    error CallerIsNotKeeper(address caller);
    error CallerIsNotSuperKeeper(address caller);
    error CallerIsNotCommander(address caller);
    error CallerIsNotRaftOrCommander(address caller);
    error CallerIsNotRaft(address caller);
    error CallerIsNotAdmin(address caller);
    error CallerIsNotAuthorizedToBoard(address caller);
    error DirectGrantIsDisabled(address caller);
    error DirectRevokeIsDisabled(address caller);
    error InvalidAccessManagerAddress(address invalidAddress);
}
