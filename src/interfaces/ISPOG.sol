// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IList} from "./IList.sol";

interface ISPOG {
    function newList() external;

    function removeList(uint256 _proposalId, address _listAddress) external;

    function append(
        uint256 _proposalId,
        address _address,
        IList _list
    ) external;

    function remove(
        uint256 _proposalId,
        address _address,
        IList _list
    ) external;

    function emergencyRemove(
        uint256 _proposalId,
        address _address,
        IList _list
    ) external;
}
