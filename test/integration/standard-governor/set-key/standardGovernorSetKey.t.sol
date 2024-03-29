// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IStandardGovernor } from "../../IntegrationBaseSetup.t.sol";

contract StandardGovernorSetKey_IntegrationTest is IntegrationBaseSetup {
    function test_standardGovernorSetKey() external {
        IStandardGovernor standardGovernor_ = IStandardGovernor(_registrar.standardGovernor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(standardGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes32 key_ = "TEST_KEY";
        bytes32 value_ = "TEST_VALUE";

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(standardGovernor_.setKey.selector, key_, value_);

        string memory description_ = "Update config key/value pair";

        uint256 daveBalanceBefore_ = _cashToken1.balanceOf(_dave);
        uint256 proposalFee_ = standardGovernor_.proposalFee();

        vm.prank(_dave);
        _cashToken1.approve(address(standardGovernor_), proposalFee_);

        vm.prank(_dave);
        uint256 proposalId_ = standardGovernor_.propose(targets_, values_, callDatas_, description_);

        assertEq(_cashToken1.balanceOf(_dave), daveBalanceBefore_ - proposalFee_);
        assertEq(_cashToken1.balanceOf(address(standardGovernor_)), proposalFee_);

        _warpToNextVoteEpoch();

        vm.prank(_alice);
        uint256 weight_ = standardGovernor_.castVote(proposalId_, 1);

        assertEq(weight_, 550_000);

        _warpToNextTransferEpoch();

        standardGovernor_.execute(targets_, values_, callDatas_, bytes32(0));

        assertEq(_registrar.get(key_), value_);

        assertEq(_cashToken1.balanceOf(_dave), daveBalanceBefore_);
        assertEq(_cashToken1.balanceOf(address(standardGovernor_)), 0);
    }
}
