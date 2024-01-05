// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { ZeroGovernor } from "../../src/ZeroGovernor.sol";

contract ZeroGovernorHarness is ZeroGovernor {
    constructor(
        address voteToken_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        uint16 emergencyProposalThresholdRatio_,
        uint16 zeroProposalThresholdRatio_,
        address[] memory allowedCashTokens_
    )
        ZeroGovernor(
            voteToken_,
            emergencyGovernorDeployer_,
            powerTokenDeployer_,
            standardGovernorDeployer_,
            bootstrapToken_,
            standardProposalFee_,
            emergencyProposalThresholdRatio_,
            zeroProposalThresholdRatio_,
            allowedCashTokens_
        )
    {}

    function revertIfInvalidCalldata(bytes memory callData_) external pure {
        _revertIfInvalidCalldata(callData_);
    }
}
