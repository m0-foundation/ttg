// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SPOG.sol";

contract SPOGTest is Test {
    SPOG public spog;

    function setUp() public {
        // set up SPOG initialization
        // spog = new SPOG();
    }

    function testSPOGHasBeenInitialized() public {}

    function testRevertWhenInitializingWithIncorrectvalues() public {}
}
