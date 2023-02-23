// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {ERC165CheckerSPOG} from "src/ERC165CheckerSPOG.sol";

/***************************************************/
/******** Prototype - NOT FOR PROD ****************/
/*************************************************/

error NotAdmin();

/// @notice List contract where only an admin (SPOG) can add and remove addresses from a list
contract P_List is ERC165CheckerSPOG {
    // text list
    mapping(string => bool) internal listText;

    // create an admin address
    address public admin;

    string private _name;

    event TextAdded(string _text);
    event TextRemoved(string _text);

    // constructor sets the admin address
    constructor(string memory name_) {
        _name = name_;
        checkSPOGInterface(msg.sender);
        admin = msg.sender;
    }

    /// @notice Returns the name of the list
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Add an string to the list
    /// @param _text The string to add
    function add(string memory _text) external {
        if (msg.sender != admin) revert NotAdmin();

        // add the string to the list
        listText[_text] = true;
        emit TextAdded(_text);
    }

    /// @notice Remove a text from the list
    /// @param _text The text to remove
    function remove(string memory _text) external {
        if (msg.sender != admin) revert NotAdmin();

        // remove the text from the list
        listText[_text] = false;
        emit TextRemoved(_text);
    }

    /// @notice Check if a text is on the list
    /// @param _text The text to check
    function contains(string memory _text) external view returns (bool) {
        return listText[_text];
    }

    /// @notice Change the admin address
    /// @param _newAdmin The new admin address
    function changeAdmin(address _newAdmin)
        external
        onlySPOGInterface(_newAdmin)
    {
        if (msg.sender != admin) revert NotAdmin();

        admin = _newAdmin;
    }
}
