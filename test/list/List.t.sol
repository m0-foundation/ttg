// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "test/shared/Base.t.sol";
import "src/periphery/List.sol";
import "src/interfaces/ISPOG.sol";

contract MockSPOG is ERC165 {
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }
}

contract ListTest is BaseTest {
    List public list;

    // Events to test
    event AddressAdded(address indexed _address);
    event AddressRemoved(address indexed _address);
    event AdminChanged(address indexed _newAdmin);

    function setUp() public {
        vm.startPrank(msg.sender);
        createUsers();
        list = new List("SPOG Collateral Managers List");
    }

    function test_Constructor() public {
        assertEq(list.admin(), users.admin);
        assertEq(list.name(), "SPOG Collateral Managers List");
    }

    function test_AddUsers() public {
        // add Alice and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(users.alice);
        list.add(users.alice);

        // list contains only Alice
        assertTrue(list.contains(users.alice), "Alice is not in the list");
        assertFalse(list.contains(users.bob), "Bob is in the list");

        // add Bob and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(users.bob);
        list.add(users.bob);

        // list contains both Alice and Bob now
        assertTrue(list.contains(users.alice), "Alice is not in the list");
        assertTrue(list.contains(users.bob), "Bob is not in the list");
    }

    function test_RemoveUsers() public {
        // add Alice and Bob
        list.add(users.alice);
        list.add(users.bob);

        // remove Alice and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(users.alice));
        list.remove(users.alice);

        // list contains only Bob
        assertFalse(list.contains(users.alice), "Alice is still in the list");
        assertTrue(list.contains(users.bob), "Bob is not in the list");

        // remove Bob and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(users.bob));
        list.remove(users.bob);

        // list doesn't have users now
        assertFalse(list.contains(users.alice), "Alice is still in the list");
        assertFalse(list.contains(users.bob), "Bob is still in the list");
    }

    function test_RemoveUsers_WhenListIsEmpty_OrUserIsNotInTheList() public {
        // list is empty
        assertFalse(list.contains(users.charlie), "Charlie is in the list");

        bytes memory expectedError = abi.encodeWithSignature("AddressIsNotInList()");

        vm.expectRevert(expectedError);
        list.remove(users.charlie);
    }

    function test_ChangeAdmin() public {
        // successfully set new admin to SPOG-like contract
        address newSPOG = address(new MockSPOG());

        expectEmit();
        emit AdminChanged(newSPOG);
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), newSPOG);
    }

    function test_Revert_ChangeAdmin_WhenNewAdminIsNotSPOG() public {
        // revert when trying to set new admin to non-SPOG address
        vm.expectRevert(ERC165CheckerSPOG.InvalidSPOGInterface.selector);
        list.changeAdmin(users.alice);

        assertEq(list.admin(), users.admin);
    }

    function test_Revert_ChangeAdmin_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller instead of admin
        changePrank({who: users.alice});
        address newSPOG = address(new MockSPOG());

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), users.admin);
    }

    function test_Revert_Add_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller instead of admin
        changePrank({who: users.alice});

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.add(users.alice);
    }

    function test_Revert_Remove_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller instead of admin
        changePrank({who: users.alice});

        // revert when called not by an admin
        vm.expectRevert(IList.NotAdmin.selector);
        list.remove(users.alice);
    }

    function test_Revert_addWhenAlreadyInList() public {
        list.add(users.alice);

        bytes memory expectedError = abi.encodeWithSignature("AddressIsAlreadyInList()");

        vm.expectRevert(expectedError);
        list.add(users.alice);
    }
}
