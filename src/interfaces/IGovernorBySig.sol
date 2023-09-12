// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IGovernor } from "./IGovernor.sol";
import { IERC712 } from "./IERC712.sol";

interface IGovernorBySig is IERC712, IGovernor {
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 weight);

    function BALLOT_TYPEHASH() external view returns (bytes32 ballotTypehash);

    function name() external view returns (string memory name);
}
