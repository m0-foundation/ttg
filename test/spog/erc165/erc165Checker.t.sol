// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "test/shared/SPOGBaseTest.t.sol";

contract MockContract is ERC165CheckerSPOG {}

contract TestERC165CheckerSPOG is SPOGBaseTest {
    function test_checkSpogInterface() public {
        MockContract checker = new MockContract();

        vm.expectRevert();
        checker.checkSPOGInterface(address(0));

        checker.checkSPOGInterface(address(spog));
    }
}
