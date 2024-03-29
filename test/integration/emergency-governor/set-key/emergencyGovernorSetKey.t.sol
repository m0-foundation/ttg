// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import { IntegrationBaseSetup, IEmergencyGovernor } from "../../IntegrationBaseSetup.t.sol";

contract EmergencyGovernorSetKey_IntegrationTest is IntegrationBaseSetup {
    function test_emergencyGovernorSetKey() external {
        IEmergencyGovernor emergencyGovernor_ = IEmergencyGovernor(_registrar.emergencyGovernor());

        address[] memory targets_ = new address[](1);
        targets_[0] = address(emergencyGovernor_);

        uint256[] memory values_ = new uint256[](1);

        bytes32 key_ = "TEST_KEY";
        bytes32 value_ = "TEST_VALUE";

        bytes[] memory callDatas_ = new bytes[](1);
        callDatas_[0] = abi.encodeWithSelector(emergencyGovernor_.setKey.selector, key_, value_);

        string memory description_ = "Emergency update config key/value pair";

        vm.prank(_alice);
        uint256 proposalId_ = emergencyGovernor_.propose(targets_, values_, callDatas_, description_);

        vm.prank(_alice);
        assertEq(emergencyGovernor_.castVote(proposalId_, 1), 550_000);

        vm.prank(_bob);
        assertEq(emergencyGovernor_.castVote(proposalId_, 1), 250_000);

        emergencyGovernor_.execute(targets_, values_, callDatas_, bytes32(0));

        assertEq(_registrar.get(key_), value_);
    }
}
