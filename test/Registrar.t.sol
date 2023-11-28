// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { Registrar } from "../src/Registrar.sol";

import { MockEmergencyGovernorDeployer, MockPowerTokenDeployer } from "./utils/Mocks.sol";
import { MockStandardGovernorDeployer, MockZeroGovernor } from "./utils/Mocks.sol";

contract RegistrarTests is Test {
    address internal _account1 = makeAddr("account1");
    address internal _account2 = makeAddr("account2");
    address internal _account3 = makeAddr("account3");
    address internal _emergencyGovernor = makeAddr("emergencyGovernor");
    address internal _powerToken = makeAddr("powerToken");
    address internal _standardGovernor = makeAddr("standardGovernor");
    address internal _vault = makeAddr("vault");
    address internal _zeroToken = makeAddr("zeroToken");

    Registrar internal _registrar;

    MockEmergencyGovernorDeployer internal _emergencyGovernorDeployer;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockStandardGovernorDeployer internal _standardGovernorDeployer;
    MockZeroGovernor internal _zeroGovernor;

    function setUp() external {
        _emergencyGovernorDeployer = new MockEmergencyGovernorDeployer();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _standardGovernorDeployer = new MockStandardGovernorDeployer();
        _zeroGovernor = new MockZeroGovernor();

        _emergencyGovernorDeployer.setLastDeploy(_emergencyGovernor);

        _powerTokenDeployer.setLastDeploy(_powerToken);

        _standardGovernorDeployer.setLastDeploy(_standardGovernor);
        _standardGovernorDeployer.setVault(_vault);

        _zeroGovernor.setEmergencyGovernorDeployer(address(_emergencyGovernorDeployer));
        _zeroGovernor.setPowerTokenDeployer(address(_powerTokenDeployer));
        _zeroGovernor.setStandardGovernorDeployer(address(_standardGovernorDeployer));
        _zeroGovernor.setVoteToken(_zeroToken);

        _registrar = new Registrar(address(_zeroGovernor));
    }

    function test_initialState() external {
        assertEq(_registrar.standardGovernorDeployer(), address(_standardGovernorDeployer));
        assertEq(_registrar.emergencyGovernorDeployer(), address(_emergencyGovernorDeployer));
        assertEq(_registrar.powerTokenDeployer(), address(_powerTokenDeployer));
        assertEq(_registrar.zeroGovernor(), address(_zeroGovernor));
        assertEq(_registrar.zeroToken(), _zeroToken);
        assertEq(_registrar.vault(), _vault);
        assertEq(_registrar.standardGovernor(), address(_standardGovernor));
        assertEq(_registrar.emergencyGovernor(), address(_emergencyGovernor));
        assertEq(_registrar.powerToken(), _powerToken);
    }

    function test_updateConfig_notStandardOrEmergencyGovernor() external {
        vm.expectRevert(IRegistrar.NotStandardOrEmergencyGovernor.selector);
        _registrar.updateConfig("someKey", "someValue");
    }

    function test_updateConfig_fromStandardGovernor() external {
        assertEq(_registrar.get("someKey"), bytes32(0));

        vm.prank(address(_standardGovernor));
        _registrar.updateConfig("someKey", "someValue");

        assertEq(_registrar.get("someKey"), "someValue");
    }

    function test_updateConfig_fromEmergencyGovernor() external {
        assertEq(_registrar.get("someKey"), bytes32(0));

        vm.prank(address(_emergencyGovernor));
        _registrar.updateConfig("someKey", "someValue");

        assertEq(_registrar.get("someKey"), "someValue");
    }

    function test_updateConfig_multiple() external {
        bytes32[] memory keys_ = new bytes32[](3);
        keys_[0] = "someKey1";
        keys_[1] = "someKey2";
        keys_[2] = "someKey3";

        bytes32[] memory values_ = _registrar.get(keys_);

        assertEq(values_[0], bytes32(0));
        assertEq(values_[1], bytes32(0));
        assertEq(values_[2], bytes32(0));

        vm.startPrank(address(_standardGovernor));
        _registrar.updateConfig("someKey1", "someValue1");
        _registrar.updateConfig("someKey2", "someValue2");
        _registrar.updateConfig("someKey3", "someValue3");
        vm.stopPrank();

        values_ = _registrar.get(keys_);

        assertEq(values_[0], "someValue1");
        assertEq(values_[1], "someValue2");
        assertEq(values_[2], "someValue3");
    }

    function test_addToList_notStandardOrEmergencyGovernor() external {
        vm.expectRevert(IRegistrar.NotStandardOrEmergencyGovernor.selector);
        _registrar.addToList("someList", _account1);
    }

    function test_addToList_fromStandardGovernor() external {
        assertFalse(_registrar.listContains("someList", _account1));

        vm.prank(address(_standardGovernor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));
    }

    function test_addToList_fromEmergencyGovernor() external {
        assertFalse(_registrar.listContains("someList", _account1));

        vm.prank(address(_emergencyGovernor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));
    }

    function test_addToList_multiple() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertFalse(_registrar.listContains("someList", accounts_));

        vm.startPrank(address(_standardGovernor));
        _registrar.addToList("someList", _account1);
        _registrar.addToList("someList", _account2);
        _registrar.addToList("someList", _account3);
        vm.stopPrank();

        assertTrue(_registrar.listContains("someList", accounts_));
    }

    function test_removeFromList_notStandardOrEmergencyGovernor() external {
        vm.expectRevert(IRegistrar.NotStandardOrEmergencyGovernor.selector);
        _registrar.removeFromList("someList", _account1);
    }

    function test_removeFromList_fromStandardGovernor() external {
        vm.prank(address(_standardGovernor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));

        vm.prank(address(_standardGovernor));
        _registrar.removeFromList("someList", _account1);

        assertFalse(_registrar.listContains("someList", _account1));
    }

    function test_removeFromList_fromEmergencyGovernor() external {
        vm.prank(address(_emergencyGovernor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));

        vm.prank(address(_emergencyGovernor));
        _registrar.removeFromList("someList", _account1);

        assertFalse(_registrar.listContains("someList", _account1));
    }

    function test_removeFromList_multiple() external {
        vm.startPrank(address(_standardGovernor));
        _registrar.addToList("someList", _account1);
        _registrar.addToList("someList", _account2);
        _registrar.addToList("someList", _account3);
        vm.stopPrank();

        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertTrue(_registrar.listContains("someList", accounts_));

        vm.startPrank(address(_standardGovernor));
        _registrar.removeFromList("someList", _account1);
        _registrar.removeFromList("someList", _account2);
        _registrar.removeFromList("someList", _account3);
        vm.stopPrank();

        assertFalse(_registrar.listContains("someList", accounts_));
    }
}
