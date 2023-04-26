// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {IList} from "src/interfaces/IList.sol";
import {ISPOG} from "src/interfaces/ISPOG.sol";

abstract contract SPOGGoverned {
    error InvalidList(address listAddress);

    ISPOG public spog;

    constructor(address _spog) {
        spog = ISPOG(_spog);
    }

    function getListByAddress(address listAddress) public view returns (IList) {
        if (!spog.isListInMasterList(listAddress)) {
            revert InvalidList(listAddress);
        }

        return IList(listAddress);
    }
}
