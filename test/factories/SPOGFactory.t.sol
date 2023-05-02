// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SPOGFactory} from "src/factories/SPOGFactory.sol";
import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";

contract SPOGFactoryTest is SPOG_Base {
    function test_fallback() public {
        SPOGFactory factory = new SPOGFactory();

        vm.expectRevert("SPOGFactory: non-existent function");
        (bool success,) = address(factory).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, true);
    }
}
