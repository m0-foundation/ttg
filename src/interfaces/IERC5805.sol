// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IERC712 } from "./IERC712.sol";
import { IERC6372 } from "./IERC6372.sol";

// See https://eips.ethereum.org/EIPS/eip-5805

interface IERC5805 is IERC712, IERC6372 {
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    function DELEGATION_TYPEHASH() external view returns (bytes32 delegationTypehash);

    // This function returns the address to which the voting power of an account is currently delegated.
    // Note that if the delegate is address(0) then the voting power SHOULD NOT be checkpointed,
    // and it should not be possible to vote with it.
    function delegates(address account) external view returns (address delegatee);

    // This function changes the caller’s delegate, updating the vote delegation in the meantime.
    function delegate(address delegatee) external;

    // This function changes an account’s delegate using a signature, updating the vote delegation in the meantime.
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    // This function returns the current voting weight of an account. This corresponds to all the voting power
    // delegated to it at the moment this function is called.
    // As tokens delegated to address(0) should not be counted/snapshotted, getVotes(0) SHOULD always return 0.
    function getVotes(address account) external view returns (uint256 votePower);

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256 votePower);
}
