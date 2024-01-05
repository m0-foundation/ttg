// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IBatchGovernor, IGovernor, IZeroGovernor } from "../../IntegrationBaseSetup.t.sol";

contract SetCashToken_IntegrationTest is IntegrationBaseSetup {
    function test_zeroGovernorProposal_setCashToken() external {
        address[] memory targets_ = new address[](1);
        targets_[0] = address(_zeroGovernor);

        uint256[] memory values_ = new uint256[](1);

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(
            _zeroGovernor.setCashToken.selector,
            address(_cashToken2),
            _standardProposalFee * 2
        );

        string memory description_ = "Update cash token";

        _warpToNextEpoch();

        uint256 voteStart_ = _currentEpoch();
        uint256 proposalId_ = _hashProposal(callDatas_[0], voteStart_, address(_zeroGovernor));

        vm.prank(_dave);
        _zeroGovernor.propose(targets_, values_, callDatas_, description_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 1); // Active

        uint8 yesSupport_ = uint8(IBatchGovernor.VoteType.Yes);

        uint256 daveZeroWeight_ = _zeroToken.getVotes(_dave);

        vm.prank(_dave);
        assertEq(_zeroGovernor.castVote(proposalId_, yesSupport_), daveZeroWeight_);

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 4); // Succeeded

        vm.prank(_dave);
        _zeroGovernor.execute(targets_, values_, callDatas_, keccak256(bytes(description_)));

        assertEq(uint256(_zeroGovernor.state(proposalId_)), 7); // Executed

        // Aftermath of the cash token change
        assertEq(_powerToken.cashToken(), address(_cashToken1)); // no change yet
        assertEq(_standardGovernor.cashToken(), address(_cashToken2));
        assertEq(_standardGovernor.proposalFee(), _standardProposalFee * 2);

        _warpToNextEpoch();

        assertEq(_standardGovernor.cashToken(), address(_cashToken2));
    }
}
