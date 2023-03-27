// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {List, NotAdmin} from "src/periphery/List.sol";
import {BaseTest} from "test/Base.t.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract MockSPOG is ERC165 {
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(ISPOG).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}

contract ListTest is BaseTest {
    List public list;

    // Events to test
    event AddressAdded(address _address);
    event AddressRemoved(address _address);

    function setUp() public {
        createUsers();
        list = new List("SPOG Collateral Managers List");
    }

    function test_constructor() public {
        assertEq(list.admin(), users.admin);
        assertEq(list.name(), "SPOG Collateral Managers List");
    }

    function test_AddUsers() public {
        // Add Alice and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(users.alice);
        list.add(users.alice);

        // List contains only Alice
        assertEq(list.contains(users.alice), true);
        assertEq(list.contains(users.bob), false);

        // Add Bob and check that event `AddressAdded` is emitted
        expectEmit();
        emit AddressAdded(users.bob);
        list.add(users.bob);

        // List contains Alice and Bob now
        assertEq(list.contains(users.alice), true);
        assertEq(list.contains(users.bob), true);
    }

    function test_RemoveUsers() public {
        // Add Alice and Bob
        list.add(users.alice);
        list.add(users.bob);

        // Remove Alice and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(users.alice));
        list.remove(users.alice);

        // List contains only Bob
        assertEq(list.contains(users.alice), false);
        assertEq(list.contains(users.bob), true);

        // Remove Bob and check that event `AddressRemoved` is emitted
        expectEmit();
        emit AddressRemoved(address(users.bob));
        list.remove(users.bob);

        // List contains no users now
        assertEq(list.contains(users.alice), false);
        assertEq(list.contains(users.bob), false);
    }

    function test_changeAdmin() public {
        address newSPOG = address(new MockSPOG());
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), newSPOG);
    }

    function test_Revert_ChangeAdmin_WhenNewAdminIsNotSPOG() public {
        vm.expectRevert(
            "ERC165CheckerSPOG: spogAddress address does not implement proper interface"
        );
        list.changeAdmin(users.alice);

        assertEq(list.admin(), users.admin);
    }

    function test_Revert_ChangeAdmin_WhenCallerIsNotAdmin() public {
        // Make the admin the default caller.
        address newSPOG = address(new MockSPOG());
        changePrank({who: users.alice});

        vm.expectRevert(NotAdmin.selector);
        list.changeAdmin(newSPOG);

        assertEq(list.admin(), users.admin);
    }

    function test_Revert_Add_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller.
        changePrank({who: users.alice});

        vm.expectRevert(NotAdmin.selector);
        list.add(users.alice);
    }

    function test_Revert_Remove_WhenCallerIsNotAdmin() public {
        // Make Alice the default caller.
        changePrank({who: users.alice});

        vm.expectRevert(NotAdmin.selector);
        list.remove(users.alice);
    }
}
