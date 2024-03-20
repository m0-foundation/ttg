// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { EmergencyGovernor } from "../../src/EmergencyGovernor.sol";

contract EmergencyGovernorHarness is EmergencyGovernor {
    constructor(
        address voteToken_,
        address zeroGovernor_,
        address registrar_,
        address standardGovernor_,
        uint256 quorumNumerator_
    ) EmergencyGovernor(voteToken_, zeroGovernor_, registrar_, standardGovernor_, quorumNumerator_) {}

    function revertIfInvalidCalldata(bytes memory callData_) external pure {
        _revertIfInvalidCalldata(callData_);
    }
}
