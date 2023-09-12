// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import { IRegistrar } from "../../src/registrar/IRegistrar.sol";

// import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";

// contract Registrar_ChangeConfig is SPOGBaseTest {
//     function test_updateConfig_notGovernor() public {
//         vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
//         registrar.updateConfig("someKey", "someValue");
//     }

//     function test_updateConfig() public {
//         vm.prank(address(governor));
//         registrar.updateConfig("someKey", "someValue");

//         assertEq(registrar.get("someKey"), "someValue");
//     }

//     function test_updateConfig_multiple() public {
//         vm.startPrank(address(governor));
//         registrar.updateConfig("someKey1", "someValue1");
//         registrar.updateConfig("someKey2", "someValue2");
//         registrar.updateConfig("someKey3", "someValue3");
//         vm.stopPrank();

//         bytes32[] memory keys = new bytes32[](3);
//         keys[0] = "someKey1";
//         keys[1] = "someKey2";
//         keys[2] = "someKey3";

//         bytes32[] memory values = registrar.get(keys);

//         assertEq(values[0], "someValue1");
//         assertEq(values[1], "someValue2");
//         assertEq(values[2], "someValue3");
//     }
// }
