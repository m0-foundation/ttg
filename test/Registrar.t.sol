// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { Registrar } from "../src/Registrar.sol";

import { MockBootstrapToken, MockPowerTokenDeployer, MockDualGovernorDeployer, MockDualGovernor } from "./utils/Mocks.sol";

contract RegistrarTests is Test {
    address internal _cashToken = makeAddr("cashToken");
    address internal _zeroToken = makeAddr("zeroToken");
    address internal _account1 = makeAddr("account1");
    address internal _account2 = makeAddr("account2");
    address internal _account3 = makeAddr("account3");

    Registrar internal _registrar;
    MockBootstrapToken internal _bootstrapToken;
    MockPowerTokenDeployer internal _powerTokenDeployer;
    MockDualGovernorDeployer internal _governorDeployer;
    MockDualGovernor internal _governor;

    function setUp() external {
        _bootstrapToken = new MockBootstrapToken();
        _powerTokenDeployer = new MockPowerTokenDeployer();
        _governorDeployer = new MockDualGovernorDeployer();
        _governor = new MockDualGovernor();
        _governorDeployer.setNextDeploy(address(_governor));

        _governor.setZeroToken(_zeroToken);

        _registrar = new Registrar(
            address(_governorDeployer),
            address(_powerTokenDeployer),
            address(_bootstrapToken),
            _cashToken
        );
    }

    function test_initialState() external {
        assertEq(_registrar.governor(), address(_governor));
        assertEq(_registrar.governorDeployer(), address(_governorDeployer));
        assertEq(_registrar.powerTokenDeployer(), address(_powerTokenDeployer));
        assertEq(_registrar.zeroToken(), address(_zeroToken));
    }

    function test_updateConfig_notGovernor() external {
        vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
        _registrar.updateConfig("someKey", "someValue");
    }

    function test_updateConfig() external {
        assertEq(_registrar.get("someKey"), bytes32(0));

        vm.prank(address(_governor));
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

        vm.startPrank(address(_governor));
        _registrar.updateConfig("someKey1", "someValue1");
        _registrar.updateConfig("someKey2", "someValue2");
        _registrar.updateConfig("someKey3", "someValue3");
        vm.stopPrank();

        values_ = _registrar.get(keys_);

        assertEq(values_[0], "someValue1");
        assertEq(values_[1], "someValue2");
        assertEq(values_[2], "someValue3");
    }

    function test_addToList_notGovernor() external {
        vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
        _registrar.addToList("someList", _account1);
    }

    function test_addToList() external {
        assertFalse(_registrar.listContains("someList", _account1));

        vm.prank(address(_governor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));
    }

    function test_addToList_multiple() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertFalse(_registrar.listContains("someList", accounts_));

        vm.startPrank(address(_governor));
        _registrar.addToList("someList", _account1);
        _registrar.addToList("someList", _account2);
        _registrar.addToList("someList", _account3);
        vm.stopPrank();

        assertTrue(_registrar.listContains("someList", accounts_));
    }

    function test_removeFromList_notGovernor() external {
        vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
        _registrar.removeFromList("someList", _account1);
    }

    function test_removeFromList() external {
        vm.prank(address(_governor));
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));

        vm.prank(address(_governor));
        _registrar.removeFromList("someList", _account1);

        assertFalse(_registrar.listContains("someList", _account1));
    }

    function test_removeFromList_multiple() external {
        vm.startPrank(address(_governor));
        _registrar.addToList("someList", _account1);
        _registrar.addToList("someList", _account2);
        _registrar.addToList("someList", _account3);
        vm.stopPrank();

        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertTrue(_registrar.listContains("someList", accounts_));

        vm.startPrank(address(_governor));
        _registrar.removeFromList("someList", _account1);
        _registrar.removeFromList("someList", _account2);
        _registrar.removeFromList("someList", _account3);
        vm.stopPrank();

        assertFalse(_registrar.listContains("someList", accounts_));
    }

    function test_reset_notGovernor() external {
        vm.expectRevert(IRegistrar.CallerIsNotGovernor.selector);
        _registrar.reset();
    }

    function test_reset() external {
        address newGovernor_ = makeAddr("newGovernor");

        _governorDeployer.setNextDeploy(newGovernor_);

        vm.prank(address(_governor));
        _registrar.reset();

        assertEq(_registrar.governor(), newGovernor_);
    }
}
