// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

/***************************************************/
/******** Prototype - NOT FOR PROD ****************/
/*************************************************/

interface P_IList {
    function name() external view returns (string memory);

    function add(string memory _text) external;

    function remove(string memory _text) external;

    function contains(string memory _text) external view returns (bool);

    function changeAdmin(address _newAdmin) external;
}
