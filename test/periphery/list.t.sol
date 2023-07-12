// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { IList } from "../../src/interfaces/periphery/IList.sol";
import { ISPOG } from "../../src/interfaces/ISPOG.sol";

import { ERC165CheckerSPOG } from "../../src/periphery/ERC165CheckerSPOG.sol";
import { List } from "../../src/periphery/List.sol";

import { SPOGBaseTest } from "../shared/SPOGBaseTest.t.sol";
import { SPOGMock } from "../shared/SPOGMock.sol";

contract ListTest is SPOGBaseTest {
    address public admin;

    // Events to test
    event AddressAdded(address indexed _address);
    event AddressRemoved(address indexed _address);
    event AdminChanged(address indexed _newAdmin);

    function setUp() public override {
        admin = carol;
        vm.startPrank(admin);
        list = new List("SPOG Collateral Managers List");
        vm.stopPrank();
    }

    function test_Constructor() public {
        assertEq(list.admin(), admin);
        assertEq(list.name(), "SPOG Collateral Managers List");
    }

    function test_AddUsers() public {
        vm.startPrank(admin);

        // add Alice and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(alice);
        list.add(alice);

        // list contains only Alice
        assertTrue(list.contains(alice), "Alice is not in the list");
        assertFalse(list.contains(bob), "Bob is in the list");

        // add Bob and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(bob);
        list.add(bob);

        // list contains both Alice and Bob now
        assertTrue(list.contains(alice), "Alice is not in the list");
        assertTrue(list.contains(bob), "Bob is not in the list");
    }

    function test_RemoveUsers() public {
        vm.startPrank(admin);

        // add Alice and Bob
        list.add(alice);
        list.add(bob);

        // remove Alice and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(alice));
        list.remove(alice);

        // list contains only Bob
        assertFalse(list.contains(alice), "Alice is still in the list");
        assertTrue(list.contains(bob), "Bob is not in the list");

        // remove Bob and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(bob));
        list.remove(bob);

        // list doesn't have users now
        assertFalse(list.contains(alice), "Alice is still in the list");
        assertFalse(list.contains(bob), "Bob is still in the list");
    }

    function test_RemoveUsers_WhenListIsEmpty_OrUserIsNotInTheList() public {
        vm.startPrank(admin);

        // list is empty
        assertFalse(list.contains(alice), "Alice is in the list");

        bytes memory expectedError = abi.encodeWithSignature("AddressIsNotInList()");

        vm.expectRevert(expectedError);
        list.remove(alice);
    }

    function test_ChangeAdmin() public {
        vm.startPrank(admin);

        // successfully set new admin to SPOG-like contract
        address newSPOG = address(new SPOGMock());

        expectEmit();
        emit AdminChanged(newSPOG);
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), newSPOG);
    }

    function test_Revert_ChangeAdmin_WhenNewAdminIsNotSPOG() public {
        vm.startPrank(admin);

        // revert when trying to set new admin to non-SPOG address
        vm.expectRevert(ERC165CheckerSPOG.InvalidSPOGInterface.selector);
        list.changeAdmin(alice);

        assertEq(list.admin(), admin);
    }

    function test_Revert_ChangeAdmin_WhenCallerIsNotAdmin() public {
        vm.startPrank(alice);
        address newSPOG = address(new SPOGMock());

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), carol);
    }

    function test_Revert_Add_WhenCallerIsNotAdmin() public {
        vm.startPrank(alice);

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.add(alice);
    }

    function test_Revert_Remove_WhenCallerIsNotAdmin() public {
        vm.startPrank(alice);

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.remove(alice);
    }

    function test_Revert_addWhenAlreadyInList() public {
        vm.startPrank(admin);

        list.add(alice);

        bytes memory expectedError = abi.encodeWithSignature("AddressIsAlreadyInList()");

        vm.expectRevert(expectedError);
        list.add(alice);
    }
}
