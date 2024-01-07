// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IBatchGovernor, IGovernor, IZeroGovernor } from "../../IntegrationBaseSetup.t.sol";

contract SetZeroAndEmergencyThresholds_IntegrationTest is IntegrationBaseSetup {
    function test_zeroGovernorProposal_setZeroAndEmergencyThresholds() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory zeroThresholdCallDatas_ = new bytes[](1);
        zeroThresholdCallDatas_[0] = abi.encodeWithSelector(
            _zeroGovernor.setZeroProposalThresholdRatio.selector,
            5_000
        );

        bytes[] memory emergencyThresholdCallDatas_ = new bytes[](1);
        emergencyThresholdCallDatas_[0] = abi.encodeWithSelector(
            _zeroGovernor.setEmergencyProposalThresholdRatio.selector,
            7_000
        );

        string memory zeroThresholdDescription_ = "Update zero threshold";
        string memory emergencyThresholdDescription_ = "Update emergency threshold";

        _warpToNextEpoch();

        // Proposal to change zero threshold
        vm.prank(_dave);
        uint256 zeroProposalId_ = _zeroGovernor.propose(
            targets_,
            values_,
            zeroThresholdCallDatas_,
            zeroThresholdDescription_
        );

        // Proposal to change emergency threshold
        vm.prank(_dave);
        uint256 emergencyProposalId_ = _zeroGovernor.propose(
            targets_,
            values_,
            emergencyThresholdCallDatas_,
            emergencyThresholdDescription_
        );

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256[] memory proposalIds_ = new uint256[](2);
        proposalIds_[0] = zeroProposalId_;
        proposalIds_[1] = emergencyProposalId_;

        uint8[] memory supports_ = new uint8[](2);
        supports_[0] = yesSupport_;
        supports_[1] = yesSupport_;

        uint256 daveZeroWeight_ = _zeroToken.getVotes(_dave);

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVotes(proposalIds_, supports_), daveZeroWeight_);

        assertEq(uint256(_zeroGovernor.state(zeroProposalId_)), 4); // Succeeded
        assertEq(uint256(_zeroGovernor.state(emergencyProposalId_)), 4); // Succeeded

        vm.prank(_dave);
        _zeroGovernor.execute(
            targets_,
            values_,
            emergencyThresholdCallDatas_,
            keccak256(bytes(emergencyThresholdDescription_))
        );

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, zeroThresholdCallDatas_, keccak256(bytes(zeroThresholdDescription_)));

        assertEq(uint256(_zeroGovernor.state(zeroProposalId_)), 7); // Executed
        assertEq(uint256(_zeroGovernor.state(emergencyProposalId_)), 7); // Executed

        // Aftermath of the thresholds change
        assertEq(_emergencyGovernor.thresholdRatio(), 7_000);
        assertEq(_zeroGovernor.thresholdRatio(), 5_000);
    }
}
