// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SPOGGovernorFactory} from "src/factories/SPOGGovernorFactory.sol";
import {SPOG_Base} from "test/shared/SPOG_Base.t.sol";

contract SPOGGovernorFactoryTest is SPOG_Base {
    function test_fallback() public {
        SPOGGovernorFactory factory = new SPOGGovernorFactory();

        vm.expectRevert("SPOGGovernorFactory: non-existent function");
        (bool success,) = address(factory).call(abi.encodeWithSignature("doesNotExist()"));

        assertEq(success, false);
    }
}
