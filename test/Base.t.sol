// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import {ERC20GodMode} from "test/mock/ERC20GodMode.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title BaseTest
/// @notice Common contract members needed across test contracts.
abstract contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 internal constant ONE_MILLION_TOKENS = 1_000_000e18;

    /*//////////////////////////////////////////////////////////////////////////
                          INTERNAL NON-CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates an address by hashing the name, labels the address and funds it with 100 ETH, 1 million DAI,
    /// and 1 million non-compliant tokens.
    function createUser(string memory name) internal returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({account: addr, newBalance: 1000 ether});
    }

    /// @dev Expects an event to be emitted by checking all three topics and the data. As mentioned in the Foundry
    /// Book, the extra `true` arguments don't hurt.
    function expectEmit() internal {
        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
    }
}
