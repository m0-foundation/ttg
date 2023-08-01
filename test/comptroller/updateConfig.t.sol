// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IComptroller } from "../../src/comptroller/IComptroller.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

contract Comptroller_ChangeConfig is SPOGBaseTest {
    function test_updateConfig_notGovernor() public {
        vm.expectRevert(IComptroller.CallerIsNotGovernor.selector);
        comptroller.updateConfig("someKey", "someValue");
    }

    function test_updateConfig() public {
        vm.prank(address(governor));
        comptroller.updateConfig("someKey", "someValue");

        assertEq(comptroller.get("someKey"), "someValue");
    }

    function test_updateConfig_multiple() public {
        vm.startPrank(address(governor));
        comptroller.updateConfig("someKey1", "someValue1");
        comptroller.updateConfig("someKey2", "someValue2");
        comptroller.updateConfig("someKey3", "someValue3");
        vm.stopPrank();

        bytes32[] memory keys = new bytes32[](3);
        keys[0] = "someKey1";
        keys[1] = "someKey2";
        keys[2] = "someKey3";

        bytes32[] memory values = comptroller.get(keys);

        assertEq(values[0], "someValue1");
        assertEq(values[1], "someValue2");
        assertEq(values[2], "someValue3");
    }
}
