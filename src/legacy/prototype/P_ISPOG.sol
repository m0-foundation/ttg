// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

/***************************************************/
/******** Prototype - NOT FOR PROD ****************/
/*************************************************/

import {P_IList} from "src/legacy/prototype/P_IList.sol";

interface P_ISPOG {
    function addNewList(string memory listName) external;

    function removeList(address _listAddress) external;

    function append(string memory _address, P_IList _list) external;

    function remove(string memory _address, P_IList _list) external;
}
