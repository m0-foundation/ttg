// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "src/periphery/List.sol";
import "test/shared/SPOG_Base.t.sol";
import "src/interfaces/ISPOG.sol";

contract MockSPOG is ERC165 {
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract ListTest is SPOG_Base {
    List public listContract = new List("SPOG Collateral Managers List");

    // Events to test
    event AddressAdded(address indexed _address);
    event AddressRemoved(address indexed _address);
    event AdminChanged(address indexed _newAdmin);

    function test_Constructor() public {
        assertEq(listContract.admin(), address(this));
        assertEq(listContract.name(), "SPOG Collateral Managers List");
    }

    function test_AddUsers() public {
        // add Alice and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(alice);
        listContract.add(alice);

        // list contains only Alice
        assertTrue(listContract.contains(alice), "Alice is not in the list");
        assertFalse(listContract.contains(bob), "Bob is in the list");

        // add Bob and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(bob);
        listContract.add(bob);

        // list contains both Alice and Bob now
        assertTrue(listContract.contains(alice), "Alice is not in the list");
        assertTrue(listContract.contains(bob), "Bob is not in the list");
    }

    function test_RemoveUsers() public {
        // add Alice and Bob
        listContract.add(alice);
        listContract.add(bob);

        // remove Alice and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(alice));
        listContract.remove(alice);

        // list contains only Bob
        assertFalse(listContract.contains(alice), "Alice is still in the list");
        assertTrue(listContract.contains(bob), "Bob is not in the list");

        // remove Bob and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(bob));
        listContract.remove(bob);

        // list doesn't have users now
        assertFalse(listContract.contains(alice), "Alice is still in the list");
        assertFalse(listContract.contains(bob), "Bob is still in the list");
    }

    function test_RemoveUsers_WhenListIsEmpty_OrUserIsNotInTheList() public {
        // list is empty
        assertFalse(listContract.contains(charlie), "Charlie is in the list");

        bytes memory expectedError = abi.encodeWithSignature("AddressIsNotInList()");

        vm.expectRevert(expectedError);
        listContract.remove(charlie);
    }

    function test_ChangeAdmin() public {
        // successfully set new admin to SPOG-like contract
        address newSPOG = address(new MockSPOG());

        expectEmit();
        emit AdminChanged(newSPOG);
        listContract.changeAdmin(newSPOG);

        assertEq(listContract.admin(), newSPOG);
    }

    function test_Revert_ChangeAdmin_WhenNewAdminIsNotSPOG() public {
        // revert when trying to set new admin to non-SPOG address
        vm.expectRevert(ERC165CheckerSPOG.InvalidSPOGInterface.selector);
        listContract.changeAdmin(alice);

        assertEq(listContract.admin(), address(this));
    }

    function test_Revert_ChangeAdmin_WhenCallerIsNotAdmin() public {
        address newSPOG = address(new MockSPOG());

        // revert when called not by an admin
        vm.expectRevert(NotAdmin.selector);
        // Make Alice the default caller instead of admin
        vm.prank(alice);
        listContract.changeAdmin(newSPOG);

        assertEq(listContract.admin(), address(this));
    }

    function test_Revert_Add_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller instead of admin
        vm.prank(alice);

        // revert when called not by an admin
        vm.expectRevert(NotAdmin.selector);
        listContract.add(alice);
    }

    function test_Revert_Remove_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller instead of admin
        vm.prank(alice);

        // revert when called not by an admin
        vm.expectRevert(NotAdmin.selector);
        listContract.remove(alice);
    }

    function test_Revert_addWhenAlreadyInList() public {
        listContract.add(alice);

        bytes memory expectedError = abi.encodeWithSignature("AddressIsAlreadyInList()");

        vm.expectRevert(expectedError);
        listContract.add(alice);
    }
}
