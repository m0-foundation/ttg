// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.26;

import { Test } from "../lib/forge-std/src/Test.sol";

import { IRegistrar } from "../src/interfaces/IRegistrar.sol";

import { Registrar } from "../src/Registrar.sol";

contract RegistrarTests is Test {
    address internal _account1 = makeAddr("account1");
    address internal _account2 = makeAddr("account2");
    address internal _account3 = makeAddr("account3");
    address internal _portal = makeAddr("portal");

    Registrar internal _registrar;

    function setUp() external {
        _registrar = new Registrar(_portal);
    }

    /* ============ initial state ============ */
    function test_initialState() external {
        assertEq(_registrar.portal(), _portal);
    }

    /* ============ constructor ============ */
    function test_constructor_zeroPortal() external {
        vm.expectRevert(IRegistrar.ZeroPortal.selector);
        new Registrar(address(0));
    }

    /* ============ setKey ============ */
    function test_setKey_notPortal() external {
        vm.expectRevert(IRegistrar.NotPortal.selector);
        _registrar.setKey("someKey", "someValue");
    }

    function test_setKey() external {
        assertEq(_registrar.get("someKey"), bytes32(0));

        vm.expectEmit();
        emit IRegistrar.KeySet("someKey", "someValue");

        vm.prank(_portal);
        _registrar.setKey("someKey", "someValue");

        assertEq(_registrar.get("someKey"), "someValue");
    }

    function test_setKey_multiple() external {
        bytes32[] memory keys_ = new bytes32[](3);
        keys_[0] = "someKey1";
        keys_[1] = "someKey2";
        keys_[2] = "someKey3";

        bytes32[] memory values_ = _registrar.get(keys_);

        assertEq(values_[0], bytes32(0));
        assertEq(values_[1], bytes32(0));
        assertEq(values_[2], bytes32(0));

        vm.expectEmit();
        emit IRegistrar.KeySet("someKey1", "someValue1");

        vm.prank(_portal);
        _registrar.setKey("someKey1", "someValue1");

        vm.expectEmit();
        emit IRegistrar.KeySet("someKey2", "someValue2");

        vm.prank(_portal);
        _registrar.setKey("someKey2", "someValue2");

        vm.expectEmit();
        emit IRegistrar.KeySet("someKey3", "someValue3");

        vm.prank(_portal);
        _registrar.setKey("someKey3", "someValue3");

        values_ = _registrar.get(keys_);

        assertEq(values_[0], "someValue1");
        assertEq(values_[1], "someValue2");
        assertEq(values_[2], "someValue3");
    }

    /* ============ addToList ============ */
    function test_addToList_notPortal() external {
        vm.expectRevert(IRegistrar.NotPortal.selector);
        _registrar.addToList("someList", _account1);
    }

    function test_addToList() external {
        assertFalse(_registrar.listContains("someList", _account1));

        vm.expectEmit();
        emit IRegistrar.AddressAddedToList("someList", _account1);

        vm.prank(_portal);
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));
    }

    function test_addToList_multiple() external {
        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertFalse(_registrar.listContains("someList", accounts_));

        vm.expectEmit();
        emit IRegistrar.AddressAddedToList("someList", _account1);

        vm.prank(_portal);
        _registrar.addToList("someList", _account1);

        vm.expectEmit();
        emit IRegistrar.AddressAddedToList("someList", _account2);

        vm.prank(_portal);
        _registrar.addToList("someList", _account2);

        vm.expectEmit();
        emit IRegistrar.AddressAddedToList("someList", _account3);

        vm.prank(_portal);
        _registrar.addToList("someList", _account3);

        assertTrue(_registrar.listContains("someList", accounts_));
    }

    /* ============ removeFromList ============ */
    function test_removeFromList_notPortal() external {
        vm.expectRevert(IRegistrar.NotPortal.selector);
        _registrar.removeFromList("someList", _account1);
    }

    function test_removeFromList() external {
        vm.prank(_portal);
        _registrar.addToList("someList", _account1);

        assertTrue(_registrar.listContains("someList", _account1));

        vm.expectEmit();
        emit IRegistrar.AddressRemovedFromList("someList", _account1);

        vm.prank(_portal);
        _registrar.removeFromList("someList", _account1);

        assertFalse(_registrar.listContains("someList", _account1));
    }

    function test_removeFromList_multiple() external {
        vm.startPrank(_portal);
        _registrar.addToList("someList", _account1);
        _registrar.addToList("someList", _account2);
        _registrar.addToList("someList", _account3);
        vm.stopPrank();

        address[] memory accounts_ = new address[](3);
        accounts_[0] = _account1;
        accounts_[1] = _account2;
        accounts_[2] = _account3;

        assertTrue(_registrar.listContains("someList", accounts_));

        vm.expectEmit();
        emit IRegistrar.AddressRemovedFromList("someList", _account1);

        vm.prank(_portal);
        _registrar.removeFromList("someList", _account1);

        vm.expectEmit();
        emit IRegistrar.AddressRemovedFromList("someList", _account2);

        vm.prank(_portal);
        _registrar.removeFromList("someList", _account2);

        vm.expectEmit();
        emit IRegistrar.AddressRemovedFromList("someList", _account3);

        vm.prank(_portal);
        _registrar.removeFromList("someList", _account3);

        assertFalse(_registrar.listContains("someList", accounts_));
    }
}
