// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IBatchGovernor } from "../../IntegrationBaseSetup.t.sol";

contract SetZeroAndEmergencyQuorums_IntegrationTest is IntegrationBaseSetup {
    function test_zeroGovernorProposal_setZeroAndEmergencyQuorums() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory zeroQuorumCallDatas_ = new bytes[](1);
        zeroQuorumCallDatas_[0] = abi.encodeWithSelector(_zeroGovernor.setZeroProposalQuorumNumerator.selector, 5_000);

        bytes[] memory emergencyQuorumCallDatas_ = new bytes[](1);
        emergencyQuorumCallDatas_[0] = abi.encodeWithSelector(
            _zeroGovernor.setEmergencyProposalQuorumNumerator.selector,
            7_000
        );

        string memory zeroQuorumDescription_ = "Update zero quorum numerator";
        string memory emergencyQuorumDescription_ = "Update emergency quorum numerator";

        _warpToNextEpoch();

        // Proposal to change zero quorum
        vm.prank(_dave);
        uint256 zeroProposalId_ = _zeroGovernor.propose(
            targets_,
            values_,
            zeroQuorumCallDatas_,
            zeroQuorumDescription_
        );

        // Proposal to change emergency quorum
        vm.prank(_dave);
        uint256 emergencyProposalId_ = _zeroGovernor.propose(
            targets_,
            values_,
            emergencyQuorumCallDatas_,
            emergencyQuorumDescription_
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
            emergencyQuorumCallDatas_,
            keccak256(bytes(emergencyQuorumDescription_))
        );

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, zeroQuorumCallDatas_, keccak256(bytes(zeroQuorumDescription_)));

        assertEq(uint256(_zeroGovernor.state(zeroProposalId_)), 7); // Executed
        assertEq(uint256(_zeroGovernor.state(emergencyProposalId_)), 7); // Executed

        // Aftermath of the quorums change
        assertEq(_emergencyGovernor.quorumNumerator(), 7_000);
        assertEq(_zeroGovernor.quorumNumerator(), 5_000);
    }
}
