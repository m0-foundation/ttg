// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { EmergencyGovernor } from "../../src/EmergencyGovernor.sol";

contract EmergencyGovernorHarness is EmergencyGovernor {
    constructor(
        address voteToken_,
        address zeroGovernor_,
        address registrar_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) EmergencyGovernor(voteToken_, zeroGovernor_, registrar_, standardGovernor_, thresholdRatio_) {}

    function revertIfInvalidCalldata(bytes memory callData_) external pure {
        _revertIfInvalidCalldata(callData_);
    }
}
