// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "src/interfaces/IList.sol";

interface ISPOG {
    function addNewList(IList list) external;

    function removeList(IList list) external;

    function append(address _address, IList _list) external;

    function remove(address _address, IList _list) external;

    function emergencyRemove(address _address, IList _list) external;

    function tokenInflationCalculation() external view returns (uint256);
}
