// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC712 } from "../../../lib/common/src/interfaces/IERC712.sol";

import { IGovernor } from "./IGovernor.sol";

interface IGovernorBySig is IERC712, IGovernor {
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        address voter,
        bytes memory signature
    ) external returns (uint256 weight);

    function castVoteWithReasonBySig(
        uint256 proposalId,
        uint8 support,
        string calldata reason,
        address voter,
        bytes memory signature
    ) external returns (uint256 weight);

    function BALLOT_TYPEHASH() external pure returns (bytes32 typehash);

    function name() external view returns (string memory name);
}
