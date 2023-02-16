// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "./IList.sol";

interface ISPOG {
    function addNewList(string memory listName) external;

    function removeList(address _listAddress) external;

    function append(address _address, IList _list) external;

    function remove(address _address, IList _list) external;

    function emergencyRemove(address _address, IList _list) external;
}
